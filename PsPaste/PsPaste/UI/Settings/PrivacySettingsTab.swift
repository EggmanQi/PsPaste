import SwiftUI

/// Privacy settings (UI.md §4): the excluded-app list (managed via
/// `AppSettings`, effective in the capture monitor from the next poll) and
/// the destructive "Clear History" action with a confirmation alert.
struct PrivacySettingsTab: View {
    @Environment(AppSettings.self) private var settings

    let store: ClipboardStore

    @State private var showsRunningAppPicker = false
    @State private var showsClearConfirmation = false

    var body: some View {
        Form {
            Section("Excluded Apps") {
                Text("Copies made in excluded apps are not recorded.")
                    .foregroundStyle(.secondary)
                if !settings.excludedBundleIDs.isEmpty {
                    List {
                        ForEach(settings.excludedBundleIDs, id: \.self) { bundleID in
                            ExcludedAppRow(bundleID: bundleID)
                        }
                        .onDelete(perform: remove)
                    }
                    .frame(minHeight: Metrics.Settings.excludedListMinHeight)
                }
                Button("Add from Running Apps…") {
                    showsRunningAppPicker = true
                }
            }
            Section("Data") {
                Button("Clear History…") {
                    showsClearConfirmation = true
                }
            }
        }
        .formStyle(.grouped)
        .padding(Metrics.Settings.formPadding)
        .sheet(isPresented: $showsRunningAppPicker) {
            RunningAppPicker { bundleID in
                add(bundleID)
            }
        }
        .alert("Clear History?", isPresented: $showsClearConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                store.clearAll()
            }
        } message: {
            Text("Every record and stored payload will be deleted. This cannot be undone.")
        }
    }

    private func remove(at offsets: IndexSet) {
        settings.excludedBundleIDs.remove(atOffsets: offsets)
    }

    /// Dedup guard: re-picking an already excluded app is a no-op.
    private func add(_ bundleID: String) {
        guard !settings.excludedBundleIDs.contains(bundleID) else { return }
        settings.excludedBundleIDs.append(bundleID)
    }
}

/// One excluded app: icon + display name + bundle id (source of truth).
private struct ExcludedAppRow: View {
    let bundleID: String

    var body: some View {
        HStack(spacing: Metrics.Settings.rowIconSpacing) {
            if let icon = SourceAppDisplay.icon(for: bundleID, size: Metrics.Settings.rowIconSize) {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: Metrics.Settings.rowIconSize, height: Metrics.Settings.rowIconSize)
            }
            VStack(alignment: .leading) {
                Text(SourceAppDisplay.name(for: bundleID))
                Text(bundleID)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, Metrics.Settings.rowVerticalPadding)
    }
}
