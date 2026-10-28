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
        .background {
            // §5.1: translucent material with a warm tint layered on top.
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                Theme.ColorToken.panelTint(colorScheme)
            }
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: Theme.Panel.cornerRadius,
                topTrailingRadius: Theme.Panel.cornerRadius
            )
        )
        .contentShape(Rectangle())
        .onKeyPress { press in pressHandler(press) }
        .overlay(alignment: .top) {
            if model.showsManualPasteHint {
                Text("Copied — press ⌘V to paste")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: 4)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Theme.Panel.animation, value: model.showsManualPasteHint)
    }

    private var topBar: some View {
        HStack(spacing: 12) {
            // Icon-state search field: unfocused it reads as magnifier + hint
            // (UI.md §2.3); clicking it (or typing a character) enters input mode.
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search clipboard history", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { model.confirmSelection(in: items) }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Theme.ColorToken.searchBarBackground, in: Capsule())
            Spacer()
            Button("Pinboard") {}
                .disabled(true)
                .opacity(0.4)
            Button(action: {}) {
                Image(systemName: "gearshape")
            }
            .disabled(true)
            .opacity(0.4)
        }
        .font(Theme.TextStyle.topBar)
        .frame(height: Theme.Panel.topBarHeight)
        .padding(.horizontal, 16)
    }

    private var historyArea: some View {
        ScrollViewReader { proxy in
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
            }
            .frame(height: Theme.Card.height)
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
        VStack(spacing: 6) {
            Text("Copy something to get started")
                .font(.headline)
            Text("Press ⌘⇧` anywhere to open this panel")
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
            // Type-to-search (UI.md §2.3): printable characters focus the field
            // and append themselves; functional keys and ⌘ shortcuts pass through.
            if let text = PanelModel.searchAppendText(
                forCharacters: press.characters,
                hasCommandModifiers: press.modifiers.contains(.command)
            ) {
                searchFocused = true
                model.searchText.append(text)
                return .handled
            }
            return .ignored
        }
    }
}
