import AppKit
import CryptoKit
import Foundation
import Observation

/// Read-only pasteboard surface used by `ClipboardMonitor`.
/// `NSPasteboard` conforms in production; tests inject a mock.
protocol PasteboardReading: AnyObject {
    var changeCount: Int { get }
    var declaredTypes: [NSPasteboard.PasteboardType] { get }
    var items: [any PasteboardItemReading] { get }
}

/// Read-only pasteboard item surface.
protocol PasteboardItemReading {
    var types: [NSPasteboard.PasteboardType] { get }
    func data(forType type: NSPasteboard.PasteboardType) -> Data?
    func string(forType type: NSPasteboard.PasteboardType) -> String?
}

extension NSPasteboard: PasteboardReading {
    var declaredTypes: [NSPasteboard.PasteboardType] { types ?? [] }
    var items: [any PasteboardItemReading] { pasteboardItems ?? [] }
}

extension NSPasteboardItem: PasteboardItemReading {}

/// One accepted pasteboard change, ready for persistence.
struct ClipboardSnapshot {
    /// All captured UTIs from this copy, in canonical order.
    var contentTypes: [String]
    /// Plain text representation (searchable); falls back to URL for link-only copies.
    var text: String?
    /// Large representations (rtf/html/image) to persist on disk instead of the DB.
    var payloads: [(type: String, data: Data)]
    /// SHA-256 over all captured representations, for dedup.
    var contentHash: String
    var sourceAppBundleID: String?
}

/// Polls the general pasteboard and emits snapshots for accepted changes.
///
/// Skip rules, in order (ARCHITECTURE §4):
/// concealed/transient types, excluded source apps, duplicate hash (via
/// `shouldSkipCapture`), and self-originated write-backs (reserved for Task 3).
@Observable
final class ClipboardMonitor {

    /// Pasteboard markers that identify sensitive or ephemeral content (F10).
    private enum MarkerType {
        static let concealed = "org.nspasteboard.ConcealedType"
        static let transient = "org.nspasteboard.TransientType"
    }

    /// UTIs read from each pasteboard item, in priority order.
    private static let capturedTypes: [NSPasteboard.PasteboardType] = [
        .string, // public.utf8-plain-text
        .init("public.url"),
        .init("public.file-url"),
        .init("public.rtf"),
        .init("public.html"),
        .init("public.png"),
        .init("public.tiff"),
    ]

    /// Types stored as payload files rather than in the database.
    private static let payloadTypes: Set<String> = [
        "public.rtf", "public.html", "public.png", "public.tiff",
    ]

    /// Wired to storage by the app; called on the main actor for each accepted change.
    var onCapture: ((ClipboardSnapshot) -> Void)?
    /// Wired to storage by the app; returns true when the change must not be recorded.
    var shouldSkipCapture: ((ClipboardSnapshot) -> Bool)?

    /// Source apps whose copies are ignored. Settings UI arrives in M2 (F9).
    var excludedBundleIDs: Set<String> = []

    private(set) var isPaused = false

    private let pasteboard: any PasteboardReading
    private var timer: Timer?
    private var lastChangeCount: Int
    private var ignoreNextChange = false

    init(pasteboard: any PasteboardReading = NSPasteboard.general) {
        self.pasteboard = pasteboard
        self.lastChangeCount = pasteboard.changeCount
    }

    func start(pollInterval: TimeInterval = 0.5) {
        guard timer == nil else { return }
        lastChangeCount = pasteboard.changeCount
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.poll() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Pause switch: polling continues but changes are skipped (ARCHITECTURE §4).
    func setPaused(_ paused: Bool) {
        isPaused = paused
    }

    /// Reserved for PasteService (Task 3): call before writing the app's own data
    /// back to the pasteboard so the write-back is not captured again.
    func markNextPasteboardWriteAsOwn() {
        ignoreNextChange = true
    }

    /// Runs one poll cycle synchronously. Exposed for tests; production polls via the timer.
    func checkNow() {
        poll()
    }

    private func poll() {
        guard pasteboard.changeCount != lastChangeCount else { return }
        lastChangeCount = pasteboard.changeCount

        guard !isPaused else { return }

        if ignoreNextChange {
            ignoreNextChange = false
            return
        }

        let pasteboardTypes = pasteboard.declaredTypes
        guard !pasteboardTypes.isEmpty else { return }
        let rawTypes = Set(pasteboardTypes.map(\.rawValue))
        guard !rawTypes.contains(MarkerType.concealed), !rawTypes.contains(MarkerType.transient) else {
            return
        }

        let sourceApp = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        if let sourceApp, excludedBundleIDs.contains(sourceApp) { return }

        guard let snapshot = makeSnapshot(from: pasteboard, sourceApp: sourceApp) else { return }
        guard shouldSkipCapture?(snapshot) != true else { return }
        onCapture?(snapshot)
    }

    private func makeSnapshot(
        from pasteboard: any PasteboardReading,
        sourceApp: String?
    ) -> ClipboardSnapshot? {
        var contentTypes: Set<String> = []
        var plainParts: [String] = []
        var urlParts: [String] = []
        var payloads: [(type: String, data: Data)] = []
        var hasher = SHA256()

        for item in pasteboard.items {
            for type in Self.capturedTypes where item.types.contains(type) {
                if Self.payloadTypes.contains(type.rawValue) {
                    guard let data = item.data(forType: type),
                          Self.isValidPayload(type.rawValue, data: data) else { continue }
                    contentTypes.insert(type.rawValue)
                    hasher.update(data: Data(type.rawValue.utf8))
                    hasher.update(data: data)
                    payloads.append((type.rawValue, data))
                } else if let string = item.string(forType: type) {
                    contentTypes.insert(type.rawValue)
                    hasher.update(data: Data(type.rawValue.utf8))
                    hasher.update(data: Data(string.utf8))
                    if type == .string {
                        plainParts.append(string)
                    } else {
                        urlParts.append(string)
                    }
                }
            }
        }

        guard !contentTypes.isEmpty else { return nil }

        let text = plainParts.isEmpty ? urlParts.first : plainParts.joined(separator: "\n")

        return ClipboardSnapshot(
            contentTypes: Self.capturedTypes.map(\.rawValue).filter(contentTypes.contains),
            text: text,
            payloads: payloads,
            contentHash: hasher.finalize().map { String(format: "%02x", $0) }.joined(),
            sourceAppBundleID: sourceApp
        )
    }

    /// Payload admission rule (Task 8-D): corrupt image data (e.g. a 4-byte
    /// PNG magic-only write from an incomplete pasteboard read) must never
    /// reach disk. Non-image payloads pass; images must be substantial enough
    /// and decodable.
    nonisolated static func isValidPayload(_ type: String, data: Data) -> Bool {
        guard type == "public.png" || type == "public.tiff" else { return true }
        return data.count >= 100 && NSImage(data: data) != nil
    }
}
