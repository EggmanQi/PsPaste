import XCTest
@testable import PsPaste

final class PanelModelTests: XCTestCase {

    // MARK: - Task 6-A: scroll gate for selection changes

    func testMouseClickOnVisibleCardDoesNotScroll() {
        XCTAssertFalse(
            PanelModel.shouldScrollToSelection(source: .mouseClick, isTargetVisible: true)
        )
    }

    func testMouseClickOnInvisibleCardScrolls() {
        XCTAssertTrue(
            PanelModel.shouldScrollToSelection(source: .mouseClick, isTargetVisible: false)
        )
    }

    func testKeyboardNavigationKeepsSmoothScrolling() {
        XCTAssertTrue(
            PanelModel.shouldScrollToSelection(source: .keyboardNavigation, isTargetVisible: true)
        )
        XCTAssertTrue(
            PanelModel.shouldScrollToSelection(source: .keyboardNavigation, isTargetVisible: false)
        )
    }

    func testProgrammaticChangeScrollsOnlyWhenInvisible() {
        XCTAssertFalse(
            PanelModel.shouldScrollToSelection(source: .programmatic, isTargetVisible: true)
        )
        XCTAssertTrue(
            PanelModel.shouldScrollToSelection(source: .programmatic, isTargetVisible: false)
        )
    }

    // MARK: - Task 6-B: printable-character routing to search

    func testPrintableCharacterRoutesToSearch() {
        XCTAssertEqual(
            PanelModel.searchAppendText(forCharacters: "a", hasCommandModifiers: false),
            "a"
        )
        XCTAssertEqual(
            PanelModel.searchAppendText(forCharacters: "Hello", hasCommandModifiers: false),
            "Hello"
        )
    }

    func testCommandModifiedKeyDoesNotAppend() {
        XCTAssertNil(
            PanelModel.searchAppendText(forCharacters: "f", hasCommandModifiers: true)
        )
    }

    func testEmptyAndControlCharactersDoNotAppend() {
        XCTAssertNil(
            PanelModel.searchAppendText(forCharacters: "", hasCommandModifiers: false)
        )
        XCTAssertNil(
            PanelModel.searchAppendText(forCharacters: "\u{1b}", hasCommandModifiers: false)
        )
        XCTAssertNil(
            PanelModel.searchAppendText(forCharacters: "\t", hasCommandModifiers: false)
        )
    }
}
