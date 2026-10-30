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
    /// Nil means "no selection": the panel summons unselected and Return
    /// pastes nothing until the user picks a card (arrows or click).
    var selectedID: UUID?
    /// What caused the last selection change; drives scroll-to-visible decisions (Task 6-A).
    private(set) var selectionChangeSource: SelectionChangeSource = .programmatic
    /// True while the "Copied — press ⌘V to paste" hint is visible (no AX permission).
    var showsManualPasteHint = false
    /// Mirror of the filtered query results, maintained by `HistoryItemsView`.
    /// The panel-level key handling (`HistoryPanelView` owns `.onKeyPress`)
    /// and the search field's submit action read this instead of the query.
    var filteredItems: [ClipboardItem] = []

    /// Wired by the app: marks the write-back as own, restores representations, etc.
    var onRestore: ((ClipboardItem) -> Void)?
    /// Wired by `PanelController`.
    var onRequestClose: (() -> Void)?
    /// Wired by the app: the v5 action row (UI.md §2.2) — copy-only write-back,
    /// pin toggle, delete. Business effects stay in the assembly, not the UI.
    var onCopyOnly: ((ClipboardItem) -> Void)?
    var onTogglePin: ((ClipboardItem) -> Void)?
    var onDelete: ((ClipboardItem) -> Void)?
    /// Wired by the app: ⌘, opens the settings window (UI.md §2.3/§4).
    var onOpenSettings: (() -> Void)?

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

    /// Return / double-click on the effective selection. The restore handler
    /// decides when the panel closes: at once before a direct paste, after
    /// the manual-paste hint when pasting is not permitted.
    func confirmSelection(in items: [ClipboardItem]) {
        guard let item = effectiveSelection(in: items) else { return }
        onRestore?(item)
    }

    /// Esc: clear search first, close only when search is already empty.
    func handleEscape() {
        if searchText.isEmpty {
            onRequestClose?()
        } else {
            searchText = ""
        }
    }

    /// Action row: write back to the pasteboard without pasting, closing, or
    /// re-recording history (UI.md §2.2 v5).
    func requestCopy(of item: ClipboardItem) {
        onCopyOnly?(item)
    }

    func togglePin(of item: ClipboardItem) {
        onTogglePin?(item)
    }

    /// Action row delete: the selection falls back to the neighbor card —
    /// the next older item takes the freed slot, else the previous newer one.
    func deleteItem(_ item: ClipboardItem, in items: [ClipboardItem]) {
        onDelete?(item)
        guard selectedID == item.id else { return }
        selectionChangeSource = .programmatic
        selectedID = Self.selectionAfterDelete(of: item.id, in: items.map(\.id))
    }

    /// Selection fallback after removal, a pure function.
    nonisolated static func selectionAfterDelete(of id: UUID, in ids: [UUID]) -> UUID? {
        guard let index = ids.firstIndex(of: id) else { return nil }
        if index + 1 < ids.count { return ids[index + 1] }
        return index > 0 ? ids[index - 1] : nil
    }

    /// The current selection, or nil when nothing is selected. No fallback:
    /// a nil ID stays nil even when items exist (UI.md §2.3 — the panel
    /// summons unselected).
    func effectiveSelection(in items: [ClipboardItem]) -> ClipboardItem? {
        guard let selectedID else { return nil }
        return items.first(where: { $0.id == selectedID })
    }

    /// Search filter reconciliation (UI.md §2.3): keep the selection while it
    /// is still in the filtered results; when it fell out, land on the first
    /// match so typing never leaves Return without a target.
    func updateSelectionAfterFilter(in items: [ClipboardItem]) {
        if effectiveSelection(in: items) != nil { return }
        selectionChangeSource = .programmatic
        selectedID = items.first?.id
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
