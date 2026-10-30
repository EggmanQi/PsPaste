import XCTest
@testable import PsPaste

/// Settings read/write contract (Task 14): semantic UserDefaults keys,
/// defaults matching the previous hardcoded behavior (zero migration), and
/// change callbacks that let the assembly wire effective paths.
@MainActor
final class AppSettingsTests: XCTestCase {

    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = makeDefaults()
    }

    /// A fresh suite per test: the UUID name guarantees an empty domain, so
    /// no cleanup against shared state is needed.
    private func makeDefaults() -> UserDefaults {
        UserDefaults(suiteName: "AppSettingsTests.\(UUID().uuidString)")!
    }

    func testDefaultsMatchPreviousHardcodedBehavior() {
        let settings = AppSettings(defaults: defaults)
        XCTAssertEqual(settings.historyLimit, 1_000)
        XCTAssertEqual(settings.retentionDays, 30)
        XCTAssertEqual(settings.staleTTL, 30 * 24 * 60 * 60, accuracy: 0.001)
        XCTAssertTrue(settings.excludedBundleIDs.isEmpty)
    }

    func testRoundTripPersistsAllSettings() {
        let settings = AppSettings(defaults: defaults)
        settings.historyLimit = 250
        settings.retentionDays = 90
        settings.excludedBundleIDs = ["com.example.secret", "com.example.game"]

        // A fresh instance over the same suite reads the persisted values.
        let reloaded = AppSettings(defaults: defaults)
        XCTAssertEqual(reloaded.historyLimit, 250)
        XCTAssertEqual(reloaded.retentionDays, 90)
        XCTAssertEqual(reloaded.excludedBundleIDs, ["com.example.secret", "com.example.game"])
    }

    func testChangeCallbacksFireOnEveryWrite() {
        let settings = AppSettings(defaults: defaults)
        var limit: Int?
        var ttl: TimeInterval?
        var excluded: [String]?
        settings.onHistoryLimitChange = { limit = $0 }
        settings.onRetentionChange = { ttl = $0 }
        settings.onExcludedBundleIDsChange = { excluded = $0 }

        settings.historyLimit = 42
        settings.retentionDays = 7
        settings.excludedBundleIDs = ["com.example.secret"]

        XCTAssertEqual(limit, 42)
        XCTAssertEqual(ttl ?? -1, 7 * 24 * 60 * 60, accuracy: 0.001)
        XCTAssertEqual(excluded, ["com.example.secret"])
    }

    func testStaleTTLFollowsRetentionDaysSingleSource() {
        let settings = AppSettings(defaults: defaults)
        settings.retentionDays = 14
        XCTAssertEqual(settings.staleTTL, 14 * 24 * 60 * 60, accuracy: 0.001)
    }
}
