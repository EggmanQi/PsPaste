import AppKit
import SwiftUI

/// The settings window (UI.md §4, Task 14). An `NSWindowController` hosting
/// `SettingsView`, matching the existing AppKit entry structure — the app
/// has no SwiftUI Scene, and LSUIElement stays untouched. The window
/// activates the app on open, like `DebugWindowController`.
@MainActor
final class SettingsWindowController: NSWindowController {

    /// Initial content size; the window stays resizable above the tab
    /// content's minimum (Metrics.Settings.minContent*).
    private static let windowSize = NSSize(width: 560, height: 480)

    init(settings: AppSettings, themeManager: ThemeManager, store: ClipboardStore) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: Self.windowSize.width, height: Self.windowSize.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "P's Paste — Settings"
        window.contentView = NSHostingView(
            rootView: SettingsView(store: store)
                .environment(settings)
                .environment(themeManager)
        )
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func showSettings() {
        // LSUIElement-agnostic: bring ourselves forward so the window appears.
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
