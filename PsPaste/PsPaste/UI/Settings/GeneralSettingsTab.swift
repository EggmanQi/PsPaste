import SwiftUI

/// General settings (UI.md §4): launch at login, panel shortcut, history
/// capacity, retention span, theme. All controls bind straight to
/// `AppSettings` / `ThemeManager` / `LaunchAtLoginController`; writes take
/// effect immediately and persist for the next launch.
struct GeneralSettingsTab: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.hotKeyApplier) private var hotKeyApplier

    /// Bounces the launch toggle back by forcing a re-read of the
    /// SMAppService-backed binding when a toggle attempt fails.
    @State private var launchStatusRefresh = false
    @State private var launchError: String?

    var body: some View {
        Form {
            Section("Launch") {
                Toggle(
                    "Launch at login",
                    isOn: launchAtLoginBinding
                )
                .id(launchStatusRefresh)
                if let launchError {
                    Text(launchError)
                        .foregroundStyle(.red)
                }
            }
            Section("Shortcut") {
                ShortcutRecorder(current: settings.hotKeyBinding) { binding in
                    hotKeyApplier.attempt(binding)
                }
            }
            Section("History") {
                Stepper(
                    "Keep at most \(settings.historyLimit) items",
                    value: Bindable(settings).historyLimit,
                    in: AppSettings.Limit.minHistoryItems...AppSettings.Limit.maxHistoryItems
                )
                Picker("Keep items for", selection: Bindable(settings).retentionDays) {
                    ForEach(AppSettings.Limit.retentionOptionsDays, id: \.self) { days in
                        Text(Self.retentionLabel(for: days)).tag(days)
                    }
                }
                .pickerStyle(.menu)
            }
            Section("Appearance") {
                Picker("Theme", selection: themeSelection) {
                    ForEach(themeManager.themes, id: \.id) { theme in
                        Text(theme.name).tag(theme.id)
                    }
                }
                .pickerStyle(.radioGroup)
            }
        }
        .formStyle(.grouped)
        .padding(Metrics.Settings.formPadding)
    }

    /// SMAppService is the single source of truth (Task 15-A): the binding
    /// always re-reads status, so a failed toggle visibly bounces back once
    /// the forced refresh re-renders the control.
    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { LaunchAtLoginController.isEnabled() },
            set: { enabled in
                launchError = nil
                guard LaunchAtLoginController.setEnabled(enabled) else {
                    launchError = "Could not update the login item. Is the app in /Applications?"
                    launchStatusRefresh.toggle()
                    return
                }
                launchStatusRefresh.toggle()
            }
        )
    }

    /// ThemeManager persists in `currentIndex.didSet`; the picker binds to
    /// the id so the selection survives theme list reordering.
    private var themeSelection: Binding<String> {
        Binding(
            get: { themeManager.current.id },
            set: { themeManager.select(id: $0) }
        )
    }

    /// "1 year" reads better than "365 days" at the long end of the picker.
    nonisolated static func retentionLabel(for days: Int) -> String {
        days == 365 ? "1 year" : "\(days) days"
    }
}
