import AppKit
import Carbon

/// Paste-back orchestration (ARCHITECTURE §7).
///
/// Task 3 scope: restore + simulated ⌘V gated by the Accessibility permission.
enum PasteService {

    /// What happens after an item is written back to the pasteboard.
    enum Action: Equatable {
        /// Permission granted: close the panel and post a synthetic ⌘V.
        case directPaste
        /// No permission: write back only; the UI shows a manual-paste hint.
        case copyOnly
    }

    /// Pure branch decision over the Accessibility permission. Unit-tested.
    static func action(isAccessibilityTrusted trusted: Bool) -> Action {
        trusted ? .directPaste : .copyOnly
    }

    /// Query only: never shows the system authorization prompt. The
    /// authorization entry points live in the menu bar and the About tab.
    static func isAccessibilityTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    /// Deep link to the Accessibility pane in System Settings.
    static let accessibilitySettingsURL = URL(
        string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
    )!

    /// Restores the plain text plus every stored payload representation.
    /// Call `ClipboardMonitor.markNextPasteboardWriteAsOwn()` first to prevent
    /// the monitor from recording this write-back.
    static func restoreToGeneralPasteboard(
        _ item: ClipboardItem,
        payloads: [(type: String, data: Data)]
    ) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        let boardItem = NSPasteboardItem()
        if let text = item.text, !text.isEmpty {
            boardItem.setString(text, forType: .string)
        }
        for payload in payloads {
            boardItem.setData(payload.data, forType: NSPasteboard.PasteboardType(payload.type))
        }
        pasteboard.writeObjects([boardItem])
    }

    /// Posts key down + key up for ⌘V to the HID event tap.
    /// The caller must ensure the target app (not this panel) has key status.
    static func postCommandV() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyCode = CGKeyCode(kVK_ANSI_V)
        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else {
            return
        }
        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
