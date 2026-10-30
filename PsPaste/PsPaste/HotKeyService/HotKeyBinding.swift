import Carbon
import Foundation

/// A persisted global-hot-key binding (Task 15): a Carbon key code plus a
/// Carbon modifier mask. Round-trips through `AppSettings`/UserDefaults as
/// two integers; the validation and display rules are pure and unit-tested.
struct HotKeyBinding: Equatable {

    var keyCode: UInt32
    var modifiers: UInt32

    static let `default` = HotKeyBinding(
        keyCode: HotKeyService.defaultKeyCode,
        modifiers: HotKeyService.defaultModifiers
    )

    /// Key codes that are modifiers themselves — pressing one can never be
    /// a binding, it would "match" before the real key arrives.
    nonisolated private static var modifierKeyCodes: Set<UInt32> {
        [
            UInt32(kVK_Command), UInt32(kVK_Shift), UInt32(kVK_CapsLock),
            UInt32(kVK_Option), UInt32(kVK_Control),
            UInt32(kVK_RightCommand), UInt32(kVK_RightShift),
            UInt32(kVK_RightOption), UInt32(kVK_RightControl),
        ]
    }

    /// Recorder acceptance rule (UI.md §4): at least one modifier, and the
    /// key itself is not a modifier key — a plain letter or function key
    /// would shadow normal typing system-wide.
    nonisolated static func isRegistrable(keyCode: UInt32, modifiers: UInt32) -> Bool {
        !modifierKeyCodes.contains(keyCode) && modifiers != 0
    }

    /// Human-readable form like "⌘⇧`". Modifiers render in macOS menu order
    /// (Control, Option, Shift, Command); the key glyph comes from an
    /// injected provider so this stays pure and testable.
    nonisolated func displayString(keyCharacter: (UInt32) -> String) -> String {
        var text = ""
        if modifiers & UInt32(controlKey) != 0 { text += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { text += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { text += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { text += "⌘" }
        return text + keyCharacter(keyCode)
    }
}
