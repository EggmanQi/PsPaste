import SwiftData
import SwiftUI

/// The horizontally scrolling history strip (UI.md §2.1/§2.2). Owns the
/// SwiftData query so the search filter lives in the store as a
/// `#Predicate` (Task 14-C, full search: text + source app name): a
/// `Predicate` is fixed at `Query` creation time, so `HistoryPanelView`
/// re-creates this view — by trimmed search identity — whenever the search
/// text changes. Between rebuilds the plain `@Query` keeps the results
/// live-updating on every database change, preserving the previous
/// realtime semantics.
struct HistoryItemsView: View {
    let model: PanelModel
    let store: ClipboardStore

    /// Newest first; unfiltered when the search term is empty.
    @Query private var items: [ClipboardItem]

    init(model: PanelModel, store: ClipboardStore, searchText: String) {
        self.model = model
        self.store = store
        let term = searchText.trimmingCharacters(in: .whitespaces)
        if term.isEmpty {
            _items = Query(sort: \ClipboardItem.createdAt, order: .reverse)
        } else {
            _items = Query(
                filter: ClipboardItem.searchPredicate(matching: term),
                sort: \ClipboardItem.createdAt,
                order: .reverse
            )
        }
    }

    /// Identity for the parent-side `.id`: two texts that differ only in
    /// surrounding whitespace must not rebuild the query.
    static func searchKey(for text: String) -> String {
        text.trimmingCharacters(in: .whitespaces)
    }

    private var effectiveSelectedID: UUID? {
        model.effectiveSelection(in: items)?.id
    }

    private var itemIDs: [UUID] { items.map(\.id) }

    var body: some View {
        ScrollViewReader { proxy in
            // Top-aligned row: the per-item insets below reserve the selection
            // lift plus the divider margin above and a bottom-edge margin below,
            // so the lifted card and its action row never touch the panel edges.
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(alignment: .top, spacing: Metrics.Card.spacing) {
                    ForEach(items, id: \.id) { item in
                        let selected = item.id == effectiveSelectedID
                        VStack(spacing: Metrics.Card.actionRowSpacing) {
                            CardView(
                                item: item,
                                isSelected: selected,
                                store: store,
                                onSelect: { model.selectViaMouse(item.id) },
                                onConfirm: { model.confirmSelection(in: items) }
                            )
                            // The selected card rises and reveals its action
                            // row; every card reserves the slot so the grid
                            // never moves when selection changes (§2.2 v5).
                            .offset(y: selected ? -Metrics.Card.selectionLift : 0)

                            CardActionRow(
                                item: item,
                                onCopy: { model.requestCopy(of: item) },
                                onDelete: { model.deleteItem(item, in: items) },
                                onTogglePin: { model.togglePin(of: item) }
                            )
                            .frame(height: Metrics.Card.actionRowHeight)
                            .opacity(selected ? 1 : 0)
                            .allowsHitTesting(selected)
                        }
                        .padding(.top, Metrics.Card.topInset)
                        .padding(.bottom, Metrics.Card.bottomInset)
                        .animation(
                            .easeOut(duration: Metrics.Card.selectionLiftDuration),
                            value: selected
                        )
                        .id(item.id)
                    }
                }
                .padding(.horizontal, Metrics.Card.spacing)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .overlay {
                if items.isEmpty {
                    emptyState
                }
            }
            .onChange(of: itemIDs, initial: true) { _, _ in
                // Mirror for the panel-level key handling (HistoryPanelView
                // owns .onKeyPress but not this query).
                model.filteredItems = items
                // Selection reconciliation (§2.3) while search is active: on
                // summon the panel intentionally has no selection (Task 9),
                // which this same callback must not overwrite.
                guard model.searchExpanded else { return }
                model.updateSelectionAfterFilter(in: items)
            }
            .onChange(of: effectiveSelectedID, initial: false) { _, newValue in
                guard let newValue else { return }
                let source = model.selectionChangeSource
                // A clicked card is on screen by definition; gating the scroll
                // here removes the animated scrollTo that felt like click lag (Task 6-A).
                guard PanelModel.shouldScrollToSelection(
                    source: source,
                    isTargetVisible: source == .mouseClick
                ) else { return }
                withAnimation(Metrics.Panel.animation) {
                    proxy.scrollTo(newValue)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Metrics.EmptyState.spacing) {
            Text("Copy something to get started")
                .font(theme.emptyStateTitleFont)
            Text("Press \(settings.hotKeyBinding.displayText) anywhere to open this panel")
                .font(theme.emptyStateSubtitleFont)
                .foregroundStyle(theme.secondaryText(colorScheme))
        }
    }

    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    @Environment(AppSettings.self) private var settings

    private var theme: any Theme { themeManager.current }
}
