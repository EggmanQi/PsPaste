import SwiftUI

/// One history card in the panel (UI.md §2.2, selection styling per §5.1).
struct CardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let store: ClipboardStore
    let onSelect: () -> Void
    let onConfirm: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @State private var thumbnail: NSImage?
    /// Manual double-click detection: a plain single-tap gesture fires with no
    /// delay, while a coexisting `onTapGesture(count: 2)` would hold the single
    /// tap back for the double-tap window (~0.3s) — that wait was part of the
    /// perceived selection lag (Task 6-A).
    @State private var lastTapAt: Date?

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
        .background(cardBackground)
        .overlay(cardBorder)
        // Only the scale animates, and fast: stroke/fill switch on the same frame.
        .scaleEffect(isSelected ? Theme.Selection.scale : 1)
        .animation(Theme.Selection.animation, value: isSelected)
        .contentShape(RoundedRectangle(cornerRadius: Theme.Card.cornerRadius))
        .onTapGesture(count: 1) { handleTap() }
        .task(id: item.id) {
            guard isImage, thumbnail == nil else { return }
            let key = item.payloadPath ?? item.id.uuidString
            thumbnail = ThumbnailCache.image(forKey: key) {
                store.imagePayload(for: item).flatMap { NSImage(data: $0) }
            }
        }
    }

    /// Three-layer hierarchy (§5.1): card fill, then an 8% accent fill when selected.
    private var cardBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: Theme.Card.cornerRadius)
                .fill(Theme.ColorToken.cardBackground(colorScheme))
            if isSelected {
                RoundedRectangle(cornerRadius: Theme.Card.cornerRadius)
                    .fill(Theme.Selection.fill(colorScheme))
            }
        }
    }

    /// 1pt warm border normally; 2pt accent stroke when selected.
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: Theme.Card.cornerRadius)
            .strokeBorder(
                isSelected
                    ? Theme.Selection.stroke(colorScheme)
                    : Theme.ColorToken.cardBorder(colorScheme),
                lineWidth: isSelected
                    ? Theme.Selection.strokeWidth
                    : Theme.Card.borderWidth
            )
    }

    private func handleTap() {
        let now = Date()
        if let lastTapAt, now.timeIntervalSince(lastTapAt) < Theme.Card.doubleTapInterval {
            self.lastTapAt = nil
            onConfirm()
        } else {
            lastTapAt = now
            onSelect()
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
