import Foundation
import SwiftData

/// One captured clipboard record.
///
/// Large representations (images, rtf, html) live on disk; the database stores
/// only metadata and paths (ARCHITECTURE §3). All properties have defaults or are
/// optional to satisfy the SwiftData + CloudKit constraints for M2.
@Model
final class ClipboardItem {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var sourceAppBundleID: String?
    /// Local device identifier; reserved for future multi-device dedup (ARCHITECTURE §8).
    var sourceDevice: String
    /// Every UTI captured for this copy, used for lossless paste-back.
    var contentTypes: [String]
    /// Plain text representation for display and search.
    var text: String?
    /// Relative path of the payload directory under the Payloads root.
    var payloadPath: String?
    var thumbnailPath: String?
    var isPinned: Bool
    var contentHash: String
    /// Last time the user pasted this entry back (Task 12, LRU eviction).
    /// Nil for records captured before this field existed — `lastActivityAt`
    /// falls back to `createdAt`, which is the right semantics for a record
    /// that was never used after its capture.
    var lastUsedAt: Date?

    /// Eviction clock: last use wins, creation is the floor.
    var lastActivityAt: Date { lastUsedAt ?? createdAt }

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        sourceAppBundleID: String? = nil,
        sourceDevice: String,
        contentTypes: [String],
        text: String?,
        payloadPath: String? = nil,
        thumbnailPath: String? = nil,
        isPinned: Bool = false,
        contentHash: String,
        lastUsedAt: Date? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.sourceAppBundleID = sourceAppBundleID
        self.sourceDevice = sourceDevice
        self.contentTypes = contentTypes
        self.text = text
        self.payloadPath = payloadPath
        self.thumbnailPath = thumbnailPath
        self.isPinned = isPinned
        self.contentHash = contentHash
        self.lastUsedAt = lastUsedAt
    }
}

extension ClipboardItem {
    /// Display text per UI.md §2.2: the full text within the character budget;
    /// beyond it, keep the first 70% and the last 30% with an ellipsis between,
    /// so long copies stay readable at both ends.
    var summary: String {
        if let text, !text.isEmpty {
            return Self.middleTruncated(text)
        }
        if contentTypes.contains("public.png") || contentTypes.contains("public.tiff") {
            return "Image"
        }
        if contentTypes.contains("public.file-url") {
            return "File"
        }
        return contentTypes.first ?? "Item"
    }

    /// Middle-truncation rule (UI.md §2.2), a pure function for testing.
    /// `budget` counts characters, not bytes or lines.
    static func middleTruncated(_ text: String, budget: Int = 300) -> String {
        guard text.count > budget else { return text }
        let headCount = Int((Double(budget) * 0.7).rounded(.down))
        let tailCount = budget - headCount
        return "\(text.prefix(headCount)) … \(text.suffix(tailCount))"
    }
}
