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

    /// Non-nil while an activation request is pending. `NSApp.activate()`
    /// completes asynchronously; ordering the window front before the
    /// activation lands leaves it buried behind the previously active app
    /// and without key status (the re-trigger case: settings open, focus
    /// moved elsewhere, button pressed again).
    private var activationObserver: NSObjectProtocol?

    func showSettings() {
        // Ordering an already-visible window of an inactive app to the front
        // can be silently ignored by AppKit; ordering it out first makes the
        // re-order-in raise it above every other window at its level.
        if let window, window.isVisible {
            window.orderOut(nil)
        }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)

        // Key status needs an active app; NSApp.activate() completes
        // asynchronously, so re-front the window once activation lands.
        guard !NSApp.isActive else { return }

        NSApp.activate()
        if let activationObserver {
            NotificationCenter.default.removeObserver(activationObserver)
        }
        activationObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // The queue is .main, so isolation is guaranteed at runtime.
            MainActor.assumeIsolated {
                guard let self else { return }
                self.showWindow(nil)
                self.window?.makeKeyAndOrderFront(nil)
                if let observer = self.activationObserver {
                    NotificationCenter.default.removeObserver(observer)
                    self.activationObserver = nil
                }
            }
        }
    }
}
