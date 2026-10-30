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
    ///
    /// The write-back carries the TransientType marker, so neither our
    /// monitor nor other clipboard managers record it again (ARCHITECTURE §4
    /// rule 4). A type that occurs more than once (e.g. several copied files)
    /// gets one pasteboard item per occurrence, in captured order.
    static func restore(
        _ item: ClipboardItem,
        payloads: [(type: String, data: Data)],
        to pasteboard: NSPasteboard = .general
    ) {
        let first = NSPasteboardItem()
        first.setData(Data(), forType: .transientMarker)
        if let text = item.text, !text.isEmpty {
            first.setString(text, forType: .string)
        }

        var boardItems = [first]
        for payload in payloads {
            let type = NSPasteboard.PasteboardType(payload.type)
            let target: NSPasteboardItem
            if let free = boardItems.first(where: { !$0.types.contains(type) }) {
                target = free
            } else {
                target = NSPasteboardItem()
                boardItems.append(target)
            }
            target.setData(payload.data, forType: type)
        }

        pasteboard.clearContents()
        pasteboard.writeObjects(boardItems)
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
