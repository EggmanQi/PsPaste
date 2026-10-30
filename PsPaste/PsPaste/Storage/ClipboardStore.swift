import Foundation
import SwiftData

/// Persists clipboard snapshots and enforces the history limit.
///
/// Payload files live in `Application Support/PsPaste/Payloads/<item id>/`;
/// the database stores only the relative path.
@MainActor
final class ClipboardStore {

    let modelContainer: ModelContainer

    private let context: ModelContext
    private let payloadsRoot: URL

    /// Oldest unpinned records beyond this count are deleted (F2, default 1000).
    /// Wired to `AppSettings` at launch and on change (Task 14).
    var historyLimit = 1000

    /// Records idle longer than this are removed by the periodic sweep.
    /// Wired to `AppSettings.retentionDays` at launch and on change (Task 14);
    /// the default preserves the previous fixed 30-day policy.
    var staleTTL: TimeInterval = Double(AppSettings.Limit.defaultRetentionDays) * 24 * 60 * 60

    /// Eviction policy (ARCHITECTURE §3, 2026-10-29 LRU revision): survival
    /// is by last activity, pinned records are exempt from both rules.
    enum Eviction {
        /// How often the periodic sweep runs (plus once at launch).
        static let scanInterval: TimeInterval = 24 * 60 * 60
    }

    private var evictionTimer: Timer?

    private static let deviceName = Host.current().localizedName ?? "Unknown Mac"

    /// Designated initializer. Tests inject an in-memory container and a temp payloads root.
    init(modelContainer: ModelContainer, payloadsRoot: URL) {
        self.modelContainer = modelContainer
        context = ModelContext(modelContainer)
        self.payloadsRoot = payloadsRoot
        try? FileManager.default.createDirectory(at: payloadsRoot, withIntermediateDirectories: true)
    }

    convenience init() {
        self.init(
            modelContainer: Self.makeDefaultContainer(),
            payloadsRoot: Self.defaultPayloadsRoot()
        )
    }

    private static func makeDefaultContainer() -> ModelContainer {
        do {
            return try ModelContainer(for: ClipboardItem.self)
        } catch {
            fatalError("Failed to create the SwiftData container: \(error)")
        }
    }

    private static func defaultPayloadsRoot() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PsPaste/Payloads", isDirectory: true)
    }

    func save(_ snapshot: ClipboardSnapshot) {
        let itemID = UUID()
        let item = ClipboardItem(
            id: itemID,
            sourceAppBundleID: snapshot.sourceAppBundleID,
            sourceAppName: snapshot.sourceAppName,
            sourceDevice: Self.deviceName,
            contentTypes: snapshot.contentTypes,
            text: snapshot.text,
            payloadPath: writePayloads(snapshot.payloads, itemID: itemID),
            contentHash: snapshot.contentHash
        )
        context.insert(item)
        try? context.save()
        pruneIfNeeded()
    }

    /// True when the newest record already has this content hash (ARCHITECTURE §4 rule 3).
    func containsNewest(matchingHash hash: String) -> Bool {
        var descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        guard let newest = try? context.fetch(descriptor).first else { return false }
        return newest.contentHash == hash
    }

    /// Reads back every stored payload representation of an item, ordered as captured.
    func payloadContents(for item: ClipboardItem) -> [(type: String, data: Data)] {
        guard let directory = payloadDirectory(of: item),
              let names = try? FileManager.default.contentsOfDirectory(atPath: directory.path) else {
            return []
        }
        // File names are "<index>_<type>"; sort by the number so that a copy
        // with ten or more payloads (e.g. a file list) keeps its order.
        let ordered = names.sorted { lhs, rhs in
            (Int(lhs.prefix { $0 != "_" }) ?? .max) < (Int(rhs.prefix { $0 != "_" }) ?? .max)
        }
        return ordered.compactMap { name in
            guard let separator = name.firstIndex(of: "_") else { return nil }
            let type = String(name[name.index(after: separator)...]).replacingOccurrences(of: "_", with: "/")
            guard let data = try? Data(contentsOf: directory.appendingPathComponent(name)) else { return nil }
            return (type, data)
        }
    }

    /// The first image payload of an item (png preferred over tiff), for thumbnails.
    func imagePayload(for item: ClipboardItem) -> Data? {
        payloadContents(for: item).first { payload in
            payload.type == "public.png" || payload.type == "public.tiff"
        }?.data
    }

    private func payloadDirectory(of item: ClipboardItem) -> URL? {
        guard let payloadPath = item.payloadPath else { return nil }
        return payloadsRoot.appendingPathComponent(payloadPath, isDirectory: true)
    }

    @discardableResult
    private func writePayloads(
        _ payloads: [(type: String, data: Data)],
        itemID: UUID
    ) -> String? {
        guard !payloads.isEmpty else { return nil }
        let directory = payloadsRoot.appendingPathComponent(itemID.uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (index, payload) in payloads.enumerated() {
            let fileName = "\(index)_\(payload.type.replacingOccurrences(of: "/", with: "_"))"
            try? payload.data.write(to: directory.appendingPathComponent(fileName))
        }
        return itemID.uuidString
    }

    /// Deletes one record and its payload files (shared by the eviction
    /// rules and the panel's delete action). Re-fetches in our own context —
    /// callers may hold instances from another ModelContext (e.g. a @Query
    /// in the panel).
    func delete(_ item: ClipboardItem) {
        let itemID = item.id
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.id == itemID }
        )
        guard let owned = try? context.fetch(descriptor).first else { return }
        if let payloadPath = owned.payloadPath {
            try? FileManager.default.removeItem(
                at: payloadsRoot.appendingPathComponent(payloadPath, isDirectory: true)
            )
        }
        context.delete(owned)
        try? context.save()
    }

    /// Toggles the pinned flag (UI.md §2.2 v5); pinned records are exempt
    /// from both eviction rules (ARCHITECTURE §3).
    func togglePin(_ item: ClipboardItem) {
        let itemID = item.id
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.id == itemID }
        )
        guard let owned = try? context.fetch(descriptor).first else { return }
        owned.isPinned.toggle()
        try? context.save()
    }

    /// Touch on confirm: pasting an entry back makes it the most recently used.
    /// Re-fetches in our own context — callers may hold instances from
    /// another ModelContext (e.g. a @Query in the panel).
    func markUsed(_ item: ClipboardItem) {
        let itemID = item.id
        let descriptor = FetchDescriptor<ClipboardItem>(
            predicate: #Predicate { $0.id == itemID }
        )
        guard let owned = try? context.fetch(descriptor).first else { return }
        owned.lastUsedAt = Date()
        try? context.save()
    }

    /// Periodic eviction (ARCHITECTURE §3 rule 2): unpinned records whose
    /// last activity is older than the TTL are deleted. `now` is injectable
    /// for tests; the timer fires this with the wall clock. The TTL itself
    /// is the instance property, wired to `AppSettings` (Task 14).
    func evictStale(now: Date = Date()) {
        let descriptor = FetchDescriptor<ClipboardItem>()
        guard let all = try? context.fetch(descriptor) else { return }
        for item in all where !item.isPinned && Self.shouldEvict(
            lastActivityAt: item.lastActivityAt,
            now: now,
            ttl: staleTTL
        ) {
            delete(item)
        }
    }

    /// Starts the launch + every-24h stale sweep. The clock stays injectable
    /// via `evictStale(now:)`; the timer only wires wall-clock firing.
    func startEvictionTimer() {
        evictionTimer?.invalidate()
        evictionTimer = Timer.scheduledTimer(
            withTimeInterval: Eviction.scanInterval,
            repeats: true
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.evictStale() }
        }
    }

    /// Eviction decision, a pure function: strictly older than the TTL.
    nonisolated static func shouldEvict(
        lastActivityAt: Date,
        now: Date,
        ttl: TimeInterval
    ) -> Bool {
        now.timeIntervalSince(lastActivityAt) > ttl
    }

    /// Capacity eviction (ARCHITECTURE §3 rule 1): beyond the limit, the
    /// least recently used unpinned records go first, payloads included.
    private func pruneIfNeeded() {
        let descriptor = FetchDescriptor<ClipboardItem>()
        guard let all = try? context.fetch(descriptor), all.count > historyLimit else { return }

        let lruOrder = all
            .filter { !$0.isPinned }
            .sorted { $0.lastActivityAt < $1.lastActivityAt }

        var excess = all.count - historyLimit
        for item in lruOrder {
            guard excess > 0 else { break }
            delete(item)
            excess -= 1
        }
    }

    /// Applies the capacity rule immediately (Settings ▸ General lowers the
    /// limit, Task 14) instead of waiting for the next capture to prune.
    func enforceHistoryLimit() {
        pruneIfNeeded()
    }

    /// Deletes every record and its payload files (Settings ▸ Privacy,
    /// Task 14). One save for the whole batch.
    func clearAll() {
        let descriptor = FetchDescriptor<ClipboardItem>()
        guard let all = try? context.fetch(descriptor) else { return }
        for item in all {
            if let payloadPath = item.payloadPath {
                try? FileManager.default.removeItem(
                    at: payloadsRoot.appendingPathComponent(payloadPath, isDirectory: true)
                )
            }
            context.delete(item)
        }
        try? context.save()
    }
}
