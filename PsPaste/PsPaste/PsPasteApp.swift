import AppKit
import SwiftData
import SwiftUI

/// Menu-bar app entry (Task 3 app form): no Dock icon, no SwiftUI scenes.
@main
final class PsPasteAppDelegate: NSObject, NSApplicationDelegate {

    /// Explicit entry point: with no Main storyboard/nib, `NSApplicationMain`
    /// would never connect the delegate — applicationDidFinishLaunching would
    /// never fire and the app would idle silently (no monitor, no hotkey,
    /// no status item). Found 2026-10-27 as the "app runs but does nothing" bug.
    static func main() {
        let app = NSApplication.shared
        let delegate = PsPasteAppDelegate()
        app.delegate = delegate
        app.run()
    }

    private let store = ClipboardStore()
    private let monitor = ClipboardMonitor()
    private let panelModel = PanelModel()
    private let panelController: PanelController
    private let hotKeyService = HotKeyService()
    private let menuBarController: MenuBarController
    private let debugWindowController: DebugWindowController
    private let settingsWindowController: SettingsWindowController
    private let notifier = SystemNotifier()
    private let settings = AppSettings.shared
    private let appMenuOpenItem = NSMenuItem(
        title: "Open P's Paste",
        action: #selector(togglePanelFromMenu),
        keyEquivalent: ""
    )

    override init() {
        panelController = PanelController(
            contentView: NSHostingView(
                rootView: HistoryPanelView(model: panelModel, store: store)
                    // @Query needs a ModelContext in the environment; without
                    // this the panel silently shows an empty history.
                    .modelContainer(store.modelContainer)
                    // The active skin (UI.md §5.2); ThemeManager publishes
                    // changes, so theme switches re-render the panel.
                    .environment(ThemeManager.shared)
            ),
            model: panelModel
        )
        debugWindowController = DebugWindowController(store: store)
        settingsWindowController = SettingsWindowController(
            settings: settings,
            themeManager: ThemeManager.shared,
            store: store,
            // Recorder applier (Task 15-B): register the new binding first;
            // persist only on success so a conflict keeps the old binding
            // active and un-persisted.
            hotKeyApplier: HotKeyApplier { [hotKeyService, settings] binding in
                guard hotKeyService.rebind(to: binding) else { return false }
                settings.setHotKeyBinding(binding)
                return true
            }
        )
        menuBarController = MenuBarController(
            monitor: monitor,
            togglePanel: { [panelController] in panelController.toggle() },
            openDebugWindow: { [debugWindowController] in
                debugWindowController.showDebugWindow()
            },
            openSettings: { [settingsWindowController] in
                settingsWindowController.showSettings()
            }
        )
        super.init()

        monitor.onCapture = { [store] snapshot in store.save(snapshot) }
        monitor.shouldSkipCapture = { [store] snapshot in
            store.containsNewest(matchingHash: snapshot.contentHash)
        }
        panelModel.onRestore = { [weak self] item in self?.handleRestore(item) }
        panelModel.onCopyOnly = { [monitor, store] item in
            // Copy-only: write back without pasting, closing, or re-recording
            // history — the TransientType mark prevents the re-capture (§2.2 v5).
            monitor.markNextPasteboardWriteAsOwn()
            PasteService.restoreToGeneralPasteboard(
                item,
                payloads: store.payloadContents(for: item)
            )
        }
        panelModel.onTogglePin = { [store] item in store.togglePin(item) }
        panelModel.onDelete = { [store] item in store.delete(item) }
        // ⌘, from the panel: close it, then bring the settings window up.
        panelModel.onOpenSettings = { [panelController, settingsWindowController] in
            panelController.close()
            settingsWindowController.showSettings()
        }

        // Settings effective paths (Task 14): apply persisted values now and
        // forward every later change — no relaunch needed.
        store.historyLimit = settings.historyLimit
        store.staleTTL = settings.staleTTL
        monitor.excludedBundleIDs = Set(settings.excludedBundleIDs)
        settings.onHistoryLimitChange = { [store] limit in
            store.historyLimit = limit
            store.enforceHistoryLimit()
        }
        settings.onRetentionChange = { [store] ttl in
            store.staleTTL = ttl
        }
        settings.onExcludedBundleIDsChange = { [monitor] bundleIDs in
            monitor.excludedBundleIDs = Set(bundleIDs)
        }
        settings.onHotKeyBindingChange = { [weak self] binding in
            self?.applyShortcutHints(binding)
        }
        hotKeyService.onToggle = { [panelController] in panelController.toggle() }
        hotKeyService.onRegistrationStateChange = { [weak self] state in
            guard let self else { return }
            switch state {
            case .registered:
                self.menuBarController.setHotKeyConflict(nil)
            case .failed(let binding):
                // Retries re-report the same failure every 30 seconds;
                // notify once per conflict, the menu bar icon stays on.
                let isNewConflict = self.menuBarController.hotKeyConflict != binding
                self.menuBarController.setHotKeyConflict(binding)
                guard isNewConflict else { return }
                self.notifier.deliver(
                    title: "P's Paste",
                    body: "Shortcut \(binding.displayText) is in use by another app, so the panel hotkey is unavailable. Retrying every 30 seconds."
                )
            }
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        installMainMenu()
        applyShortcutHints(settings.hotKeyBinding)
        monitor.start()
        // The persisted binding decides the hot key (Task 15); absent keys
        // fall back to the default ⌘⇧` inside AppSettings.
        hotKeyService.start(
            keyCode: settings.hotkeyKeyCode,
            modifiers: settings.hotkeyModifiers
        )
        // Stale sweep at launch, then every 24h (ARCHITECTURE §3 rule 2).
        store.evictStale()
        store.startEvictionTimer()
    }

    // MARK: - Paste (ARCHITECTURE §7)

    private func handleRestore(_ item: ClipboardItem) {
        store.markUsed(item)
        monitor.markNextPasteboardWriteAsOwn()
        PasteService.restoreToGeneralPasteboard(
            item,
            payloads: store.payloadContents(for: item)
        )

        switch PasteService.action(
            isAccessibilityTrusted: PasteService.isAccessibilityTrusted()
        ) {
        case .directPaste:
            // Order out first so the previous app regains key status;
            // posting ⌘V while the panel is key would send it to ourselves.
            panelController.closeImmediately()
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(50)) {
                PasteService.postCommandV()
            }
        case .copyOnly:
            panelModel.showsManualPasteHint = true
            // Keep the hint visible briefly, then dismiss the panel.
            DispatchQueue.main.asyncAfter(deadline: .now() + .milliseconds(1200)) {
                self.panelModel.showsManualPasteHint = false
                self.panelController.close()
            }
        }
    }

    // MARK: - Minimal main menu

    private func applyShortcutHints(_ binding: HotKeyBinding) {
        appMenuOpenItem.setKeyEquivalent(for: binding)
        menuBarController.setHotKeyBinding(binding)
    }

    @objc private func togglePanelFromMenu() {
        panelController.toggle()
    }

    @objc private func openSettingsWindow() {
        settingsWindowController.showSettings()
    }

    /// LSUIElement apps get no default menu; provide just enough for the search
    /// field's standard key equivalents (Copy/Paste/Select All) and window controls.
    /// The app menu shows while one of our windows is active, so it repeats
    /// the status menu's main entries (Settings ⌘, included).
    private func installMainMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "About P's Paste",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenuOpenItem.target = self
        let settingsItem = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettingsWindow),
            keyEquivalent: ","
        )
        settingsItem.target = self
        appMenu.addItem(appMenuOpenItem)
        appMenu.addItem(settingsItem)
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Quit P's Paste",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(
            withTitle: "Cut",
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        editMenu.addItem(
            withTitle: "Copy",
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        editMenu.addItem(
            withTitle: "Paste",
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        editMenu.addItem(
            withTitle: "Select All",
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        editItem.submenu = editMenu

        let windowItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(
            withTitle: "Minimize",
            action: #selector(NSWindow.performMiniaturize(_:)),
            keyEquivalent: "m"
        )
        windowItem.submenu = windowMenu

        mainMenu.addItem(appItem)
        mainMenu.addItem(editItem)
        mainMenu.addItem(windowItem)
        NSApp.mainMenu = mainMenu
    }
}
