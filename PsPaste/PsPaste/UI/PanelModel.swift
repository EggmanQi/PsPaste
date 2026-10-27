import Foundation

/// Presentation state for the history panel, shared between `HistoryPanelView`
/// and `PanelController`. All business actions are wired by the app assembly.
@MainActor
@Observable
final class PanelModel {

    var searchText = ""
    /// Nil means "follow the newest item"; resolved by the view against current items.
    var selectedID: UUID?
    /// Bumped by `PanelController` on every show so the view re-focuses the search field.
    var focusSignal = 0
    /// True while the "Copied — press ⌘V to paste" hint is visible (no AX permission).
    var showsManualPasteHint = false

    /// Wired by the app: marks the write-back as own, restores representations, etc.
    var onRestore: ((ClipboardItem) -> Void)?
    /// Wired by `PanelController`.
    var onRequestClose: (() -> Void)?

    /// Called by the controller right before the panel is shown.
    func prepareForShow() {
        selectedID = nil
        showsManualPasteHint = false
    }

    func moveSelection(in items: [ClipboardItem], direction: SelectionDirection) {
        guard !items.isEmpty else { selectedID = nil; return }
        let ids = items.map(\.id)
        guard let selectedID, let index = ids.firstIndex(of: selectedID) else {
            self.selectedID = ids.first
            return
        }
        let next = min(max(index + direction.offset, 0), ids.count - 1)
        self.selectedID = ids[next]
    }

    /// Return / double-click on the effective selection.
    func confirmSelection(in items: [ClipboardItem]) {
        guard let item = effectiveSelection(in: items) else { return }
        onRestore?(item)
        onRequestClose?()
    }

    /// Esc: clear search first, close only when search is already empty.
    func handleEscape() {
        if searchText.isEmpty {
            onRequestClose?()
        } else {
            searchText = ""
        }
    }

    func effectiveSelection(in items: [ClipboardItem]) -> ClipboardItem? {
        guard !items.isEmpty else { return nil }
        if let selectedID, let item = items.first(where: { $0.id == selectedID }) {
            return item
        }
        return items.first
    }

    enum SelectionDirection {
        case newer, older

        var offset: Int { self == .newer ? -1 : 1 }
    }
}
