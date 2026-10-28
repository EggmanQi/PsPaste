import CoreGraphics
import XCTest
@testable import PsPaste

final class PanelControllerTests: XCTestCase {

    private let panelFrame = CGRect(x: 0, y: 0, width: 1440, height: 320)
    private let selfBundleID = "com.ebs.pspaste"

    func testMouseDownInsidePanelDoesNotClose() {
        XCTAssertFalse(
            PanelController.shouldClose(
                for: .leftMouseDown(at: CGPoint(x: 700, y: 160)),
                panelFrame: panelFrame,
                selfBundleID: selfBundleID
            )
        )
    }

    func testMouseDownOutsidePanelCloses() {
        XCTAssertTrue(
            PanelController.shouldClose(
                for: .leftMouseDown(at: CGPoint(x: 700, y: 400)),
                panelFrame: panelFrame,
                selfBundleID: selfBundleID
            )
        )
    }

    func testActivationOfOtherAppCloses() {
        XCTAssertTrue(
            PanelController.shouldClose(
                for: .applicationActivated(bundleID: "com.apple.Safari"),
                panelFrame: panelFrame,
                selfBundleID: selfBundleID
            )
        )
    }

    func testActivationOfSelfDoesNotClose() {
        XCTAssertFalse(
            PanelController.shouldClose(
                for: .applicationActivated(bundleID: selfBundleID),
                panelFrame: panelFrame,
                selfBundleID: selfBundleID
            )
        )
    }
}
