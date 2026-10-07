import AppKit
import Foundation

/// Links and prefilled GitHub issue forms, shared by the menu and the Settings window.
enum Feedback {
    static let repositoryURL = URL(string: "https://github.com/VasylHerman/break-reminder")!
    static let releasesURL = URL(string: "https://github.com/VasylHerman/break-reminder/releases")!
    static let newIssueURL = URL(string: "https://github.com/VasylHerman/break-reminder/issues/new")!
    static let installCommand = "brew install vasylherman/tap/break-reminder"

    /// Set by the app delegate so reports can include the current timer state.
    static var snapshotProvider: () -> ActivityTracker.Snapshot? = { nil }
    static var blockStartProvider: () -> Date? = { nil }

    static var versionString: String {
        guard let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return "dev" }
        return "v\(short)"
    }

    static var installMethod: String {
        Bundle.main.bundlePath.contains("/Cellar/") ? "Homebrew" : "manual build"
    }

    static func openRepository() { NSWorkspace.shared.open(repositoryURL) }
    static func openReleaseNotes() { NSWorkspace.shared.open(releasesURL) }
    static func requestFeature() { openIssueForm(template: "feature_request.yml") }
    static func reportBug() { openIssueForm(template: "bug_report.yml") }

    static func copyInstallCommand() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(installCommand, forType: .string)
    }

    /// Context pasted into the "Environment" field of a feature request or bug report.
    static func environmentReport() -> String {
        let os = ProcessInfo.processInfo.operatingSystemVersionString
        var lines = [
            "Break Reminder \(versionString), macOS \(os), installed via \(installMethod)",
            "Settings: work limit \(Settings.workLimitMinutes)m, rest after \(Settings.restThresholdMinutes)m idle, "
                + "warn \(Settings.warnBeforeMinutes)m before, remind every \(Settings.remindEveryMinutes)m, "
                + "sound \(Settings.notificationSound.isEmpty ? "off" : Settings.notificationSound)",
        ]
        let triggers = [
            Settings.smartPauseCall ? "call" : nil, Settings.smartPauseScreenShare ? "share" : nil,
            Settings.smartPauseFullscreen ? "fullscreen" : nil,
        ].compactMap { $0 }
        let smart = Settings.smartPauseEnabled ? (triggers.isEmpty ? "on, no triggers" : triggers.joined(separator: ", ")) : "off"
        lines.append("Smart Pause: \(smart), grace \(Settings.smartPauseGraceMinutes)m")
        if let snapshot = snapshotProvider() {
            let state = snapshot.state == .working ? "working" : "resting"
            lines.append("State: \(state) for \(TimeFormat.minutes(snapshot.currentSeconds)), idle \(Int(snapshot.idleSeconds))s")
        }
        return lines.joined(separator: "\n")
    }

    /// Opens a prefilled GitHub issue form. Field ids match .github/ISSUE_TEMPLATE/*.yml.
    private static func openIssueForm(template: String) {
        var components = URLComponents(url: newIssueURL, resolvingAgainstBaseURL: false)!
        let items = [
            URLQueryItem(name: "template", value: template),
            URLQueryItem(name: "environment", value: environmentReport()),
        ]
        // Encode everything outside the unreserved set so "+" and "&" in the text survive the trip.
        let unreserved = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        components.percentEncodedQuery = items.map { item in
            let name = item.name.addingPercentEncoding(withAllowedCharacters: unreserved) ?? item.name
            let value = (item.value ?? "").addingPercentEncoding(withAllowedCharacters: unreserved) ?? ""
            return "\(name)=\(value)"
        }.joined(separator: "&")
        if let url = components.url {
            NSWorkspace.shared.open(url)
        }
    }
}

enum TimeFormat {
    /// Menu bar counter: "23" for minutes and "1:05" from an hour on, or "23m" and "1h 05m" with the unit.
    static func counter(_ seconds: TimeInterval, showUnit: Bool) -> String {
        if showUnit { return minutes(seconds) }
        let total = Int(seconds) / 60
        let hours = total / 60
        let minutes = total % 60
        return hours > 0 ? String(format: "%d:%02d", hours, minutes) : "\(minutes)"
    }

    /// "23m" or "1h 05m".
    static func minutes(_ seconds: TimeInterval) -> String {
        let total = Int(seconds) / 60
        let hours = total / 60
        let minutes = total % 60
        return hours > 0 ? String(format: "%dh %02dm", hours, minutes) : "\(minutes)m"
    }
}
