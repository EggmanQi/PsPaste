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
        contentHash: String
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
    }
}
