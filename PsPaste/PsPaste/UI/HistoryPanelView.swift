import SwiftUI

/// Bottom history panel content (UI.md §2). Hosted inside `PanelController`'s NSPanel.
struct HistoryPanelView: View {
    @Bindable var model: PanelModel
    let store: ClipboardStore

    @FocusState private var searchFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager

    private var theme: any Theme { themeManager.current }

    var body: some View {
        VStack(spacing: Metrics.Panel.sectionSpacing) {
            topBar
            Divider()
            historyArea
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Opaque panel canvas in the active theme's color (solid warm paper
        // for Parchment — translucent washes the tone out, Task 7).
        .background(theme.panelBackground(colorScheme))
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: theme.panelCornerRadius,
                topTrailingRadius: theme.panelCornerRadius
            )
        )
        .contentShape(Rectangle())
        .onKeyPress { press in pressHandler(press) }
        .overlay(alignment: .top) {
            if model.showsManualPasteHint {
                Text("Copied — press ⌘V to paste")
                    .font(theme.hintFont)
                    .padding(.horizontal, Metrics.Hint.horizontalPadding)
                    .padding(.vertical, Metrics.Hint.verticalPadding)
                    .background(.regularMaterial, in: Capsule())
                    .shadow(radius: Metrics.Hint.shadowRadius)
                    .padding(.top, Metrics.Hint.topPadding)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(Metrics.Panel.animation, value: model.showsManualPasteHint)
    }

    private var topBar: some View {
        HStack(spacing: Metrics.Panel.topBarItemSpacing) {
            // Search slot (UI.md §2.3, Task 7): summons as a collapsed button;
            // clicking it, typing a character, or pressing ⌘F expands the field.
            searchSlot
            Spacer()
            themeMenu
            Button("Pinboard") {}
                .disabled(true)
                .opacity(Metrics.Control.disabledOpacity)
            Button(action: { model.onOpenSettings?() }) {
                Image(systemName: "gearshape")
            }
            .help("Settings (⌘,)")
        }
        .font(theme.topBarFont)
        .frame(height: Metrics.Panel.topBarHeight)
        .padding(.horizontal, Metrics.Panel.topBarHorizontalPadding)
    }

    /// Theme switcher (UI.md §5.2): lists every theme, checkmarks the active
    /// one, applies immediately and persists via ThemeManager.
    private var themeMenu: some View {
        Menu {
            ForEach(themeManager.themes, id: \.id) { theme in
                Button {
                    themeManager.select(id: theme.id)
                } label: {
                    Label(
                        theme.name,
                        systemImage: theme.id == themeManager.current.id
                            ? "checkmark"
                            : ""
                    )
                }
            }
        } label: {
            Image(systemName: "paintbrush")
        }
        .menuStyle(.borderlessButton)
        // .borderlessButton collapses to the symbol's bounds without a frame.
        .frame(width: Metrics.Panel.themeButtonWidth)
    }

    /// One fixed-height slot for both search states: collapsed icon button or
    /// expanded input field, same capsule fill, so the swap does not reflow
    /// the bar.
    private var searchSlot: some View {
        HStack(spacing: Metrics.SearchSlot.iconSpacing) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(theme.secondaryText(colorScheme))
            if model.searchExpanded {
                TextField("Search clipboard history", text: $model.searchText)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onSubmit { model.confirmSelection(in: model.filteredItems) }
            }
        }
        .padding(.horizontal, Metrics.SearchSlot.horizontalPadding)
        .padding(.vertical, Metrics.SearchSlot.verticalPadding)
        .background(theme.searchBarBackground(colorScheme), in: Capsule())
        .contentShape(Capsule())
        .onTapGesture {
            guard !model.searchExpanded else { return }
            model.searchExpanded = true
        }
        .onChange(of: model.searchExpanded, initial: true) { _, expanded in
            searchFocused = expanded
        }
    }

    /// The query-owning strip. A `Predicate` is bound to its `Query` at
    /// creation time, so the search identity re-creates the strip on every
    /// real term change and the new `@Query` runs the predicate in the store
    /// (Task 14-C); whitespace-only edits keep their identity (and query).
    private var historyArea: some View {
        HistoryItemsView(model: model, store: store, searchText: model.searchText)
            .id(HistoryItemsView.searchKey(for: model.searchText))
    }

    /// Panel-level keys (UI.md §2.3); typing falls through to the search field.
    /// Item-dependent actions read `model.filteredItems`, the mirror the strip
    /// maintains, because this view no longer owns the query.
    private func pressHandler(_ press: KeyPress) -> KeyPress.Result {
        switch press.key {
        case .escape:
            model.handleEscape()
            return .handled
        case .leftArrow:
            model.moveSelection(in: model.filteredItems, direction: .newer)
            return .handled
        case .rightArrow:
            model.moveSelection(in: model.filteredItems, direction: .older)
            return .handled
        case .return:
            model.confirmSelection(in: model.filteredItems)
            return .handled
        default:
            if press.key == "f", press.modifiers.contains(.command) {
                model.searchExpanded = true
                return .handled
            }
            if press.key == ",", press.modifiers.contains(.command) {
                model.onOpenSettings?()
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
