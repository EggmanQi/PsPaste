import Foundation

/// Presentation state for the history panel, shared between `HistoryPanelView`
/// and `PanelController`. All business actions are wired by the app assembly.
@MainActor
@Observable
final class PanelModel {

    nonisolated enum SelectionChangeSource: Equatable {
        case mouseClick
        case keyboardNavigation
        case programmatic
    }

    var searchText = ""
    /// True once the user has entered search input mode (Task 7). The panel
    /// always summons with the collapsed search button; typing a character or
    /// clicking the button (or pressing ⌘F) expands the field.
    var searchExpanded = false
    /// Nil means "follow the newest item"; resolved by the view against current items.
    var selectedID: UUID?
    /// What caused the last selection change; drives scroll-to-visible decisions (Task 6-A).
    private(set) var selectionChangeSource: SelectionChangeSource = .programmatic
    /// True while the "Copied — press ⌘V to paste" hint is visible (no AX permission).
    var showsManualPasteHint = false

    /// Wired by the app: marks the write-back as own, restores representations, etc.
    var onRestore: ((ClipboardItem) -> Void)?
    /// Wired by `PanelController`.
    var onRequestClose: (() -> Void)?

    /// Called by the controller right before the panel is shown.
    func prepareForShow() {
        selectedID = nil
        selectionChangeSource = .programmatic
        showsManualPasteHint = false
        // Every summon starts from the collapsed search button (Task 7).
        searchExpanded = false
    }

    /// Mouse click on a card: instant selection, no scroll-to-visible (Task 6-A).
    func selectViaMouse(_ id: UUID) {
        selectionChangeSource = .mouseClick
        selectedID = id
    }

    func moveSelection(in items: [ClipboardItem], direction: SelectionDirection) {
        guard !items.isEmpty else { selectedID = nil; return }
        let ids = items.map(\.id)
        selectionChangeSource = .keyboardNavigation
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

    // MARK: - Pure decision logic (Task 6)

    /// Scroll gate for selection changes: a clicked card is visible by
    /// construction, so an animated `scrollTo` after a click was the perceived
    /// selection lag. Keyboard navigation keeps smooth scrolling; programmatic
    /// changes scroll only when the target is off-screen.
    nonisolated static func shouldScrollToSelection(
        source: SelectionChangeSource,
        isTargetVisible: Bool
    ) -> Bool {
        switch source {
        case .keyboardNavigation:
            return true
        case .mouseClick, .programmatic:
            return !isTargetVisible
        }
    }

    /// Key routing for type-to-search (UI.md §2.3): printable character presses
    /// append to the search text (focusing the field first); functional keys
    /// and command-modified shortcuts never append.
    nonisolated static func searchAppendText(
        forCharacters characters: String,
        hasCommandModifiers: Bool
    ) -> String? {
        guard !hasCommandModifiers,
              !characters.isEmpty,
              characters.rangeOfCharacter(from: .controlCharacters) == nil else {
            return nil
        }
        return characters
    }

    enum SelectionDirection {
        case newer, older

        var offset: Int { self == .newer ? -1 : 1 }
    }
}
