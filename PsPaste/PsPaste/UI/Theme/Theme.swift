import SwiftUI

/// Visual constants for the MVP skin (UI.md §5). All style values live here so the
/// skin can be replaced wholesale later; views must not hardcode them.
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
        static let selectedScale: CGFloat = 1.03
        static let selectionBorderWidth: CGFloat = 2
        static let contentLineLimit = 6
        static let height = Panel.height - Panel.topBarHeight - 24
    }

    enum TextStyle {
        static let cardContent = Font.system(.body)
        static let cardMeta = Font.system(.caption)
        static let topBar = Font.system(.body)
    }

    enum ColorToken {
        static let cardBackground = Color.secondary.opacity(0.12)
        static let selectionBorder = Color.accentColor
        static let placeholder = Color.secondary.opacity(0.15)
    }
}
