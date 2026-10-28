import AppKit

/// In-memory cache for card thumbnails, keyed by payload path (Task 6-A).
///
/// `LazyHStack` recycles cards during scrolling, which would otherwise
/// re-read image payloads from disk every time a card re-enters the viewport.
@MainActor
enum ThumbnailCache {
    private static let cache = NSCache<NSString, NSImage>()

    static func image(forKey key: String, loader: () -> NSImage?) -> NSImage? {
        if let cached = cache.object(forKey: key as NSString) {
            return cached
        }
        guard let image = loader() else { return nil }
        cache.setObject(image, forKey: key as NSString)
        return image
    }
}
