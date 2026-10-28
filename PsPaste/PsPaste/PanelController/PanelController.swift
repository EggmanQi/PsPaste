import AppKit

/// Bottom history panel: borderless non-activating NSPanel shown at the bottom of
/// the screen under the mouse (ARCHITECTURE §5, UI.md §2).
///
/// The controller owns window chrome and show/hide only; it never imports SwiftUI —
/// the hosting view is built by the app assembly and injected.
@MainActor
final class PanelController {

    /// An interaction outside the panel that may auto-close it (Task 5).
    nonisolated enum OutsideEvent: Equatable {
        case leftMouseDown(at: CGPoint)
        case applicationActivated(bundleID: String?)
    }

    /// Pure close decision for an outside interaction (unit-tested).
    nonisolated static func shouldClose(
        for event: OutsideEvent,
        panelFrame: CGRect,
        selfBundleID: String
    ) -> Bool {
        switch event {
        case .leftMouseDown(let location):
            return !panelFrame.contains(location)
        case .applicationActivated(let bundleID):
            // Activating our own app (e.g. opening the debug window) keeps the panel.
            return bundleID != selfBundleID
        }
    }

    private let panel: PastePanel
    private let model: PanelModel
    private let selfBundleID = Bundle.main.bundleIdentifier ?? "com.ebs.pspaste"

    private var outsideMouseMonitor: Any?
    private var appActivationObserver: NSObjectProtocol?

    var isVisible: Bool { panel.isVisible }

    init(contentView: NSView, model: PanelModel) {
        self.model = model
        panel = PastePanel(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: Theme.Panel.height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        model.onRequestClose = { [weak self] in self?.close() }
        panel.contentView = contentView
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
    }

    func toggle() {
        isVisible ? close() : show()
    }

    /// Orders the panel in without activating the app; positions it on the mouse screen.
    func show() {
        let screen = Self.screenWithMouse()
        let frame = NSRect(
            x: screen.frame.minX,
            y: screen.frame.minY,
            width: screen.frame.width,
            height: Theme.Panel.height
        )

        var entryFrame = frame
        entryFrame.origin.y -= Theme.Panel.slideOffset
        panel.setFrame(entryFrame, display: false)
        panel.alphaValue = 0

        panel.orderFrontRegardless()
        panel.makeKey()

        model.prepareForShow()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Theme.Panel.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 1
        }

        installOutsideInteractionMonitors()
    }

    /// Orders the panel out instantly with no animation.
    ///
    /// Used before a simulated ⌘V: the panel must release key status first,
    /// otherwise the keystroke would be delivered to the panel itself
    /// (ARCHITECTURE §7 timing note).
    func closeImmediately() {
        removeOutsideInteractionMonitors()
        panel.orderOut(nil)
        panel.alphaValue = 1
    }

    func close() {
        removeOutsideInteractionMonitors()
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = Theme.Panel.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            var exitFrame = panel.frame
            exitFrame.origin.y -= Theme.Panel.slideOffset
            panel.animator().setFrame(exitFrame, display: false)
            panel.animator().alphaValue = 0
        }) {
            self.panel.orderOut(nil)
            self.panel.alphaValue = 1
        }
    }

    // MARK: - Outside-interaction monitors (Task 5)

    /// The app never activates, so the panel never gets resignKey/deactivate
    /// notifications when the user works elsewhere — closing on outside
    /// interaction must be detected actively while the panel is visible.
    ///
    /// The global mouse monitor never sees events delivered to our own app,
    /// so clicking the menu bar icon or its menu does not dismiss the panel.
    private func installOutsideInteractionMonitors() {
        guard outsideMouseMonitor == nil, appActivationObserver == nil else { return }

        outsideMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] _ in
            guard let self else { return }
            MainActor.assumeIsolated { self.handleGlobalMouseDown() }
        }
        appActivationObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard let self else { return }
            MainActor.assumeIsolated { self.handleApplicationActivated(app?.bundleIdentifier) }
        }
    }

    private func removeOutsideInteractionMonitors() {
        if let outsideMouseMonitor {
            NSEvent.removeMonitor(outsideMouseMonitor)
            self.outsideMouseMonitor = nil
        }
        if let appActivationObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(appActivationObserver)
            self.appActivationObserver = nil
        }
    }

    private func handleGlobalMouseDown() {
        guard panel.isVisible else { return }
        // Global monitor events have no window; use screen coordinates.
        let location = NSEvent.mouseLocation
        if Self.shouldClose(
            for: .leftMouseDown(at: location),
            panelFrame: panel.frame,
            selfBundleID: selfBundleID
        ) {
            close()
        }
    }

    private func handleApplicationActivated(_ bundleID: String?) {
        guard panel.isVisible else { return }
        if Self.shouldClose(
            for: .applicationActivated(bundleID: bundleID),
            panelFrame: panel.frame,
            selfBundleID: selfBundleID
        ) {
            close()
        }
    }

    private static func screenWithMouse() -> NSScreen {
        let mouseLocation = NSEvent.mouseLocation
        return NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}

/// Borderless panel that accepts key input without activating the app.
private final class PastePanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
