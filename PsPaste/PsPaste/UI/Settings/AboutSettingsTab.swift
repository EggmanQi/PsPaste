import SwiftUI

/// About settings (UI.md §4): app version (from the bundle) and the
/// Accessibility permission status with its authorization entry points.
struct AboutSettingsTab: View {

    @State private var isAccessibilityTrusted = PasteService.isAccessibilityTrusted()

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            ?? "Unknown"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            ?? "0"
        return "\(version) (\(build))"
    }

    var body: some View {
        Form {
            Section("Version") {
                LabeledContent("P's Paste", value: versionString)
            }
            Section("Accessibility") {
                LabeledContent(
                    "Direct paste permission",
                    value: isAccessibilityTrusted ? "Granted" : "Not granted"
                )
                .foregroundStyle(isAccessibilityTrusted ? .secondary : .primary)
                if isAccessibilityTrusted {
                    Text("P's Paste may simulate ⌘V, so confirming an entry pastes it straight into the previous app.")
                        .foregroundStyle(.secondary)
                }
                Button("Open Accessibility Settings…") {
                    NSWorkspace.shared.open(PasteService.accessibilitySettingsURL)
                }
                if !isAccessibilityTrusted {
                    Button("Check Again") {
                        isAccessibilityTrusted = PasteService.isAccessibilityTrusted()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding(Metrics.Settings.formPadding)
        .onAppear {
            isAccessibilityTrusted = PasteService.isAccessibilityTrusted()
        }
        // The grant happens in System Settings; re-check on the way back.
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            isAccessibilityTrusted = PasteService.isAccessibilityTrusted()
        }
    }
}
