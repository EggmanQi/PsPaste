import AppKit
import Carbon
import XCTest
@testable import PsPaste

/// Hot key binding rules (Task 15-B): recorder acceptance, modifier
/// mapping, and the display form — all pure, no Carbon registration.
final class HotKeyBindingTests: XCTestCase {

    func testDefaultBindingMatchesServiceDefaults() {
        XCTAssertEqual(HotKeyBinding.default.keyCode, HotKeyService.defaultKeyCode)
        XCTAssertEqual(HotKeyBinding.default.modifiers, HotKeyService.defaultModifiers)
    }

    func testPlainLetterWithoutModifierIsNotRegistrable() {
        XCTAssertFalse(
            HotKeyBinding.isRegistrable(keyCode: UInt32(kVK_ANSI_A), modifiers: 0)
        )
    }

    func testLetterWithModifierIsRegistrable() {
        XCTAssertTrue(
            HotKeyBinding.isRegistrable(keyCode: UInt32(kVK_ANSI_V), modifiers: UInt32(cmdKey))
        )
    }

    func testModifierKeyItselfIsNotRegistrableEvenWithModifiers() {
        XCTAssertFalse(
            HotKeyBinding.isRegistrable(keyCode: UInt32(kVK_Command), modifiers: UInt32(cmdKey))
        )
        XCTAssertFalse(
            HotKeyBinding.isRegistrable(keyCode: UInt32(kVK_Shift), modifiers: UInt32(shiftKey))
        )
    }

    func testFunctionKeyWithModifierIsRegistrable() {
        XCTAssertTrue(
            HotKeyBinding.isRegistrable(keyCode: UInt32(kVK_F1), modifiers: UInt32(shiftKey))
        )
    }

    func testDisplayStringRendersModifiersInMenuOrder() {
        let binding = HotKeyBinding(
            keyCode: UInt32(kVK_ANSI_Grave),
            modifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey)
        )
        XCTAssertEqual(
            binding.displayString { _ in "`" },
            "⌃⌥⇧⌘`"
        )
    }

    func testDisplayStringUsesInjectedKeyCharacter() {
        let binding = HotKeyBinding(
            keyCode: UInt32(kVK_ANSI_V),
            modifiers: UInt32(cmdKey)
        )
        XCTAssertEqual(binding.displayString { _ in "V" }, "⌘V")
    }

    // MARK: - KeyCodeDisplay

    @MainActor
    func testPrintableKeyTranslatesThroughLayoutNotFallback() {
        // The glyph depends on the user's layout, so only assert the
        // translation path works: a broken layout read falls back to "Key N".
        let glyph = KeyCodeDisplay.glyph(forKeyCode: UInt32(kVK_ANSI_Grave))
        XCTAssertFalse(glyph.isEmpty)
        XCTAssertFalse(glyph.hasPrefix("Key "), "layout read failed: \(glyph)")
    }

    @MainActor
    func testPrintableGlyphIsUppercaseAndKeyEquivalentIsLowercase() {
        let glyph = KeyCodeDisplay.glyph(forKeyCode: UInt32(kVK_ANSI_V))
        let keyEquivalent = KeyCodeDisplay.menuKeyEquivalent(forKeyCode: UInt32(kVK_ANSI_V))
        XCTAssertEqual(glyph, glyph.uppercased())
        XCTAssertEqual(keyEquivalent, keyEquivalent.lowercased())
        XCTAssertEqual(glyph.lowercased(), keyEquivalent)
    }

    @MainActor
    func testSpecialKeysUseFixedGlyphs() {
        XCTAssertEqual(KeyCodeDisplay.glyph(forKeyCode: UInt32(kVK_Space)), "Space")
        XCTAssertEqual(KeyCodeDisplay.glyph(forKeyCode: UInt32(kVK_Return)), "↩")
        XCTAssertEqual(KeyCodeDisplay.glyph(forKeyCode: UInt32(kVK_LeftArrow)), "←")
        XCTAssertEqual(KeyCodeDisplay.glyph(forKeyCode: UInt32(kVK_F1)), "F1")
        XCTAssertEqual(KeyCodeDisplay.glyph(forKeyCode: UInt32(kVK_F12)), "F12")
        XCTAssertEqual(KeyCodeDisplay.glyph(forKeyCode: UInt32(kVK_F20)), "F20")
    }

    @MainActor
    func testSpecialKeysUseFunctionKeyEquivalents() {
        XCTAssertEqual(
            KeyCodeDisplay.menuKeyEquivalent(forKeyCode: UInt32(kVK_F5)),
            String(NSEvent.SpecialKey.f5.unicodeScalar)
        )
        XCTAssertEqual(KeyCodeDisplay.menuKeyEquivalent(forKeyCode: UInt32(kVK_Space)), " ")
    }

    @MainActor
    func testMenuItemTakesBindingAsKeyEquivalent() {
        let item = NSMenuItem()
        item.setKeyEquivalent(for: HotKeyBinding(
            keyCode: UInt32(kVK_F5),
            modifiers: UInt32(cmdKey | optionKey)
        ))
        XCTAssertEqual(item.keyEquivalent, String(NSEvent.SpecialKey.f5.unicodeScalar))
        XCTAssertEqual(item.keyEquivalentModifierMask, [.command, .option])
    }
}
