import Foundation
import UserNotifications

/// Sends Notification Center banners. Uses UNUserNotificationCenter when running from an
/// .app bundle, and falls back to `osascript` when launched as a bare binary (`swift run`),
/// where the UserNotifications framework is unavailable.
final class Notifier: NSObject, UNUserNotificationCenterDelegate {
    static let shared = Notifier()

    private let hasBundle = Bundle.main.bundleIdentifier != nil

    static let steppedDownCategory = "steppedDown"
    static let pauseTodayAction = "pauseToday"
    static let openSettingsAction = "openSettings"

    /// Handlers for the card's buttons, set by the app delegate.
    var onPauseToday: (() -> Void)?
    var onOpenSettings: (() -> Void)?

    override init() {
        super.init()
        if hasBundle {
            let center = UNUserNotificationCenter.current()
            center.delegate = self
            let category = UNNotificationCategory(
                identifier: Self.steppedDownCategory,
                actions: [
                    UNNotificationAction(identifier: Self.pauseTodayAction, title: "Pause for Today"),
                    UNNotificationAction(identifier: Self.openSettingsAction, title: "Change Limit…", options: [.foreground]),
                ],
                intentIdentifiers: []
            )
            center.setNotificationCategories([category])
        }
    }

    /// Shown once when the automatic firmness steps down because reminders were ignored all week.
    func sendSteppedDownCard() {
        guard hasBundle else {
            send(title: "Reminders are quieter now", body: "Most reminders were skipped this week. Change the limit in Settings, or pause for today.", sound: nil)
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "Reminders are quieter now"
        content.body = "Most reminders were skipped this week, so repeats and blinking are off. Change the limit, or pause for today."
        content.categoryIdentifier = Self.steppedDownCategory
        let request = UNNotificationRequest(identifier: "steppedDown", content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request) { error in
            if let error { NSLog("Card failed: \(error)") }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        switch response.actionIdentifier {
        case Self.pauseTodayAction: onPauseToday?()
        case Self.openSettingsAction: onOpenSettings?()
        default: break
        }
        completionHandler()
    }

    func requestAuthorization() {
        guard hasBundle else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, error in
            if let error { NSLog("Notification authorization failed: \(error)") }
        }
    }

    /// `sound` is a macOS alert sound name such as "Glass"; nil or empty means silent.
    /// The reminder shown after `minutes` of continuous work, also used for the test button.
    /// `repeated` is true for the second and later reminders of the same block, which get shorter text.
    func sendBreakReminder(minutes: Int, repeated: Bool = false) {
        let (title, body) = Self.reminderText(minutes: minutes, repeated: repeated)
        send(title: title, body: body, sound: Settings.notificationSound)
    }

    /// Title and body for a reminder: a suggested activity with an optional prefix in front.
    static func reminderText(minutes: Int, repeated: Bool) -> (title: String, body: String) {
        func fill(_ template: String) -> String {
            template
                .replacingOccurrences(of: "{minutes}", with: String(minutes))
                .replacingOccurrences(of: "{rest}", with: String(Settings.restThresholdMinutes))
        }
        let prefix = fill(Settings.reminderTitle).trimmingCharacters(in: .whitespaces)

        if let activity = BreakActivities.pick(enabled: Settings.activityCategories, recent: Settings.recentActivities) {
            Settings.recentActivities = Settings.recentActivities + [activity.title]
            // The activity is the headline; an optional prefix from Settings goes in front.
            let headline = prefix.isEmpty ? activity.title : "\(prefix) · \(activity.title)"
            if repeated {
                let over = max(0, minutes - Settings.workLimitMinutes)
                let cue = over > 0 ? "\(over) min over" : "Still here"
                return (title: "\(cue) · \(activity.title)", body: "\(activity.title), then back.")
            }
            var body = activity.body.isEmpty ? "\(minutes) minutes in. Time for it." : activity.body
            if Settings.activityWhy, !activity.why.isEmpty { body += " " + activity.why }
            return (title: headline, body: body)
        }
        // Every category off, or nothing fits right now: the plain reminder.
        let title = prefix.isEmpty ? Settings.defaultReminderTitle : prefix
        return (title: title, body: fill(Settings.defaultReminderBody))
    }

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
