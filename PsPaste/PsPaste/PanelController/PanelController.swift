import AppKit

/// Bottom history panel: borderless non-activating NSPanel shown at the bottom of
/// the screen under the mouse (ARCHITECTURE §5, UI.md §2).
///
/// The controller owns window chrome and show/hide only; it never imports SwiftUI —
/// the hosting view is built by the app assembly and injected.
@MainActor
final class PanelController {

    private let panel: PastePanel
    private let model: PanelModel

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
        model.focusSignal += 1

        NSAnimationContext.runAnimationGroup { context in
            context.duration = Theme.Panel.animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().setFrame(frame, display: true)
            panel.animator().alphaValue = 1
        }
    }

    /// Orders the panel out instantly with no animation.
    ///
    /// Used before a simulated ⌘V: the panel must release key status first,
    /// otherwise the keystroke would be delivered to the panel itself
    /// (ARCHITECTURE §7 timing note).
    func closeImmediately() {
        panel.orderOut(nil)
        panel.alphaValue = 1
    }

    func close() {
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
