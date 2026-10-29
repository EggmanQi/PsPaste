import SwiftUI

/// The cold-blue skin from the particle.ai-based design doc (UI.md §5.2;
/// source `Docs/UI_新设计.md`, dark accent corrected to #2563EB for white
/// text contrast). Selection is the macOS collection convention: accent
/// fill with white text, no stroke, no shadow.
struct ParticleTheme: Theme {

    let id = "particle"
    let name = "Particle"

    let panelCornerRadius: CGFloat = 12
    let cardCornerRadius: CGFloat = 8

    let cardContentFont = Font.system(size: 13)
    let cardMetaFont = Font.system(size: 11)
    let topBarFont = Font.system(size: 13)
    let hintFont = Font.system(size: 13)
    let emptyStateTitleFont = Font.system(size: 15)
    let emptyStateSubtitleFont = Font.system(size: 13)

    /// Background level 1: panel canvas.
    private let panelBackgroundLight = Color(hex: 0xFFFFFF)
    private let panelBackgroundDark = Color(hex: 0x0B0F17)

    /// Background level 2: unselected cards, solid, with a 1pt border.
    private let cardBackgroundLight = Color(hex: 0xF9FAFB)
    private let cardBackgroundDark = Color(hex: 0x111827)

    private let cardBorderLight = Color(hex: 0xE5E7EB)
    private let cardBorderDark = Color(hex: 0x374151)

    /// Text level 1 (primary) and level 2 (secondary).
    private let primaryTextLight = Color(hex: 0x111827)
    private let primaryTextDark = Color(hex: 0xF9FAFB)
    private let secondaryTextLight = Color(hex: 0x4B5563)
    private let secondaryTextDark = Color(hex: 0x9CA3AF)

    /// Text level 3, reused for the image placeholder surface (judgment).
    private let placeholderLight = Color(hex: 0xF3F4F6)
    private let placeholderDark = Color(hex: 0x1F2937)

    /// accentSoft: accent at 15% (light) / 10% (dark) opacity.
    private let accent = Color(hex: 0x2563EB)

    func panelBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? panelBackgroundDark : panelBackgroundLight
    }

    func cardBackground(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? cardBackgroundDark : cardBackgroundLight
    }

    func cardBorder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? cardBorderDark : cardBorderLight
    }

    func primaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? primaryTextDark : primaryTextLight
    }

    func secondaryText(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? secondaryTextDark : secondaryTextLight
    }

    func placeholder(_ scheme: ColorScheme) -> Color {
        scheme == .dark ? placeholderDark : placeholderLight
    }

    func searchBarBackground(_ scheme: ColorScheme) -> Color {
        accent.opacity(scheme == .dark ? 0.10 : 0.15)
    }

    /// §5.2: accent solid fill + white text/icons, nothing else.
    func selection(_: ColorScheme) -> SelectionStyle {
        SelectionStyle(
            cardFill: accent,
            stroke: .clear,
            strokeWidth: 0,
            shadowRadius: 0,
            shadowY: 0,
            shadowOpacity: 0,
            contentForeground: .white
        )
    }
}
