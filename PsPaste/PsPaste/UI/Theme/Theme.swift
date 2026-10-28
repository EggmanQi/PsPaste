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
    }

    enum Card {
        static let width: CGFloat = 240
        static let spacing: CGFloat = 12
        static let cornerRadius: CGFloat = 10
        static let padding: CGFloat = 10
        static let metaSpacing: CGFloat = 6
        static let metaIconSize: CGFloat = 14
        static let borderWidth: CGFloat = 1
        static let doubleTapInterval: TimeInterval = 0.3
        static let contentLineLimit = 6
        static let height = Panel.height - Panel.topBarHeight - 24
    }

    /// Selected-card styling (UI.md §5.1): 2pt stroke + 8% accent fill + slight
    /// scale. Light mode uses ink blue, dark mode light steel blue for contrast.
    enum Selection {
        static let strokeLight = Color(hex: 0x1B365D)
        static let strokeDark = Color(hex: 0x5B7DB1)
        static let fillOpacity = 0.08
        static let scale: CGFloat = 1.02
        static let strokeWidth: CGFloat = 2
        /// Selection styling switches on the same frame; only scale may animate, fast.
        static let animation = Animation.easeOut(duration: 0.1)

        static func stroke(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? strokeDark : strokeLight
        }

        static func fill(_ scheme: ColorScheme) -> Color {
            stroke(scheme).opacity(fillOpacity)
        }
    }

    enum TextStyle {
        static let cardContent = Font.system(.body)
        static let cardMeta = Font.system(.caption)
        static let topBar = Font.system(.body)
    }

    /// Layered palette (UI.md §5.1): panel tint over material, then cards one
    /// notch above, then the selected card. Warm paper in light mode, warm dark
    /// grays (never pure black) in dark mode.
    enum ColorToken {
        static let panelTintLight = Color(hex: 0xF5F4ED).opacity(0.75)
        static let panelTintDark = Color(hex: 0x26221E).opacity(0.72)

        static let cardBackgroundLight = Color(hex: 0xFAF9F4)
        static let cardBackgroundDark = Color(hex: 0x37332D)

        static let cardBorderLight = Color(hex: 0xE3E0D4)
        static let cardBorderDark = Color(hex: 0x4A443C)

        static let placeholder = Color.secondary.opacity(0.15)

        /// Icon-state search field background (top bar).
        static let searchBarBackground = Color.secondary.opacity(0.12)

        static func panelTint(_ scheme: ColorScheme) -> Color {
            scheme == .dark ? panelTintDark : panelTintLight
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
    /// Hex RGB color, e.g. `Color(hex: 0x1B365D)`. Theme-internal helper.
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}
