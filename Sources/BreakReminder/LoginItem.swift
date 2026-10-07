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
}
