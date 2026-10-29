import Foundation
import SwiftUI

/// Holds the active theme and persists the choice (UI.md §5.2). Published
/// through `@Observable` and injected into the view tree via `.environment`,
/// so switching re-renders instantly and survives relaunches.
///
/// The spec names `@AppStorage("selectedTheme")`; `@AppStorage` only works
/// inside View/Scene contexts, so the same `UserDefaults` key is written
/// directly here instead (value-compatible).
@Observable
@MainActor
final class ThemeManager {

    static let shared = ThemeManager()
    static let storageKey = "selectedTheme"

    /// All switchable themes, in menu order.
    let themes: [any Theme]

    private let defaults: UserDefaults

    var currentIndex: Int {
        didSet { defaults.set(themes[currentIndex].id, forKey: Self.storageKey) }
    }

    var current: any Theme { themes[currentIndex] }

    init(defaults: UserDefaults = .standard, themes: [any Theme]? = nil) {
        self.defaults = defaults
        self.themes = themes ?? [ParchmentTheme(), ParticleTheme()]
        let savedID = defaults.string(forKey: Self.storageKey)
        self.currentIndex = self.themes.firstIndex { $0.id == savedID } ?? 0
    }

    /// Switch by theme id; unknown ids are ignored (UI stays on the current
    /// theme and the persisted value is left untouched).
    func select(id: String) {
        guard let index = themes.firstIndex(where: { $0.id == id }) else { return }
        currentIndex = index
    }
}
