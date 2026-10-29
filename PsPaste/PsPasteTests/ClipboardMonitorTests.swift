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

    func testOwnWriteBackIsNotCaptured() {
        monitor.markNextPasteboardWriteAsOwn()
        copyText("own write-back")
        XCTAssertTrue(captured.isEmpty)

        // Only the next change is ignored; later copies capture normally.
        copyText("real copy")
        XCTAssertEqual(captured.map(\.text), ["real copy"])
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
}
