import XCTest
@testable import PsPaste

/// Layout invariants of the §5.1 v2 spacing grid: the card row must float with
/// symmetric vertical margins inside the history area, never hug the divider
/// or leave a dead strip at the panel bottom.
final class ThemeTests: XCTestCase {

    func testCardHeightPlusVerticalMarginsFillsAreaBelowTopBar() {
        XCTAssertEqual(
            Theme.Card.height + 2 * Theme.Card.verticalMargin,
            Theme.Panel.height - Theme.Panel.topBarHeight,
            accuracy: 0.001
        )
    }

    func testVerticalMarginMatchesCardSpacingGrid() {
        XCTAssertEqual(Theme.Card.verticalMargin, 14, accuracy: 0.001)
        XCTAssertEqual(Theme.Card.spacing, 14, accuracy: 0.001)
        XCTAssertEqual(Theme.Card.padding, 12, accuracy: 0.001)
    }
}
