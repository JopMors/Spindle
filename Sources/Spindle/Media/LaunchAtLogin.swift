import ServiceManagement

/// Registers the widget as a login item.
///
/// `SMAppService` is the modern replacement for login-item helpers: it needs no
/// helper bundle and no privileged install, and it puts the app under System
/// Settings → General → Login Items where it can be turned off without us.
///
/// The system, not `UserDefaults`, is the source of truth — the user can revoke
/// it there at any time, so the setting is always read back rather than cached.
enum LaunchAtLogin {

    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// True when macOS has the registration but is waiting for the user to
    /// approve it in System Settings.
    static var needsApproval: Bool {
        SMAppService.mainApp.status == .requiresApproval
    }

    /// Returns the state that actually resulted, which may differ from what was
    /// asked for when macOS wants approval first.
    @discardableResult
    static func set(_ enabled: Bool) -> Bool {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            Diagnostics.log("launch at login \(enabled ? "register" : "unregister") failed: "
                + error.localizedDescription)
        }
        return isEnabled
    }
}
