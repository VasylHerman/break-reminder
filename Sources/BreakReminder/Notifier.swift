import Foundation
import UserNotifications

/// Sends Notification Center banners. Uses UNUserNotificationCenter when running from an
/// .app bundle, and falls back to `osascript` when launched as a bare binary (`swift run`),
/// where the UserNotifications framework is unavailable.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    private let hasBundle = Bundle.main.bundleIdentifier != nil

    override init() {
        super.init()
        if hasBundle {
            UNUserNotificationCenter.current().delegate = self
        }
    }

    func requestAuthorization() {
        guard hasBundle else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error { NSLog("Notification authorization failed: \(error)") }
        }
    }

    /// `sound` is a macOS alert sound name such as "Glass"; nil or empty means silent.
    func send(title: String, body: String, sound: String?) {
        let soundName = sound.flatMap { $0.isEmpty ? nil : $0 }
        if hasBundle {
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            if let soundName {
                // UNNotificationSound looks in /System/Library/Sounds among other places.
                content.sound = UNNotificationSound(named: UNNotificationSoundName("\(soundName).aiff"))
            }
            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request) { error in
                if let error { NSLog("Notification failed: \(error)") }
            }
        } else {
            var script = "display notification \"\(escape(body))\" with title \"\(escape(title))\""
            if let soundName { script += " sound name \"\(escape(soundName))\"" }
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            try? process.run()
        }
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }

    // Show banners even while the app is frontmost.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}
