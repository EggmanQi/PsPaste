import AppKit
import XCTest
@testable import PsPaste

/// Pure helpers behind the settings UI (Task 14): the retention label and
/// the running-app candidate filter. Kept separate from AppSettingsTests
/// because these live on the view layer.
final class SettingsHelpersTests: XCTestCase {

    func testRetentionLabelUsesYearFor365Days() {
        XCTAssertEqual(GeneralSettingsTab.retentionLabel(for: 7), "7 days")
        XCTAssertEqual(GeneralSettingsTab.retentionLabel(for: 365), "1 year")
    }

    func testPickableCandidatesFilterAndSort() {
        let own = candidate("com.ebs.pspaste", "P's Paste", .regular)
        let safari = candidate("com.apple.Safari", "Safari", .regular)
        let xcode = candidate("com.apple.dt.Xcode", "Xcode", .regular)
        let daemon = candidate("com.apple.dock", "Dock", .prohibited)

        let picked = RunningAppPicker.pickableCandidates(
            from: [own, xcode, daemon, safari],
            ownBundleID: "com.ebs.pspaste"
        )

        // Regular apps only, ourselves excluded, alphabetical by name.
        XCTAssertEqual(picked.map(\.bundleID), ["com.apple.Safari", "com.apple.dt.Xcode"])
    }

    private func candidate(
        _ bundleID: String,
        _ name: String,
        _ policy: NSApplication.ActivationPolicy
    ) -> RunningAppPicker.AppCandidate {
        RunningAppPicker.AppCandidate(
            bundleID: bundleID,
            name: name,
            icon: nil,
            activationPolicy: policy
        )
    }
}
