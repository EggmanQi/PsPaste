import Foundation

/// Typed access to every user-facing preference (Task 14). All values are
/// semantic `UserDefaults` keys whose defaults match the previous hardcoded
/// behavior, so existing installs need zero migration. Every write persists
/// in `didSet` and passes through to the assembly-wired change callback, so
/// settings take effect without a relaunch.
@Observable
@MainActor
final class AppSettings {

    static let shared = AppSettings()

    /// Persisted keys, one per semantic setting.
    enum Key {
        static let historyLimit = "historyLimit"
        static let retentionDays = "retentionDays"
        static let excludedBundleIDs = "excludedBundleIDs"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
    }

    /// Value bounds and options. Pure constants, unit-tested.
    enum Limit {
        static let minHistoryItems = 1
        static let maxHistoryItems = 10_000
        static let defaultHistoryItems = 1_000
        /// Retention picker options, in days.
        static let retentionOptionsDays = [7, 14, 30, 90, 180, 365]
        static let defaultRetentionDays = 30
        static let secondsPerDay: TimeInterval = 24 * 60 * 60
    }

    /// Wired by the assembly: applies a new history limit to the store.
    var onHistoryLimitChange: ((Int) -> Void)?
    /// Wired by the assembly: applies a new retention span to the store.
    var onRetentionChange: ((TimeInterval) -> Void)?
    /// Wired by the assembly: pushes the excluded list to the capture monitor.
    var onExcludedBundleIDsChange: (([String]) -> Void)?
    /// Wired by the assembly: refreshes the shortcut hints in the menus.
    var onHotKeyBindingChange: ((HotKeyBinding) -> Void)?

    var historyLimit: Int {
        didSet {
            defaults.set(historyLimit, forKey: Key.historyLimit)
            onHistoryLimitChange?(historyLimit)
        }
    }

    /// How long unused records are kept, in days (same source as the store
    /// eviction TTL — one value, two units; Task 14 makes it adjustable).
    var retentionDays: Int {
        didSet {
            defaults.set(retentionDays, forKey: Key.retentionDays)
            onRetentionChange?(staleTTL)
        }
    }

    var staleTTL: TimeInterval {
        Double(retentionDays) * Limit.secondsPerDay
    }

    /// Source apps whose copies are not recorded (UI.md §4 Privacy).
    var excludedBundleIDs: [String] {
        didSet {
            defaults.set(excludedBundleIDs, forKey: Key.excludedBundleIDs)
            onExcludedBundleIDsChange?(excludedBundleIDs)
        }
    }

    /// The global panel hot key (UI.md §4 General, Task 15). Mutable only
    /// through `setHotKeyBinding` so the pair persists and applies
    /// atomically; absent keys fall back to the default ⌘⇧`.
    private(set) var hotkeyKeyCode: UInt32
    private(set) var hotkeyModifiers: UInt32

    var hotKeyBinding: HotKeyBinding {
        HotKeyBinding(keyCode: hotkeyKeyCode, modifiers: hotkeyModifiers)
    }

    /// Persists a new hot key binding (Task 15). The assembly's applier
    /// registers it first and only calls this on success, so a persisted
    /// binding always matches the live registration.
    func setHotKeyBinding(_ binding: HotKeyBinding) {
        hotkeyKeyCode = binding.keyCode
        hotkeyModifiers = binding.modifiers
        defaults.set(Int(binding.keyCode), forKey: Key.hotkeyKeyCode)
        defaults.set(Int(binding.modifiers), forKey: Key.hotkeyModifiers)
        onHotKeyBindingChange?(binding)
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.historyLimit = defaults.object(forKey: Key.historyLimit) as? Int
            ?? Limit.defaultHistoryItems
        self.retentionDays = defaults.object(forKey: Key.retentionDays) as? Int
            ?? Limit.defaultRetentionDays
        self.excludedBundleIDs = defaults.stringArray(forKey: Key.excludedBundleIDs)
            ?? []
        self.hotkeyKeyCode = defaults.object(forKey: Key.hotkeyKeyCode).flatMap { $0 as? Int }
            .flatMap(UInt32.init) ?? HotKeyService.defaultKeyCode
        self.hotkeyModifiers = defaults.object(forKey: Key.hotkeyModifiers).flatMap { $0 as? Int }
            .flatMap(UInt32.init) ?? HotKeyService.defaultModifiers
    }
}
