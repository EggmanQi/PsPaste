import SwiftUI

/// General settings (UI.md §4): history capacity, retention span, theme.
/// All controls bind straight to `AppSettings` / `ThemeManager`; writes
/// persist in `didSet` and propagate to the effective paths immediately.
struct GeneralSettingsTab: View {
    @Environment(AppSettings.self) private var settings
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        Form {
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
