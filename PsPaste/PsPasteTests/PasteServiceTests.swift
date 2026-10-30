import AppKit
import XCTest
@testable import PsPaste

@MainActor
final class PasteServiceTests: XCTestCase {

    private var pasteboard: NSPasteboard!

    override func setUp() {
        super.setUp()
        pasteboard = NSPasteboard(name: NSPasteboard.Name("com.ebs.pspaste.tests.\(UUID().uuidString)"))
    }

    override func tearDown() {
        pasteboard.releaseGlobally()
        pasteboard = nil
        super.tearDown()
    }

    private func makeItem(contentTypes: [String], text: String?) -> ClipboardItem {
        ClipboardItem(sourceDevice: "test", contentTypes: contentTypes, text: text, contentHash: "hash")
    }

    func testTrustedPermissionChoosesDirectPaste() {
        XCTAssertEqual(PasteService.action(isAccessibilityTrusted: true), .directPaste)
    }

    func testUntrustedPermissionChoosesCopyOnly() {
        XCTAssertEqual(PasteService.action(isAccessibilityTrusted: false), .copyOnly)
    }

    func testRestoreWritesTextAndPayloadRepresentations() {
        let item = makeItem(contentTypes: ["public.utf8-plain-text", "public.png"], text: "restore me")
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        PasteService.restore(item, payloads: [("public.png", imageData)], to: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), "restore me")
        XCTAssertEqual(
            pasteboard.data(forType: NSPasteboard.PasteboardType("public.png")),
            imageData
        )
    }

    func testRestoreMarksWriteBackAsTransient() {
        PasteService.restore(
            makeItem(contentTypes: ["public.utf8-plain-text"], text: "own"),
            payloads: [],
            to: pasteboard
        )

        XCTAssertTrue(
            pasteboard.types?.contains(NSPasteboard.PasteboardType("org.nspasteboard.TransientType")) ?? false
        )
    }

    /// End-to-end anti-loop (ARCHITECTURE §4 rule 4): the monitor skips the
    /// write-back by its marker, with no shared state between the two.
    func testMonitorDoesNotRecordWriteBack() {
        let monitor = ClipboardMonitor(pasteboard: pasteboard)
        var captured: [ClipboardSnapshot] = []
        monitor.onCapture = { captured.append($0) }

        PasteService.restore(
            makeItem(contentTypes: ["public.utf8-plain-text"], text: "own"),
            payloads: [],
            to: pasteboard
        )
        monitor.checkNow()

        XCTAssertTrue(captured.isEmpty)
    }

    func testRestoreSpreadsRepeatedTypesOverSeparateItems() {
        let fileA = Data("file:///tmp/a.txt".utf8)
        let fileB = Data("file:///tmp/b.txt".utf8)
        let fileURL = NSPasteboard.PasteboardType("public.file-url")
        PasteService.restore(
            makeItem(contentTypes: ["public.utf8-plain-text", "public.file-url"], text: "a.txt\nb.txt"),
            payloads: [("public.file-url", fileA), ("public.file-url", fileB)],
            to: pasteboard
        )

        let items = pasteboard.pasteboardItems ?? []
        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items.compactMap { $0.data(forType: fileURL) }, [fileA, fileB])
        XCTAssertEqual(items.first?.string(forType: .string), "a.txt\nb.txt")
    }
}
