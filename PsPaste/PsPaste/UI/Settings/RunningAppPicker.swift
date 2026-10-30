import AppKit
import SwiftUI

/// Sheet for picking a running app to exclude (UI.md §4 Privacy). Lists
/// regular (foreground-capable) running apps minus ourselves; selection
/// hands the bundle id back to `PrivacySettingsTab`.
struct RunningAppPicker: View {
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss

    private static let ownBundleID = Bundle.main.bundleIdentifier

    var body: some View {
        List(candidates, id: \.bundleID) { candidate in
            Button {
                onSelect(candidate.bundleID)
                dismiss()
            } label: {
                HStack(spacing: Metrics.Settings.rowIconSpacing) {
                    if let icon = candidate.icon {
                        Image(nsImage: icon)
                            .resizable()
                            .frame(width: Metrics.Settings.rowIconSize, height: Metrics.Settings.rowIconSize)
                    }
                    VStack(alignment: .leading) {
                        Text(candidate.name)
                        Text(candidate.bundleID)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .frame(
            width: Metrics.Settings.pickerWidth,
            height: Metrics.Settings.pickerHeight
        )
    }

    @MainActor private var candidates: [AppCandidate] {
        Self.pickableCandidates(
            from: NSWorkspace.shared.runningApplications.map(AppCandidate.init),
            ownBundleID: Self.ownBundleID
        )
    }

    /// A foreground-capable running app, as display values.
    struct AppCandidate: Equatable {
        var bundleID: String
        var name: String
        var icon: NSImage?
        var activationPolicy: NSApplication.ActivationPolicy
    }

    /// The filter rule, pure over plain values so tests can inject candidates
    /// without constructing real `NSRunningApplication`s: regular activation
    /// policy, resolvable bundle id, not this app, alphabetical by name.
    nonisolated static func pickableCandidates(
        from apps: [AppCandidate],
        ownBundleID: String?
    ) -> [AppCandidate] {
        apps
            .filter {
                $0.activationPolicy == .regular
                    && !$0.bundleID.isEmpty
                    && $0.bundleID != ownBundleID
                    && !$0.name.isEmpty
            }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}

private extension RunningAppPicker.AppCandidate {
    init(app: NSRunningApplication) {
        self.bundleID = app.bundleIdentifier ?? ""
        self.name = app.localizedName ?? app.bundleIdentifier ?? ""
        self.icon = app.icon
        self.activationPolicy = app.activationPolicy
    }
}
