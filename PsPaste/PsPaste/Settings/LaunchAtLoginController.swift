import ServiceManagement

/// Launch-at-login state and toggling (UI.md §4 General, Task 15-A) via
/// `SMAppService.mainApp` (macOS 13+; deployment target 14.0 satisfies).
///
/// SMAppService is the single source of truth — the UI reads
/// `status` directly and there is no UserDefaults mirror that could drift.
enum LaunchAtLoginController {

    /// The registrable surface, extracted so tests can inject a mock —
    /// SMAppService itself is a process-wide singleton.
    protocol LoginItemManaging {
        var status: SMAppService.Status { get }
        func register() throws
        func unregister() throws
    }

    static func isEnabled(using item: some LoginItemManaging = SMAppService.mainApp) -> Bool {
        item.status == .enabled
    }

    /// Toggles the login item. Returns false when the operation throws
    /// (rare — e.g. the app is not under /Applications); the caller bounces
    /// the toggle back and shows the error line.
    @discardableResult
    static func setEnabled(
        _ enabled: Bool,
        using item: some LoginItemManaging = SMAppService.mainApp
    ) -> Bool {
        do {
            if enabled {
                try item.register()
            } else {
                try item.unregister()
            }
            return true
        } catch {
            return false
        }
    }
}

extension SMAppService: LaunchAtLoginController.LoginItemManaging {}
