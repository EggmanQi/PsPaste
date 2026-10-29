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
    /// Distinguishes "still loading" from "payload undecodable": a corrupt image
    /// must fall back to the captured text instead of a gray placeholder (Task 8-D).
    @State private var imageLoadFailed = false
    /// Manual double-click detection: a plain single-tap gesture fires with no
    /// delay, while a coexisting `onTapGesture(count: 2)` would hold the single
    /// tap back for the double-tap window (~0.3s) — that wait was part of the
    /// perceived selection lag (Task 6-A).
    @State private var lastTapAt: Date?

    private var isImage: Bool {
        item.contentTypes.contains("public.png") || item.contentTypes.contains("public.tiff")
    }

    /// True when the card renders its text summary: non-image entries always do;
    /// image entries only when decoding failed and text was captured.
    private var showsTextContent: Bool {
        !isImage || Self.shouldFallbackToText(
            isImage: isImage,
            hasText: item.text?.isEmpty == false,
            imageLoadFailed: imageLoadFailed
        )
    }

    /// Text fallback for image entries whose payload cannot be decoded (Task 8-D):
    /// a corrupt image must not hide the captured text forever.
    nonisolated static func shouldFallbackToText(
        isImage: Bool,
        hasText: Bool,
        imageLoadFailed: Bool
    ) -> Bool {
        isImage && imageLoadFailed && hasText
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
            guard isImage, thumbnail == nil, !imageLoadFailed else { return }
            let key = item.payloadPath ?? item.id.uuidString
            thumbnail = ThumbnailCache.image(forKey: key) {
                store.imagePayload(for: item).flatMap { NSImage(data: $0) }
            }
            if thumbnail == nil {
                imageLoadFailed = true
            }
        }
    }

    /// Two-layer card surface (§5.1 v3): an unselected card is a translucent
    /// tint over the panel canvas; a selected card turns to a standard
    /// material — the HIG-sanctioned depth cue for the content layer
    /// (materials.md: standard materials, not Liquid Glass, in content).
    @ViewBuilder
    private var cardBackground: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Card.cornerRadius)
        if isSelected {
            shape.fill(.regularMaterial)
        } else {
            shape.fill(Theme.ColorToken.cardBackground(colorScheme))
        }
    }

    /// 1pt warm border in both states; selection carries no stroke of its own
    /// (§5.1 v3 — material + scale instead).
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: Theme.Card.cornerRadius)
            .strokeBorder(
                Theme.ColorToken.cardBorder(colorScheme),
                lineWidth: Theme.Card.borderWidth
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
        if showsTextContent {
            textContent
        } else if let thumbnail {
            Image(nsImage: thumbnail)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Still loading (or undecodable with no text to fall back to).
            RoundedRectangle(cornerRadius: Theme.Card.cornerRadius / 2)
                .fill(Theme.ColorToken.placeholder)
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(Theme.ColorToken.secondaryText(colorScheme))
                }
        }
    }

    /// Text layout shared by text entries and the corrupt-image fallback.
    private var textContent: some View {
        VStack(alignment: .leading, spacing: Theme.Card.contentSpacing) {
            if let host = item.text.flatMap(URL.init(string:))?.host() {
                Text(host)
                    .font(Theme.TextStyle.cardMeta)
                    .foregroundStyle(Theme.ColorToken.secondaryText(colorScheme))
            }
            Text(item.summary)
                .font(Theme.TextStyle.cardContent)
                .lineLimit(Theme.Card.contentLineLimit)
                .truncationMode(.tail)
        }
    }

    private var metaRow: some View {
        HStack(spacing: Theme.Card.metaItemSpacing) {
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
        .foregroundStyle(Theme.ColorToken.secondaryText(colorScheme))
        .lineLimit(1)
    }
}
