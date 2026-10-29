import SwiftUI

/// Visual constants for the MVP skin (UI.md §5/§5.1). All style values live here
/// so the skin can be replaced wholesale later; views must not hardcode them.
enum Theme {

    enum Panel {
        static let height: CGFloat = 320
        static let topBarHeight: CGFloat = 40
        static let cornerRadius: CGFloat = 14
        static let slideOffset: CGFloat = 16
        static let animationDuration: TimeInterval = 0.18
        static let animation = Animation.easeOut(duration: animationDuration)
        static let topBarHorizontalPadding: CGFloat = 16
        static let topBarItemSpacing: CGFloat = 12
    }

    /// Shared control states (currently only used by the disabled placeholder
    /// buttons in the panel top bar).
    enum Control {
        static let disabledOpacity = 0.4
    }

    enum Card {
        static let width: CGFloat = 240
        static let spacing: CGFloat = 14
        static let cornerRadius: CGFloat = 10
        static let padding: CGFloat = 12
        static let contentSpacing: CGFloat = 4
        static let metaSpacing: CGFloat = 6
        static let metaItemSpacing: CGFloat = 4
        static let metaIconSize: CGFloat = 14
        static let borderWidth: CGFloat = 1
        static let doubleTapInterval: TimeInterval = 0.3
        static let contentLineLimit = 6
        /// Breathing room between the card row and the divider / panel bottom
        /// edge (§5.1 v2 spacing grid). The history area centers the card row,
        /// so `height` plus twice this margin must equal the area below the
        /// top bar.
        static let verticalMargin: CGFloat = 14
        static let height = Panel.height - Panel.topBarHeight - 2 * verticalMargin
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
    }

    enum EmptyState {
        static let spacing: CGFloat = 6
    }

    /// Selected-card styling (UI.md §5.1 v2): system-accent stroke + 15% fill
    /// + slight scale. macOS collections highlight with the accent color, not a
    /// custom ring (HIG focus-and-selection; color.md: controlAccentColor).
    enum Selection {
        static let fillOpacity = 0.15
        static let scale: CGFloat = 1.02
        static let strokeWidth: CGFloat = 2
        /// Selection styling switches on the same frame; only scale may animate, fast.
        static let animation = Animation.easeOut(duration: 0.1)

        static let stroke = Color.accentColor

        static var fill: Color { stroke.opacity(fillOpacity) }
    }

    enum TextStyle {
        static let cardContent = Font.system(.body)
        static let cardMeta = Font.system(.caption)
        static let topBar = Font.system(.body)
    }

    /// Layered palette (UI.md §5.1 v2): an opaque panel canvas one full step
    /// below the cards, then the selected card in the system accent. Adjacent
    /// layers must be distinguishable at a glance (HIG layout: visual hierarchy).
    enum ColorToken {
        /// Panel canvas, a half step darker than the v1 paper so white cards
        /// no longer blend into it.
        static let panelBackgroundLight = Color(hex: 0xF0EEE6)
        static let panelBackgroundDark = Color(hex: 0x1F1C19)

        static let cardBackgroundLight = Color(hex: 0xFFFFFF)
        static let cardBackgroundDark = Color(hex: 0x332E29)

        static let cardBorderLight = Color(hex: 0xE3E0D4)
        /// One notch above the new darker card (#332E29), mirroring the light
        /// mode border/card relationship.
        static let cardBorderDark = Color(hex: 0x453E35)

        /// Muted text/icons: warm gray with a yellow-brown undertone (Kami),
        /// not the cool neutral `.secondary`.
        static let secondaryTextLight = Color(hex: 0x6E6759)
        static let secondaryTextDark = Color(hex: 0xA8A091)

        static let placeholder = Color.secondary.opacity(0.15)

        /// Collapsed search button / expanded search field capsule fill.
        static func searchBarBackground(_ scheme: ColorScheme) -> Color {
            secondaryText(scheme).opacity(0.12)
        }

        static func panelBackground(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? panelBackgroundDark : panelBackgroundLight
        }

        static func secondaryText(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? secondaryTextDark : secondaryTextLight
        }

        static func cardBackground(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? cardBackgroundDark : cardBackgroundLight
        }

        static func cardBorder(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? cardBorderDark : cardBorderLight
        }
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
