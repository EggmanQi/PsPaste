import Carbon
import SwiftUI

private struct HotKeyApplierKey: EnvironmentKey {
    static let defaultValue = HotKeyApplier { _ in false }
}

extension EnvironmentValues {
    var hotKeyApplier: HotKeyApplier {
        get { self[HotKeyApplierKey.self] }
        set { self[HotKeyApplierKey.self] = newValue }
    }
}

/// Shortcut recorder (UI.md §4 General, Task 15-B): shows the current
/// binding, records the next key press on demand, validates it, and applies
/// it through the injected `HotKeyApplier`. Esc cancels recording; a
/// rejected binding keeps the old one and shows the conflict inline.
struct ShortcutRecorder: View {

    /// The persisted binding, re-read by the label after every apply.
    let current: HotKeyBinding
    let onApply: (HotKeyBinding) -> Bool

    @State private var isRecording = false
    @State private var hint: String?
    @State private var showsConflict = false
    @State private var sink = RecordingSink()
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: Metrics.Settings.recorderSpacing) {
            Text(isRecording ? "Press new shortcut…" : current.displayText)
                .frame(minWidth: Metrics.Settings.shortcutLabelMinWidth, alignment: .leading)
                .foregroundStyle(isRecording ? .secondary : .primary)
            Button(isRecording ? "Cancel" : "Record") {
                if isRecording {
                    cancelRecording()
                } else {
                    startRecording()
                }
            }
        }
        Group {
            if isRecording, let hint {
                Text(hint)
                    .foregroundStyle(.secondary)
            }
            if showsConflict {
                Text("Shortcut in use — the previous binding is kept.")
                    .foregroundStyle(.red)
            }
        }
        .font(.callout)
    }

    private func startRecording() {
        isRecording = true
        hint = nil
        showsConflict = false
        sink.onKey = handleKey
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [sink] event in
            // Local monitors fire on the main run loop.
            MainActor.assumeIsolated { sink.dispatch(event) }
            return nil
        }
    }

    private func cancelRecording() {
        stopMonitoring()
        isRecording = false
        hint = nil
    }

    private func stopMonitoring() {
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handleKey(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            cancelRecording()
            return
        }
        let keyCode = UInt32(event.keyCode)
        let modifiers = HotKeyService.carbonModifiers(from: event.modifierFlags)
        guard HotKeyBinding.isRegistrable(keyCode: keyCode, modifiers: modifiers) else {
            hint = "Add at least one modifier key (⌃ ⌥ ⇧ ⌘)."
            return
        }
        stopMonitoring()
        isRecording = false
        hint = nil
        showsConflict = !onApply(HotKeyBinding(keyCode: keyCode, modifiers: modifiers))
    }

    /// Reference-type monitor target: the NSEvent monitor closure is not
    /// Sendable-friendly over the view value, so key events land here.
    /// The class is @MainActor; the monitor closure enters isolation via
    /// `MainActor.assumeIsolated` (local monitors fire on the main run loop).
    @MainActor
    final class RecordingSink {
        var onKey: ((NSEvent) -> Void)?

        func dispatch(_ event: NSEvent) {
            onKey?(event)
        }
    }
}
