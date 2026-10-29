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
        static let cornerRadius: CGFloat = 10
        static let padding: CGFloat = 12
        static let contentSpacing: CGFloat = 4
        static let metaSpacing: CGFloat = 6
        static let metaItemSpacing: CGFloat = 4
        static let metaIconSize: CGFloat = 14
        static let borderWidth: CGFloat = 1
        static let doubleTapInterval: TimeInterval = 0.3
        static let contentLineLimit = 8
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
        static let shadowRadius: CGFloat = 4
    }

    enum EmptyState {
        static let spacing: CGFloat = 6
    }

    /// Selected-card styling (UI.md §5.1 v4): the selected card turns solid
    /// white, gains a 2pt system-accent stroke and a restrained shadow — no
    /// fill tint, no scale. Everything switches on the active frame (Task 6's
    /// interaction constraint stands).
    enum Selection {
        static let stroke = Color.accentColor
        static let strokeWidth: CGFloat = 2
        static let shadowRadius: CGFloat = 8
        static let shadowY: CGFloat = 3
        static let shadowOpacity = 0.15
    }

    enum TextStyle {
        static let cardContent = Font.system(.body)
        static let cardMeta = Font.system(.caption)
        static let topBar = Font.system(.body)
    }

    /// Layered palette (UI.md §5.1 v4): translucent cards float on an opaque
    /// panel canvas; selection turns one card solid white with an accent
    /// stroke and a shadow instead of tinting it.
    enum ColorToken {
        /// Panel canvas, a half step darker than the v1 paper so white cards
        /// no longer blend into it.
        static let panelBackgroundLight = Color(hex: 0xF0EEE6)
        static let panelBackgroundDark = Color(hex: 0x1F1C19)

        /// Unselected card: a translucent tint over the panel canvas (judgment
        /// values — the card lifts off the parchment without a solid fill).
        static let cardBackgroundLight = Color.white.opacity(0.5)
        static let cardBackgroundDark = Color.white.opacity(0.1)

        /// Selected card: solid white, one full notch above the translucent
        /// unselected cards (dark: a warmed light step, judgment value).
        static let cardSelectedLight = Color(hex: 0xFFFFFF)
        static let cardSelectedDark = Color(hex: 0xE8E4DC)

        static let cardBorderLight = Color(hex: 0xE3E0D4)
        /// One notch above the unselected dark card surface, mirroring the
        /// light-mode border/card relationship.
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

        static func cardSelected(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? cardSelectedDark : cardSelectedLight
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
