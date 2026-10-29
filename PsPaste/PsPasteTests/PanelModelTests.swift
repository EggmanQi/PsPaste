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

    // MARK: - Task 7: search summons collapsed, every show resets it

    @MainActor
    func testSearchStartsCollapsedAndPrepareForShowResetsIt() {
        let model = PanelModel()
        XCTAssertFalse(model.searchExpanded)

        model.searchExpanded = true
        model.prepareForShow()
        XCTAssertFalse(model.searchExpanded)
    }

    // MARK: - Task 9: panel summons with no selection

    private func makeItem(_ text: String) -> ClipboardItem {
        ClipboardItem(
            sourceDevice: "test",
            contentTypes: ["public.utf8-plain-text"],
            text: text,
            contentHash: text
        )
    }

    @MainActor
    func testNoSelectionByDefaultEvenWithItems() {
        let model = PanelModel()
        let items = [makeItem("a"), makeItem("b")]
        XCTAssertNil(model.effectiveSelection(in: items))
        // Return with no selection pastes nothing.
        model.confirmSelection(in: items)
    }

    @MainActor
    func testArrowFromNilSelectsFirstItem() {
        let model = PanelModel()
        let items = [makeItem("a"), makeItem("b")]
        model.moveSelection(in: items, direction: .older)
        XCTAssertEqual(model.effectiveSelection(in: items)?.text, "a")
    }

    @MainActor
    func testFilterKeepsValidSelection() {
        let model = PanelModel()
        let items = [makeItem("apple"), makeItem("banana")]
        model.moveSelection(in: items, direction: .older)
        model.moveSelection(in: items, direction: .older)
        XCTAssertEqual(model.effectiveSelection(in: items)?.text, "banana")

        // Same filtered results: the selection is still in them, so it stays.
        model.updateSelectionAfterFilter(in: items)
        XCTAssertEqual(model.effectiveSelection(in: items)?.text, "banana")
    }

    @MainActor
    func testFilterFallsBackToFirstMatchWhenSelectionDropsOut() {
        let model = PanelModel()
        let banana = makeItem("banana")
        model.selectViaMouse(banana.id)

        let filtered = [makeItem("apple")]
        model.updateSelectionAfterFilter(in: filtered)
        XCTAssertEqual(model.effectiveSelection(in: filtered)?.text, "apple")
    }

    @MainActor
    func testFilterWithEmptyResultsClearsSelection() {
        let model = PanelModel()
        let items = [makeItem("a")]
        model.moveSelection(in: items, direction: .older)

        model.updateSelectionAfterFilter(in: [])
        XCTAssertNil(model.selectedID)
    }
}
