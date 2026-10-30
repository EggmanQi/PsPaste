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
}
