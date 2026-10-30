import Foundation

/// Bridges the settings recorder to the assembly (Task 15-B): attempts the
/// new binding at runtime, persists it, and reports whether it worked.
/// The environment key lives in the UI layer (ShortcutRecorder.swift).
struct HotKeyApplier {

    /// Returns false when the hot key is owned by another app; the caller
    /// keeps the old binding and shows the conflict inline.
    var attempt: @MainActor (HotKeyBinding) -> Bool
}
