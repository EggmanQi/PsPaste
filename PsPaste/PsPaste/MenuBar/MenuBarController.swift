import AppKit

/// Menu bar entry (UI.md §3) with pause toggle and the Accessibility authorization entry.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let monitor: ClipboardMonitor
    private let togglePanel: () -> Void
    private let openDebugWindow: () -> Void

    private let pauseItem = NSMenuItem()
    private let permissionItem = NSMenuItem()
    private let conflictItem = NSMenuItem()

    /// Non-nil while the panel hot key registration is failing (Task 4).
    private var hotKeyConflict: String?

    /// The custom art icon (Resources/icon.png in the bundle). Colored artwork,
    /// so NOT a template image — macOS would flatten it to a black silhouette.
    private static var statusIcon: NSImage? {
        guard let url = Bundle.main.url(forResource: "icon", withExtension: "png"),
              let image = NSImage(contentsOf: url) else { return nil }
        image.size = NSSize(width: 20, height: 20)
        image.isTemplate = false
        return image
    }

    init(
        monitor: ClipboardMonitor,
        togglePanel: @escaping () -> Void,
        openDebugWindow: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.togglePanel = togglePanel
        self.openDebugWindow = openDebugWindow

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()

        if let button = statusItem.button {
            button.image = Self.statusIcon ?? NSImage(
                systemSymbolName: "clipboard.fill",
                accessibilityDescription: "P's Paste"
            )
        }

        let menu = NSMenu()
        menu.autoenablesItems = false
        menu.delegate = self
        statusItem.menu = menu
        buildMenu()
    }

    private func buildMenu() {
        guard let menu = statusItem.menu else { return }

        conflictItem.title = "Hotkey in use by another app"
        conflictItem.isEnabled = false
        conflictItem.isHidden = true
        menu.addItem(conflictItem)

        let openItem = NSMenuItem(
            title: "Open P's Paste",
            action: #selector(openPanel),
            keyEquivalent: "`"
        )
        openItem.keyEquivalentModifierMask = [.command, .shift]
        openItem.target = self

        pauseItem.target = self
        pauseItem.action = #selector(togglePause)

        permissionItem.title = "Grant Accessibility Permission…"
        permissionItem.target = self
        permissionItem.action = #selector(openAccessibilitySettings)

        let debugItem = NSMenuItem(
            title: "Open Debug Window",
            action: #selector(openDebug),
            keyEquivalent: ""
        )
        debugItem.target = self

        let settingsItem = NSMenuItem(title: "Settings…", action: nil, keyEquivalent: ",")
        settingsItem.isEnabled = false

        let quitItem = NSMenuItem(
            title: "Quit P's Paste",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self

        menu.addItem(openItem)
        menu.addItem(.separator())
        menu.addItem(pauseItem)
        menu.addItem(.separator())
        menu.addItem(permissionItem)
        menu.addItem(debugItem)
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
    }

    /// Refresh dynamic state every time the menu opens.
    func menuNeedsUpdate(_ menu: NSMenu) {
        pauseItem.title = monitor.isPaused ? "Resume Capture" : "Pause Capture"
        permissionItem.isHidden = PasteService.isAccessibilityTrusted()
        conflictItem.isHidden = hotKeyConflict == nil
        refreshStatusIcon()
    }

    /// Called by the assembly when hot key registration fails (nil = recovered).
    func setHotKeyConflict(_ error: String?) {
        hotKeyConflict = error
        refreshStatusIcon()
    }

    private func refreshStatusIcon() {
        guard let button = statusItem.button else { return }

        if hotKeyConflict != nil {
            button.image = NSImage(
                systemSymbolName: "exclamationmark.triangle.fill",
                accessibilityDescription: "P's Paste hotkey conflict"
            )
            button.appearsDisabled = false
            return
        }

        if monitor.isPaused {
            button.image = NSImage(
                systemSymbolName: "pause.circle",
                accessibilityDescription: "P's Paste"
            )
        } else {
            button.image = Self.statusIcon ?? NSImage(
                systemSymbolName: "clipboard.fill",
                accessibilityDescription: "P's Paste"
            )
        }
        // Extra visual distinction for the paused state.
        button.appearsDisabled = monitor.isPaused
    }

    @objc private func openPanel() {
        togglePanel()
    }

    @objc private func togglePause() {
        monitor.setPaused(!monitor.isPaused)
    }

    @objc private func openAccessibilitySettings() {
        NSWorkspace.shared.open(PasteService.accessibilitySettingsURL)
    }

    @objc private func openDebug() {
        openDebugWindow()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
