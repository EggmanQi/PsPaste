import SwiftUI

/// A visual skin for the whole app (UI.md §5.2): color tokens, fonts, corner
/// radii, and the selection drawing strategy. Layout metrics that must stay
/// identical across themes (card grid, spacings, panel geometry) live in
/// `Metrics` and are deliberately not part of a theme.
protocol Theme {

    /// Stable identifier, persisted in UserDefaults (`selectedTheme`).
    var id: String { get }
    /// Display name in the theme switcher menu.
    var name: String { get }

    // MARK: Geometry (theme-specific)

    var panelCornerRadius: CGFloat { get }
    var cardCornerRadius: CGFloat { get }

    // MARK: Fonts (semantic roles)

    var cardContentFont: Font { get }
    var cardMetaFont: Font { get }
    var topBarFont: Font { get }
    var hintFont: Font { get }
    var emptyStateTitleFont: Font { get }
    var emptyStateSubtitleFont: Font { get }

    // MARK: Colors (per color scheme)

    func panelBackground(_ scheme: ColorScheme) -> Color
    func cardBackground(_ scheme: ColorScheme) -> Color
    func cardBorder(_ scheme: ColorScheme) -> Color
    func primaryText(_ scheme: ColorScheme) -> Color
    func secondaryText(_ scheme: ColorScheme) -> Color
    func placeholder(_ scheme: ColorScheme) -> Color
    /// Collapsed search button / expanded search field capsule fill.
    func searchBarBackground(_ scheme: ColorScheme) -> Color

    // MARK: Selection strategy

    func selection(_ scheme: ColorScheme) -> SelectionStyle
}

/// Everything the card rendering needs to draw the selected state
/// (UI.md §5.1 v4 for Parchment, §5.2 for Particle). A zero strokeWidth or
/// shadowRadius means the feature is absent.
struct SelectionStyle: Equatable {
    /// Selected card surface fill.
    var cardFill: Color
    /// Selected card stroke color and width.
    var stroke: Color
    var strokeWidth: CGFloat
    /// Restrained lift shadow.
    var shadowRadius: CGFloat
    var shadowY: CGFloat
    var shadowOpacity: Double
    /// Text/icon color override on the selected card; nil keeps the normal
    /// label/secondary colors (Parchment). Particle sets white.
    var contentForeground: Color?
}

/// Layout constants shared by every theme (UI.md §5.2: card layout, spacing
/// grid, and panel geometry are invariants). All style values live here or in
/// a `Theme` so a skin can be replaced wholesale; views must not hardcode them.
enum Metrics {

    enum Panel {
        /// v5 (UI.md §2.1): raised from 320 to make room for the selected
        /// card's lift and the action icon row below it.
        static let height: CGFloat = 400
        static let topBarHeight: CGFloat = 40
        static let slideOffset: CGFloat = 16
        static let animationDuration: TimeInterval = 0.18
        static let animation = Animation.easeOut(duration: animationDuration)
        static let topBarHorizontalPadding: CGFloat = 16
        static let topBarItemSpacing: CGFloat = 12
        /// Width of the icon-only theme menu button (.borderlessButton).
        static let themeButtonWidth: CGFloat = 24
        /// Sections (top bar / divider / history area) stack flush.
        static let sectionSpacing: CGFloat = 0
    }

    /// Shared control states (currently only used by the disabled placeholder
    /// buttons in the panel top bar).
    enum Control {
        static let disabledOpacity = 0.4
    }

    enum Card {
        static let width: CGFloat = 240
        static let spacing: CGFloat = 14
        static let padding: CGFloat = 12
        static let contentSpacing: CGFloat = 4
        static let metaSpacing: CGFloat = 6
        static let metaItemSpacing: CGFloat = 4
        static let metaIconSize: CGFloat = 14
        static let borderWidth: CGFloat = 1
        static let doubleTapInterval: TimeInterval = 0.3
        static let contentLineLimit = 8
        /// Breathing room between the card row and the divider / panel bottom
        /// edge (§5.1 v4 spacing grid). The history area centers the card row,
        /// so `height` plus twice this margin must equal the area below the
        /// top bar.
        static let verticalMargin: CGFloat = 14
        static let height = Panel.height - Panel.topBarHeight - 2 * verticalMargin

        /// v5 (UI.md §2.2): the selected card rises to make room for the
        /// action icon row in the reserved slot below every card.
        static let selectionLift: CGFloat = 28
        static let selectionLiftDuration: TimeInterval = 0.15
        /// Reserved slot under each card that hosts the selected card's
        /// action icons; the fixed height keeps the row grid stable when
        /// selection moves.
        static let actionRowHeight: CGFloat = 22
        static let actionRowSpacing: CGFloat = 8
        static let actionIconSize: CGFloat = 22
        /// Restrained pin badge on pinned, unselected cards.
        static let pinBadgeSize: CGFloat = 10
        static let pinBadgeInset: CGFloat = 6
    }

    /// The collapsed search button / expanded search field capsule (top bar).
    enum SearchSlot {
        static let iconSpacing: CGFloat = 6
        static let horizontalPadding: CGFloat = 10
        static let verticalPadding: CGFloat = 5
    }

    /// Transient "press ⌘V" hint capsule that drops over the panel top edge.
    enum Hint {
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 6
        static let topPadding: CGFloat = 8
        static let shadowRadius: CGFloat = 4
    }

    enum EmptyState {
        static let spacing: CGFloat = 6
    }
}

extension Color {
    /// Hex RGB color, e.g. `Color(hex: 0xF0EEE6)`. Theme-internal helper.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
