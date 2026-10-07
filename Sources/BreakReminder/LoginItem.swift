import Foundation
import ServiceManagement

/// Launch at login as a standard login item. A launchd agent would also restart the app after a crash,
/// but launchd rejects agents of ad-hoc signed apps; `brew services start break-reminder` provides that.
enum LoginItem {
    static var isEnabled: Bool { SMAppService.mainApp.status == .enabled }

    static func set(enabled: Bool) throws {
        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }
    }

    /// Turns launch at login on the first time an installed copy runs. Only once, so turning it off
    /// later sticks, and only for a bundle in a permanent place: Homebrew's Cellar or /Applications.
    static func enableOnFirstRun() {
        guard !Settings.loginItemOffered else { return }
        let path = Bundle.main.bundlePath
        guard path.contains("/Cellar/") || path.hasPrefix("/Applications/") else { return }
        Settings.loginItemOffered = true
        guard SMAppService.mainApp.status == .notRegistered else { return }
        try? SMAppService.mainApp.register()
    }
}
