import SwiftUI

/// One history card in the panel (UI.md §2.2). All styling comes from the
/// active `Theme`; layout metrics are shared `Metrics`.
struct CardView: View {
    let item: ClipboardItem
    let isSelected: Bool
    let store: ClipboardStore
    let onSelect: () -> Void
    let onConfirm: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(ThemeManager.self) private var themeManager
    @State private var thumbnail: NSImage?
    /// Distinguishes "still loading" from "payload undecodable": a corrupt image
    /// must fall back to the captured text instead of a gray placeholder (Task 8-D).
    @State private var imageLoadFailed = false
    /// Manual double-click detection: a plain single-tap gesture fires with no
    /// delay, while a coexisting `onTapGesture(count: 2)` would hold the single
    /// tap back for the double-tap window (~0.3s) — that wait was part of the
    /// perceived selection lag (Task 6-A).
    @State private var lastTapAt: Date?

    private var theme: any Theme { themeManager.current }

    private var selectionStyle: SelectionStyle { theme.selection(colorScheme) }

    /// Text/icon color for secondary content; the theme may override it on
    /// the selected card (Particle turns meta text white on the accent fill).
    private var secondaryForeground: Color {
        if isSelected, let override = selectionStyle.contentForeground {
            return override
        }
        return theme.secondaryText(colorScheme)
    }

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

    /// Static timestamp for the meta row (UI.md §2.2): "HH:mm" for copies made
    /// today, "MM-dd HH:mm" for older ones. A fixed label — the live relative
    /// format re-rendered cards on a timer for no benefit.
    nonisolated static func timeLabel(
        for date: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = calendar
        // DateFormatter does not pick the calendar's time zone up by itself.
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = calendar.isDate(date, inSameDayAs: now)
            ? "HH:mm"
            : "MM-dd HH:mm"
        return formatter.string(from: date)
    }

    /// Character-count label for the meta row (UI.md §2.2): the total count
    /// stays visible even when the preview is middle-truncated. Locale pinned
    /// for deterministic grouping (POSIX does not group thousands).
    nonisolated static func charCountLabel(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.numberStyle = .decimal
        let grouped = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
        return "\(grouped) 字"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Metrics.Card.metaSpacing) {
            content
            Spacer(minLength: 0)
            metaRow
        }
        .padding(Metrics.Card.padding)
        .frame(width: Metrics.Card.width, height: Metrics.Card.height)
        .background(cardBackground)
        .overlay(cardBorder)
        // Only the selected card carries a shadow; stroke, fill, and shadow
        // switch on the same frame (no scale, no animation — §5.1 v4).
        .shadow(
            color: .black.opacity(isSelected ? selectionStyle.shadowOpacity : 0),
            radius: isSelected ? selectionStyle.shadowRadius : 0,
            y: isSelected ? selectionStyle.shadowY : 0
        )
        .contentShape(RoundedRectangle(cornerRadius: theme.cardCornerRadius))
        .overlay(alignment: .topTrailing) {
            // Pinned state is invisible otherwise (Pinboard UI is deferred);
            // the selected card shows it through the action row instead.
            if item.isPinned && !isSelected {
                Image(systemName: "pin.fill")
                    .font(.system(size: Metrics.Card.pinBadgeSize))
                    .foregroundStyle(secondaryForeground)
                    .padding(Metrics.Card.pinBadgeInset)
            }
        }
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

    /// Two-state card surface: the theme's unselected tint, or its selected
    /// fill (solid white for Parchment, accent for Particle).
    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: theme.cardCornerRadius)
            .fill(isSelected ? selectionStyle.cardFill : theme.cardBackground(colorScheme))
    }

    /// The theme's 1pt border normally; its selected stroke (accent 2pt for
    /// Parchment, none for Particle).
    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: theme.cardCornerRadius)
            .strokeBorder(
                isSelected
                    ? selectionStyle.stroke
                    : theme.cardBorder(colorScheme),
                lineWidth: isSelected
                    ? selectionStyle.strokeWidth
                    : Metrics.Card.borderWidth
            )
    }

    private func handleTap() {
        let now = Date()
        if let lastTapAt, now.timeIntervalSince(lastTapAt) < Metrics.Card.doubleTapInterval {
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
            RoundedRectangle(cornerRadius: theme.cardCornerRadius / 2)
                .fill(theme.placeholder(colorScheme))
                .overlay {
                    Image(systemName: "photo")
                        .foregroundStyle(secondaryForeground)
                }
        }
    }

    /// Text layout shared by text entries and the corrupt-image fallback.
    private var textContent: some View {
        VStack(alignment: .leading, spacing: Metrics.Card.contentSpacing) {
            if let host = item.text.flatMap(URL.init(string:))?.host() {
                Text(host)
                    .font(theme.cardMetaFont)
                    .foregroundStyle(secondaryForeground)
            }
            Text(item.summary)
                .font(theme.cardContentFont)
                .foregroundStyle(
                    isSelected
                        ? selectionStyle.contentForeground ?? theme.primaryText(colorScheme)
                        : theme.primaryText(colorScheme)
                )
                .lineLimit(Metrics.Card.contentLineLimit)
                .truncationMode(.tail)
        }
    }

    private var metaRow: some View {
        HStack(spacing: Metrics.Card.metaItemSpacing) {
            if let icon = SourceAppDisplay.icon(for: item.sourceAppBundleID, size: Metrics.Card.metaIconSize) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: Metrics.Card.metaIconSize, height: Metrics.Card.metaIconSize)
            }
            Text(SourceAppDisplay.name(for: item.sourceAppBundleID))
            if let count = item.text?.count, count > 0 {
                Text(Self.charCountLabel(count))
            }
            Spacer(minLength: 0)
            Text(Self.timeLabel(for: item.createdAt))
        }
        .font(theme.cardMetaFont)
        .foregroundStyle(secondaryForeground)
        .lineLimit(1)
    }
}
