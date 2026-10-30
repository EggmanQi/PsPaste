import AppKit
import XCTest
@testable import PsPaste

@MainActor
final class ClipboardMonitorTests: XCTestCase {

    private var pasteboard: MockPasteboard!
    private var monitor: ClipboardMonitor!
    private var captured: [ClipboardSnapshot] = []

    override func setUp() {
        super.setUp()
        pasteboard = MockPasteboard()
        monitor = ClipboardMonitor(pasteboard: pasteboard)
        captured = []
        monitor.onCapture = { [weak self] in self?.captured.append($0) }
    }

    private func copyText(_ text: String) {
        let item = MockPasteboardItem()
        item.setString(text, forType: .string)
        pasteboard.simulateCopy(declaredTypes: [.string], items: [item])
        monitor.checkNow()
    }

    func testCapturesNewChangeWithText() {
        copyText("hello ps paste")

        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured.first?.text, "hello ps paste")
        XCTAssertEqual(captured.first?.contentTypes, ["public.utf8-plain-text"])
        XCTAssertFalse(captured.first?.contentHash.isEmpty ?? true)
    }

    func testSameContentSecondCaptureSkippedViaDedupClosure() {
        copyText("repeat me")
        XCTAssertEqual(captured.count, 1)

        // Same hash as the newest stored record: storage-side dedup (ARCHITECTURE §4 rule 3).
        let seenHash = captured[0].contentHash
        monitor.shouldSkipCapture = { $0.contentHash == seenHash }
        copyText("repeat me")
        XCTAssertEqual(captured.count, 1)
    }

    func testNoChangeCountChangeProducesNoCapture() {
        monitor.checkNow()
        XCTAssertTrue(captured.isEmpty)
    }

    func testConcealedTypeChangeIsSkipped() {
        let item = MockPasteboardItem()
        item.setString("secret", forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType"))
        pasteboard.simulateCopy(
            declaredTypes: [.string, NSPasteboard.PasteboardType("org.nspasteboard.ConcealedType")],
            items: [item]
        )
        monitor.checkNow()

        XCTAssertTrue(captured.isEmpty)
    }

    func testTransientTypeChangeIsSkipped() {
        let item = MockPasteboardItem()
        item.setString("ephemeral", forType: .string)
        item.setData(Data(), forType: NSPasteboard.PasteboardType("org.nspasteboard.TransientType"))
        pasteboard.simulateCopy(
            declaredTypes: [.string, NSPasteboard.PasteboardType("org.nspasteboard.TransientType")],
            items: [item]
        )
        monitor.checkNow()

        XCTAssertTrue(captured.isEmpty)
    }

    func testPausedMonitorSkipsButKeepsTrackingChangeCount() {
        monitor.setPaused(true)
        copyText("while paused")
        XCTAssertTrue(captured.isEmpty)

        monitor.setPaused(false)
        copyText("after resume")
        XCTAssertEqual(captured.map(\.text), ["after resume"])
    }

    /// URL strings must survive to paste-back (ARCHITECTURE §4, lossless
    /// restore), so they are kept as payloads as well as the text fallback.
    func testURLRepresentationsAreKeptAsPayloads() {
        let item = MockPasteboardItem()
        item.setString("https://onev.cat", forType: NSPasteboard.PasteboardType("public.url"))
        pasteboard.simulateCopy(declaredTypes: [NSPasteboard.PasteboardType("public.url")], items: [item])
        monitor.checkNow()

        XCTAssertEqual(captured.first?.text, "https://onev.cat")
        XCTAssertEqual(captured.first?.payloads.map(\.type), ["public.url"])
        XCTAssertEqual(captured.first?.payloads.first?.data, Data("https://onev.cat".utf8))
    }

    // MARK: - Task 8-D: corrupt image payloads never reach storage

    /// Real-world case: an incomplete pasteboard read produced a 4-byte
    /// PNG-magic-only file on disk. The entry must degrade to a text entry.
    func testCorruptImagePayloadDegradesToTextEntry() {
        let item = MockPasteboardItem()
        item.setString("xcode console output", forType: .string)
        item.setData(
            Data([0x89, 0x50, 0x47, 0x0D]), // PNG magic only, 4 bytes
            forType: NSPasteboard.PasteboardType("public.png")
        )
        pasteboard.simulateCopy(
            declaredTypes: [.string, NSPasteboard.PasteboardType("public.png")],
            items: [item]
        )
        monitor.checkNow()

        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured.first?.contentTypes, ["public.utf8-plain-text"])
        XCTAssertTrue(captured.first?.payloads.isEmpty ?? false)
        XCTAssertEqual(captured.first?.text, "xcode console output")
    }

    func testValidImagePayloadIsCaptured() {
        let image = NSImage(size: NSSize(width: 8, height: 8))
        image.lockFocus()
        NSColor.red.setFill()
        NSRect(x: 0, y: 0, width: 8, height: 8).fill()
        image.unlockFocus()
        let png = NSBitmapImageRep(data: image.tiffRepresentation!)!
            .representation(using: .png, properties: [:])!
        XCTAssertGreaterThan(png.count, 100)

        let item = MockPasteboardItem()
        item.setData(png, forType: NSPasteboard.PasteboardType("public.png"))
        pasteboard.simulateCopy(declaredTypes: [NSPasteboard.PasteboardType("public.png")], items: [item])
        monitor.checkNow()

        XCTAssertEqual(captured.count, 1)
        XCTAssertEqual(captured.first?.contentTypes, ["public.png"])
        XCTAssertEqual(captured.first?.payloads.count, 1)
    }

    func testCorruptImageWithoutAnyTextIsNotCaptured() {
        let item = MockPasteboardItem()
        item.setData(
            Data([0x89, 0x50, 0x47, 0x0D]),
            forType: NSPasteboard.PasteboardType("public.png")
        )
        pasteboard.simulateCopy(declaredTypes: [NSPasteboard.PasteboardType("public.png")], items: [item])
        monitor.checkNow()

        XCTAssertTrue(captured.isEmpty)
    }

    // MARK: - Task 14: excluded apps + source app name

    func testCopyFromExcludedAppIsSkippedAndAppliesImmediately() {
        monitor.frontmostAppInfo = { ("com.example.secret", "Secret") }
        monitor.excludedBundleIDs = ["com.example.secret"]
        copyText("classified")
        XCTAssertTrue(captured.isEmpty)

        // Removing the app from the exclusion list takes effect on the next
        // poll cycle — no monitor restart (Task 14-B).
        monitor.excludedBundleIDs = []
        copyText("declassified")
        XCTAssertEqual(captured.map(\.text), ["declassified"])
    }

    func testCopyFromNonExcludedAppIsCaptured() {
        monitor.frontmostAppInfo = { ("com.example.plain", "Plain") }
        monitor.excludedBundleIDs = ["com.example.secret"]
        copyText("ordinary")
        XCTAssertEqual(captured.map(\.text), ["ordinary"])
    }

    func testSnapshotCarriesSourceAppName() {
        monitor.frontmostAppInfo = { ("com.example.writer", "Writer") }
        copyText("draft")
        XCTAssertEqual(captured.first?.sourceAppBundleID, "com.example.writer")
        XCTAssertEqual(captured.first?.sourceAppName, "Writer")
    }
}
