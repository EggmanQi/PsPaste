import AppKit
import XCTest
@testable import PsPaste

final class PasteServiceTests: XCTestCase {

    func testTrustedPermissionChoosesDirectPaste() {
        XCTAssertEqual(PasteService.action(isAccessibilityTrusted: true), .directPaste)
    }

    func testUntrustedPermissionChoosesCopyOnly() {
        XCTAssertEqual(PasteService.action(isAccessibilityTrusted: false), .copyOnly)
    }

    func testRestoreWritesTextAndPayloadRepresentations() {
        let item = ClipboardItem(
            sourceDevice: "test",
            contentTypes: ["public.utf8-plain-text", "public.png"],
            text: "restore me",
            contentHash: "hash"
        )
        let imageData = Data([0x89, 0x50, 0x4E, 0x47])
        PasteService.restoreToGeneralPasteboard(item, payloads: [("public.png", imageData)])

        let pasteboard = NSPasteboard.general
        XCTAssertEqual(pasteboard.string(forType: .string), "restore me")
        XCTAssertEqual(
            pasteboard.data(forType: NSPasteboard.PasteboardType("public.png")),
            imageData
        )
    }
}
