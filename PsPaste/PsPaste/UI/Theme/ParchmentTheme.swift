import SwiftUI

/// The default warm-paper skin (UI.md §5.1 v4). All values migrated verbatim
/// from the former static `Theme` enum — Parchment must render pixel-identical
/// to the pre-theme-system build.
struct ParchmentTheme: Theme {

    let id = "parchment"
    let name = "Parchment"

    let panelCornerRadius: CGFloat = 14
    let cardCornerRadius: CGFloat = 10

    let cardContentFont = Font.system(.body)
    let cardMetaFont = Font.system(.caption)
    let topBarFont = Font.system(.body)
    let hintFont = Font.system(.subheadline)
    let emptyStateTitleFont = Font.system(.headline)
    let emptyStateSubtitleFont = Font.system(.subheadline)

    /// Panel canvas, a half step darker than the v1 paper so white cards
    /// no longer blend into it.
    private let panelBackgroundLight = Color(hex: 0xF0EEE6)
    private let panelBackgroundDark = Color(hex: 0x1F1C19)

    /// Unselected card: a translucent tint over the panel canvas (judgment
    /// values — the card lifts off the parchment without a solid fill).
    private let cardBackgroundLight = Color.white.opacity(0.5)
    private let cardBackgroundDark = Color.white.opacity(0.1)

    private let cardBorderLight = Color(hex: 0xE3E0D4)
    /// One notch above the unselected dark card surface, mirroring the
    /// light-mode border/card relationship.
    private let cardBorderDark = Color(hex: 0x453E35)

    /// Muted text/icons: warm gray with a yellow-brown undertone (Kami),
    /// not the cool neutral `.secondary`.
    private let secondaryTextLight = Color(hex: 0x6E6759)
    private let secondaryTextDark = Color(hex: 0xA8A091)

    func panelBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? panelBackgroundDark : panelBackgroundLight
    }

    func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? cardBackgroundDark : cardBackgroundLight
    }

    func cardBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? cardBorderDark : cardBorderLight
    }

    func primaryText(_: ColorScheme) -> Color { .primary }

    func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? secondaryTextDark : secondaryTextLight
    }

    func placeholder(_: ColorScheme) -> Color {
        Color.secondary.opacity(0.15)
    }

    func searchBarBackground(_ scheme: ColorScheme) -> Color {
        secondaryText(scheme).opacity(0.12)
    }

    /// §5.1 v4: solid white card + 2pt system-accent stroke + restrained
    /// shadow. Text keeps its normal label colors.
    func selection(_ scheme: ColorScheme) -> SelectionStyle {
        SelectionStyle(
            cardFill: scheme == .dark ? Color(hex: 0xE8E4DC) : Color(hex: 0xFFFFFF),
            stroke: Color.accentColor,
            strokeWidth: 2,
            shadowRadius: 8,
            shadowY: 3,
            shadowOpacity: 0.15,
            contentForeground: nil
        )
    }
}
