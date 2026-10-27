import SwiftData
import SwiftUI

/// Debug history window, reachable only from the menu bar (Task 3 app form).
@MainActor
final class DebugWindowController: NSWindowController {

    init(store: ClipboardStore) {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "P's Paste — Debug"
        window.contentView = NSHostingView(
            rootView: HistoryListView().modelContainer(store.modelContainer)
        )
        window.center()
        super.init(window: window)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func showDebugWindow() {
        // LSUIElement app: bring ourselves forward so the window appears above others.
        NSApp.activate()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
