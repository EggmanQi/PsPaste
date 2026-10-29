import SwiftData
import SwiftUI

/// Bottom history panel content (UI.md §2). Hosted inside `PanelController`'s NSPanel.
struct HistoryPanelView: View {
    @Bindable var model: PanelModel
    let store: ClipboardStore

    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var allItems: [ClipboardItem]
    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    /// Text-field filtering (simple search; full search is M2).
    private var items: [ClipboardItem] {
        let term = model.searchText.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return allItems }
        return allItems.filter { $0.text?.localizedCaseInsensitiveContains(term) == true }
    }

    private var effectiveSelectedID: UUID? {
        model.effectiveSelection(in: items)?.id
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            historyArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // §5.1: opaque Kami parchment canvas (solid warm paper, Task 7).
        .background(Theme.ColorToken.panelBackground(colorScheme))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: Theme.Panel.cornerRadius,
                topTrailingRadius: Theme.Panel.cornerRadius
            )
        )
        .contentShape(Rectangle())
        .onKeyPress { press in pressHandler(press) }
        .onChange(of: model.searchText, initial: false) { _, _ in
            // Filter results keep a valid selection, else land on the first
            // match, so typing never leaves Return without a target (§2.3).
            model.updateSelectionAfterFilter(in: items)
        }
        .overlay(alignment: .top) {
            if model.showsManualPasteHint {
                Text("Copied — press ⌘V to paste")
                    .font(.subheadline)
                    .padding(.horizontal, Theme.Hint.horizontalPadding)
                    .padding(.vertical, Theme.Hint.verticalPadding)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 4)
                    .padding(.top, Theme.Hint.topPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Theme.Panel.animation, value: model.showsManualPasteHint)
    }

    private var topBar: some View {
        HStack(spacing: Theme.Panel.topBarItemSpacing) {
            // Search slot (UI.md §2.3, Task 7): summons as a collapsed button;
            // clicking it, typing a character, or pressing ⌘F expands the field.
            searchSlot
            Spacer()
            Button("Pinboard") {}
                .disabled(true)
                .opacity(Theme.Control.disabledOpacity)
            Button(action: {}) {
                Image(systemName: "gearshape")
            }
            .disabled(true)
            .opacity(Theme.Control.disabledOpacity)
        }
        .font(Theme.TextStyle.topBar)
        .frame(height: Theme.Panel.topBarHeight)
        .padding(.horizontal, Theme.Panel.topBarHorizontalPadding)
    }

    /// One fixed-height slot for both search states: collapsed icon button or
    /// expanded input field, same capsule fill, so the swap does not reflow
    /// the bar.
    private var searchSlot: some View {
        HStack(spacing: Theme.SearchSlot.iconSpacing) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Theme.ColorToken.secondaryText(colorScheme))
            if model.searchExpanded {
                TextField("Search clipboard history", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { model.confirmSelection(in: items) }
            }
        }
        .padding(.horizontal, Theme.SearchSlot.horizontalPadding)
        .padding(.vertical, Theme.SearchSlot.verticalPadding)
        .background(Theme.ColorToken.searchBarBackground(colorScheme), in: Capsule())
        .contentShape(Capsule())
        .onTapGesture {
            guard !model.searchExpanded else { return }
            model.searchExpanded = true
        }
        .onChange(of: model.searchExpanded, initial: true) { _, expanded in
            searchFocused = expanded
        }
    }

    private var historyArea: some View {
        ScrollViewReader { proxy in
            // No fixed height here: the area fills the space below the top bar
            // and the card row centers inside it, leaving verticalMargin above
            // and below (§5.1 v2 spacing grid) instead of hugging the divider.
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: Theme.Card.spacing) {
                    ForEach(items, id: \.id) { item in
                        CardView(
                            item: item,
                            isSelected: item.id == effectiveSelectedID,
                            store: store,
                            onSelect: { model.selectViaMouse(item.id) },
                            onConfirm: { model.confirmSelection(in: items) }
                        )
                        .id(item.id)
                    }
                }
                .padding(.horizontal, Theme.Card.spacing)
                .frame(height: Theme.Card.height)
                .frame(maxHeight: .infinity)
            }
            .overlay {
                if items.isEmpty {
                    emptyState
                }
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
                withAnimation(Theme.Panel.animation) {
                    proxy.scrollTo(newValue)
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Theme.EmptyState.spacing) {
            Text("Copy something to get started")
                .font(.headline)
            Text("Press ⌘⇧` anywhere to open this panel")
                .font(.subheadline)
                .foregroundStyle(Theme.ColorToken.secondaryText(colorScheme))
        }
    }

    /// Panel-level keys (UI.md §2.3); typing falls through to the search field.
    private func pressHandler(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .escape:
            model.handleEscape()
            return .handled
        case .leftArrow:
            model.moveSelection(in: items, direction: .newer)
            return .handled
        case .rightArrow:
            model.moveSelection(in: items, direction: .older)
            return .handled
        case .return:
            model.confirmSelection(in: items)
            return .handled
        default:
            if press.key == "f", press.modifiers.contains(.command) {
                model.searchExpanded = true
                return .handled
            }
            // Type-to-search (UI.md §2.3): printable characters expand the slot
            // and append to the search text; functional keys and ⌘ shortcuts
            // pass through.
            if let text = PanelModel.searchAppendText(
                forCharacters: press.characters,
                hasCommandModifiers: press.modifiers.contains(.command)
            ) {
                model.searchExpanded = true
                model.searchText.append(text)
                return .handled
            }
            return .ignored
        }
    }
}
