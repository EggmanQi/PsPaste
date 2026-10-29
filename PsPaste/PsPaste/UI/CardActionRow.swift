import SwiftUI

/// The action icon row that floats under the selected card (UI.md §2.2 v5,
/// replacing the deferred context menu): copy back, delete, pin/unpin, and a
/// disabled share placeholder. Only the selected card's row is visible and
/// interactive — the slot is reserved on every card so the grid never moves.
struct CardActionRow: View {
    let item: ClipboardItem
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onTogglePin: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    private var theme: any Theme { themeManager.current }

    var body: some View {
        HStack(spacing: Metrics.Card.actionRowSpacing) {
            actionButton("doc.on.doc", action: onCopy)
            actionButton("trash", action: onDelete)
            actionButton(
                item.isPinned ? "pin.fill" : "pin",
                action: onTogglePin
            )
            Button(action: {}) {
                Image(systemName: "square.and.arrow.up")
            }
            .disabled(true)
            .help("Coming soon")
        }
        .font(theme.topBarFont)
        .foregroundStyle(theme.secondaryText(colorScheme))
    }

    private func actionButton(_ systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .frame(
                    width: Metrics.Card.actionIconSize,
                    height: Metrics.Card.actionIconSize
                )
        }
    }
}
