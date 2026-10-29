import XCTest
@testable import PsPaste

/// Task 11-A: the theme manager switches themes, persists the choice under
/// the `selectedTheme` key, restores it on launch, and ignores unknown ids.
@MainActor
final class ThemeManagerTests: XCTestCase {

    private let suiteName = "ThemeManagerTests"

    private func makeDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testSelectSwitchesCurrentAndPersistsID() {
        let defaults = makeDefaults()
        let manager = ThemeManager(defaults: defaults)

        manager.select(id: "particle")

        XCTAssertEqual(manager.current.id, "particle")
        XCTAssertEqual(defaults.string(forKey: ThemeManager.storageKey), "particle")
    }

    func testInitialSelectionRestoresPersistedID() {
        let defaults = makeDefaults()
        defaults.set("particle", forKey: ThemeManager.storageKey)

        let manager = ThemeManager(defaults: defaults)

        XCTAssertEqual(manager.current.id, "particle")
    }

    func testMissingOrUnknownPersistedIDFallsBackToFirstTheme() {
        let defaults = makeDefaults()
        defaults.set("no-such-theme", forKey: ThemeManager.storageKey)

        let manager = ThemeManager(defaults: defaults)

        XCTAssertEqual(manager.current.id, "parchment")
    }

    func testSelectWithUnknownIDKeepsCurrentThemeAndPersistsNothing() {
        let defaults = makeDefaults()
        let manager = ThemeManager(defaults: defaults)

        manager.select(id: "bogus")

        XCTAssertEqual(manager.current.id, "parchment")
        XCTAssertNil(defaults.string(forKey: ThemeManager.storageKey))
    }
}
