import AppKit
import Carbon

/// Key code → shortcut glyph and menu key equivalent. Printable keys go
/// through the current ASCII-capable keyboard layout, like system menus:
/// an active input method (e.g. Pinyin) has no Unicode layout data, and a
/// non-ASCII layout may produce a different character ("·" for grave).
/// Keys that translate to control characters use a fixed table.
enum KeyCodeDisplay {

    private struct SpecialKey {
        let glyph: String
        let keyEquivalent: String
    }

    private static let specialKeys: [UInt32: SpecialKey] = {
        func key(_ glyph: String, _ special: NSEvent.SpecialKey) -> SpecialKey {
            SpecialKey(glyph: glyph, keyEquivalent: String(special.unicodeScalar))
        }
        let functionKeys: [(Int, NSEvent.SpecialKey)] = [
            (kVK_F1, .f1), (kVK_F2, .f2), (kVK_F3, .f3), (kVK_F4, .f4),
            (kVK_F5, .f5), (kVK_F6, .f6), (kVK_F7, .f7), (kVK_F8, .f8),
            (kVK_F9, .f9), (kVK_F10, .f10), (kVK_F11, .f11), (kVK_F12, .f12),
            (kVK_F13, .f13), (kVK_F14, .f14), (kVK_F15, .f15), (kVK_F16, .f16),
            (kVK_F17, .f17), (kVK_F18, .f18), (kVK_F19, .f19), (kVK_F20, .f20),
        ]
        var table: [UInt32: SpecialKey] = [
            UInt32(kVK_Space): SpecialKey(glyph: "Space", keyEquivalent: " "),
            UInt32(kVK_Return): key("↩", .carriageReturn),
            UInt32(kVK_ANSI_KeypadEnter): key("⌤", .enter),
            UInt32(kVK_Tab): key("⇥", .tab),
            UInt32(kVK_Delete): key("⌫", .backspace),
            UInt32(kVK_ForwardDelete): key("⌦", .deleteForward),
            UInt32(kVK_LeftArrow): key("←", .leftArrow),
            UInt32(kVK_RightArrow): key("→", .rightArrow),
            UInt32(kVK_UpArrow): key("↑", .upArrow),
            UInt32(kVK_DownArrow): key("↓", .downArrow),
            UInt32(kVK_Home): key("↖", .home),
            UInt32(kVK_End): key("↘", .end),
            UInt32(kVK_PageUp): key("⇞", .pageUp),
            UInt32(kVK_PageDown): key("⇟", .pageDown),
        ]
        for (index, (keyCode, special)) in functionKeys.enumerated() {
            table[UInt32(keyCode)] = key("F\(index + 1)", special)
        }
        return table
    }()

    /// The glyph shown in shortcut labels, e.g. "`", "V", "F5", "Space".
    static func glyph(forKeyCode keyCode: UInt32) -> String {
        if let special = specialKeys[keyCode] { return special.glyph }
        return layoutCharacter(forKeyCode: keyCode)?.uppercased() ?? "Key \(keyCode)"
    }

    /// The `NSMenuItem.keyEquivalent` for the key; empty when the layout
    /// cannot be read, which leaves the menu item without a shortcut.
    static func menuKeyEquivalent(forKeyCode keyCode: UInt32) -> String {
        if let special = specialKeys[keyCode] { return special.keyEquivalent }
        return layoutCharacter(forKeyCode: keyCode)?.lowercased() ?? ""
    }

    private static func layoutCharacter(forKeyCode keyCode: UInt32) -> String? {
        guard let source = TISCopyCurrentASCIICapableKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutValue = TISGetInputSourceProperty(
                  source, kTISPropertyUnicodeKeyLayoutData
              ) else {
            return nil
        }
        // The property value is the CFData reference itself, not a pointer to it.
        let layoutData = Unmanaged<CFData>.fromOpaque(layoutValue).takeUnretainedValue()
        guard let layoutBytes = CFDataGetBytePtr(layoutData) else { return nil }
        var deadKeyState = UInt32(0)
        var characters = [UniChar](repeating: 0, count: 4)
        var length = 0
        let status = layoutBytes.withMemoryRebound(
            to: UCKeyboardLayout.self,
            capacity: 1
        ) { layout in
            UCKeyTranslate(
                layout,
                UInt16(keyCode),
                UInt16(kUCKeyActionDisplay),
                0,
                UInt32(LMGetKbdType()),
                OptionBits(kUCKeyTranslateNoDeadKeysBit),
                &deadKeyState,
                characters.count,
                &length,
                &characters
            )
        }
        guard status == noErr, length > 0 else { return nil }
        return String(utf16CodeUnits: characters, count: length)
    }
}

extension HotKeyBinding {

    /// Label form like "⌘⇧`", rendered through the current keyboard layout.
    var displayText: String {
        displayString { KeyCodeDisplay.glyph(forKeyCode: $0) }
    }
}

extension NSMenuItem {

    /// Shows the binding as this item's shortcut hint.
    func setKeyEquivalent(for binding: HotKeyBinding) {
        keyEquivalent = KeyCodeDisplay.menuKeyEquivalent(forKeyCode: binding.keyCode)
        keyEquivalentModifierMask = HotKeyService.modifierFlags(fromCarbon: binding.modifiers)
    }
}
