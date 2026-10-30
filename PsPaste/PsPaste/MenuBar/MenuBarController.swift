import AppKit

/// Menu bar entry (UI.md §3) with pause toggle and the Accessibility authorization entry.
@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {

    private let statusItem: NSStatusItem
    private let monitor: ClipboardMonitor
    private let togglePanel: () -> Void
    private let openDebugWindow: () -> Void
    private let openSettings: () -> Void

    private let openItem = NSMenuItem()
    private let pauseItem = NSMenuItem()
    private let permissionItem = NSMenuItem()
    private let conflictItem = NSMenuItem()

    /// The binding whose registration is failing (Task 4); nil when registered.
    private(set) var hotKeyConflict: HotKeyBinding?

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
        openDebugWindow: @escaping () -> Void,
        openSettings: @escaping () -> Void
    ) {
        self.monitor = monitor
        self.togglePanel = togglePanel
        self.openDebugWindow = openDebugWindow
        self.openSettings = openSettings

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

        conflictItem.isEnabled = false
        conflictItem.isHidden = true
        menu.addItem(conflictItem)

        openItem.title = "Open P's Paste"
        openItem.target = self
        openItem.action = #selector(openPanel)
        openItem.setKeyEquivalent(for: .default)

        pauseItem.target = self
        pauseItem.action = #selector(togglePause)

        permissionItem.target = self
        permissionItem.action = #selector(openAccessibilitySettings)

        let debugItem = NSMenuItem(
            title: "Open Debug Window",
            action: #selector(openDebug),
            keyEquivalent: ""
        )
        debugItem.target = self

        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsWindow),
            keyEquivalent: ","
        )
        settingsItem.target = self

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
        refreshPermissionItem()
        conflictItem.isHidden = hotKeyConflict == nil
        refreshStatusIcon()
    }

    /// Granted: a checked, inert status line. Not granted: the entry point.
    private func refreshPermissionItem() {
        let trusted = PasteService.isAccessibilityTrusted()
        permissionItem.title = trusted
            ? "Accessibility Permission Granted"
            : "Grant Accessibility Permission…"
        permissionItem.state = trusted ? .on : .off
        permissionItem.isEnabled = !trusted
    }

    /// Keeps the "Open" shortcut hint in sync with the live hot key.
    func setHotKeyBinding(_ binding: HotKeyBinding) {
        openItem.setKeyEquivalent(for: binding)
    }

    /// Called by the assembly when hot key registration fails (nil = recovered).
    func setHotKeyConflict(_ binding: HotKeyBinding?) {
        hotKeyConflict = binding
        if let binding {
            conflictItem.title = "Shortcut \(binding.displayText) is in use by another app"
        }
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

    @objc private func openSettingsWindow() {
        openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
