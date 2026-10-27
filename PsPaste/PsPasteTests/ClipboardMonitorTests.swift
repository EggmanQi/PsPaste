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
}
