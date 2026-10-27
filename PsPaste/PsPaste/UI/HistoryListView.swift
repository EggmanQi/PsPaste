import SwiftData
import SwiftUI

/// Temporary scaffold list proving the capture pipeline (Task 1).
/// The bottom NSPanel UI replaces this in Task 2.
struct HistoryListView: View {
    @Query(sort: \ClipboardItem.createdAt, order: .reverse) private var items: [ClipboardItem]

    var body: some View {
        List {
            ForEach(items, id: \.id) { item in
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(item.summary)
                        .lineLimit(3)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(SourceAppDisplay.name(for: item.sourceAppBundleID))
                        Text(item.createdAt, style: .relative)
                    }
                    .font(.callout)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            }
        }
        .listStyle(.plain)
        .overlay {
            if items.isEmpty {
                Text("Copy something to get started")
                    .foregroundStyle(.secondary)
            }
        }
    }
}

extension ClipboardItem {
    /// First line of text for display; falls back by content kind for media-only copies.
    var summary: String {
        if let text, !text.isEmpty {
            let firstLine = text.prefix(while: { $0 != "\n" })
            return firstLine.isEmpty ? text : String(firstLine)
        }
        if contentTypes.contains("public.png") || contentTypes.contains("public.tiff") {
            return "Image"
        }
        if contentTypes.contains("public.file-url") {
            return "File"
        }
        return contentTypes.first ?? "Item"
    }
}

#Preview {
    let container = try! ModelContainer(
        for: ClipboardItem.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    context.insert(ClipboardItem(
        sourceDevice: "Preview",
        contentTypes: ["public.utf8-plain-text"],
        text: "Sample copied text",
        contentHash: "preview-hash"
    ))
    try? context.save()

    return HistoryListView()
        .modelContainer(container)
}
