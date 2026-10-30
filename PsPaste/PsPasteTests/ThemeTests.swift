import SwiftUI
import XCTest
@testable import PsPaste

/// Layout invariants of the §5.1 spacing grid: the card cell is square, and
/// the selected card's lift plus the action row slot must fit below the top
/// bar with margins, so nothing hugs the divider or the panel bottom edge.
/// The grid is a cross-theme invariant (UI.md §5.2), so it lives in Metrics,
/// not in any theme.
final class ThemeTests: XCTestCase {

    func testCardIsSquare() {
        XCTAssertEqual(Metrics.Card.height, Metrics.Card.width, accuracy: 0.001)
    }

    func testLiftedCardAndActionRowFitBelowTopBarWithMargins() {
        // Selected layout, top to bottom: lift + top margin, the square card,
        // the action row slot, and the bottom margin must fit inside the area
        // below the top bar with room to spare.
        let stack = Metrics.Card.selectionLift
            + Metrics.Card.verticalMargin
            + Metrics.Card.height
            + Metrics.Card.actionRowSpacing
            + Metrics.Card.actionRowHeight
            + Metrics.Card.bottomInset
        XCTAssertLessThanOrEqual(
            stack,
            Metrics.Panel.height - Metrics.Panel.topBarHeight
        )
    }

    func testVerticalMarginMatchesCardSpacingGrid() {
        XCTAssertEqual(Metrics.Card.verticalMargin, 14, accuracy: 0.001)
        XCTAssertEqual(Metrics.Card.spacing, 14, accuracy: 0.001)
        XCTAssertEqual(Metrics.Card.padding, 12, accuracy: 0.001)
    }

    // MARK: - Theme strategies (Task 11)

    func testParchmentSelectionIsStrokePlusShadowWithoutForegroundOverride() {
        let style = ParchmentTheme().selection(.light)
        XCTAssertEqual(style.strokeWidth, 2, accuracy: 0.001)
        XCTAssertEqual(style.shadowRadius, 8, accuracy: 0.001)
        XCTAssertEqual(style.shadowY, 3, accuracy: 0.001)
        XCTAssertEqual(style.shadowOpacity, 0.15, accuracy: 0.001)
        XCTAssertNil(style.contentForeground)
    }

    func testParticleSelectionIsAccentFillWithWhiteTextNoStrokeNoShadow() {
        for scheme in [ColorScheme.light, .dark] {
            let style = ParticleTheme().selection(scheme)
            XCTAssertEqual(style.strokeWidth, 0, accuracy: 0.001)
            XCTAssertEqual(style.shadowRadius, 0, accuracy: 0.001)
            XCTAssertNotNil(style.contentForeground)
        }
    }

    @MainActor
    func testDefaultRegistryOrderHasParchmentFirst() {
        let manager = ThemeManager(defaults: makeDefaults())
        XCTAssertEqual(manager.themes.count, 2)
        XCTAssertEqual(manager.themes[0].id, "parchment")
        XCTAssertEqual(manager.themes[1].id, "particle")
        XCTAssertEqual(manager.current.id, "parchment")
    }

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: "ThemeTests")!
        defaults.removePersistentDomain(forName: "ThemeTests")
        return defaults
    }
}
