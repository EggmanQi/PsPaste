import SwiftUI

/// One history card in the panel (UI.md §2.2).
struct CardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let store: ClipboardStore
    let onSelect: () -> Void
    let onConfirm: () -> Void

    @State private var thumbnail: NSImage?

    private var isImage: Bool {
        item.contentTypes.contains("public.png") || item.contentTypes.contains("public.tiff")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Card.metaSpacing) {
            content
            Spacer(minLength: 0)
            metaRow
        }
        .padding(Theme.Card.padding)
        .frame(width: Theme.Card.width, height: Theme.Card.height)
        .background(
            Theme.ColorToken.cardBackground,
            in: RoundedRectangle(cornerRadius: Theme.Card.cornerRadius)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Card.cornerRadius)
                .strokeBorder(
                    isSelected ? Theme.ColorToken.selectionBorder : .clear,
                    lineWidth: Theme.Card.selectionBorderWidth
                )
        )
        .scaleEffect(isSelected ? Theme.Card.selectedScale : 1)
        .animation(Theme.Panel.animation, value: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Card.cornerRadius))
        .onTapGesture { onSelect() }
        .onTapGesture(count: 2) { onConfirm() }
        .task(id: item.id) {
            guard isImage, thumbnail == nil else { return }
            let data = await Task.detached { store.imagePayload(for: item) }.value
            thumbnail = data.flatMap { NSImage(data: $0) }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isImage {
            if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                RoundedRectangle(cornerRadius: Theme.Card.cornerRadius / 2)
                    .fill(Theme.ColorToken.placeholder)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                    }
            }
        } else {
            VStack(alignment: .leading, spacing: 4) {
                if let host = item.text.flatMap(URL.init(string:))?.host() {
                    Text(host)
                        .font(Theme.TextStyle.cardMeta)
                        .foregroundStyle(.secondary)
                }
                Text(item.summary)
                    .font(Theme.TextStyle.cardContent)
                    .lineLimit(Theme.Card.contentLineLimit)
                    .truncationMode(.tail)
            }
        }
    }

    private var metaRow: some View {
        HStack(spacing: 4) {
            if let icon = SourceAppDisplay.icon(for: item.sourceAppBundleID, size: Theme.Card.metaIconSize) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: Theme.Card.metaIconSize, height: Theme.Card.metaIconSize)
            }
            Text(SourceAppDisplay.name(for: item.sourceAppBundleID))
            Spacer(minLength: 0)
            Text(item.createdAt, style: .relative)
        }
        .font(Theme.TextStyle.cardMeta)
        .foregroundStyle(.secondary)
        .lineLimit(1)
    }
}
