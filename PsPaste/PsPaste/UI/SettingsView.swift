import SwiftUI

/// Settings window content (UI.md §4, Task 14): General / Privacy / About.
/// The Sync tab is deliberately absent from v1 (blocked on a paid developer
/// account for CloudKit) — fewer dead tabs. Standard macOS `TabView` inside
/// a regular window; values read/write `AppSettings` (UserDefaults).
struct SettingsView: View {

    /// Privacy's "Clear History" needs the store.
    let store: ClipboardStore

    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem { Label("General", systemImage: "gearshape") }
            PrivacySettingsTab(store: store)
                .tabItem { Label("Privacy", systemImage: "lock") }
            AboutSettingsTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(
            minWidth: Metrics.Settings.minContentWidth,
            minHeight: Metrics.Settings.minContentHeight
        )
    }
}
