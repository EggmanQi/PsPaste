import AppKit

/// Resolves a source app bundle ID to a display name and icon for the history list.
enum SourceAppDisplay {
    private static var nameCache: [String: String] = [:]
    private static var iconCache: [String: NSImage] = [:]

    static func name(for bundleID: String?) -> String {
        guard let bundleID, !bundleID.isEmpty else { return "Unknown" }
        if let cached = nameCache[bundleID] { return cached }

        let name: String
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID),
           let bundle = Bundle(url: url) {
            name = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? bundleID
        } else {
            name = bundleID
        }
        nameCache[bundleID] = name
        return name
    }

    static func icon(for bundleID: String?, size: CGFloat) -> NSImage? {
        guard let bundleID, !bundleID.isEmpty else { return nil }
        if let cached = iconCache[bundleID] { return cached }
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }
        let icon = NSWorkspace.shared.icon(forFile: url.path)
        icon.size = NSSize(width: size, height: size)
        iconCache[bundleID] = icon
        return icon
    }
}
