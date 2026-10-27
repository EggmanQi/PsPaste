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
    var historyLimit = 1000

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
        return names.sorted().compactMap { name in
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

    /// Deletes the oldest unpinned records past the limit, including payload files.
    private func pruneIfNeeded() {
        let descriptor = FetchDescriptor<ClipboardItem>(
            sortBy: [SortDescriptor(\.createdAt, order: .forward)]
        )
        guard let all = try? context.fetch(descriptor), all.count > historyLimit else { return }

        var excess = all.count - historyLimit
        for item in all where !item.isPinned {
            guard excess > 0 else { break }
            if let payloadPath = item.payloadPath {
                try? FileManager.default.removeItem(
                    at: payloadsRoot.appendingPathComponent(payloadPath, isDirectory: true)
                )
            }
            context.delete(item)
            excess -= 1
        }
        try? context.save()
    }
}
