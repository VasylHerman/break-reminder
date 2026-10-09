import AppKit
import Foundation

/// Checks GitHub for a newer release once a day and installs it through Homebrew.
/// For a copy not installed by Homebrew it only points at the release page.
final class Updater {
    static let shared = Updater()

    enum State: Equatable {
        case idle
        case available(String)
        case installing(String)
        case installed(String)     // relaunch pending
        case failed(String)
    }

    private(set) var state: State = .idle { didSet { onChange?() } }
    var onChange: (() -> Void)?

    private let latestURL = URL(string: "https://api.github.com/repos/VasylHerman/break-reminder/releases/latest")!
    private let releasesPage = URL(string: "https://github.com/VasylHerman/break-reminder/releases/latest")!
    private var checking = false
    private let launchedAt = Date()
    /// In memory only: after a failed check the next try waits this long, not a whole day.
    private var lastAttempt: Date?
    private static let retryAfterFailure: TimeInterval = 15 * 60

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var installedWithHomebrew: Bool { Bundle.main.bundlePath.contains("/Cellar/") }

    /// True when install() can run brew itself, so it is safe to call without a click.
    static var canInstallAutomatically: Bool { installedWithHomebrew && brewPath != nil }

    static var brewPath: String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Daily check; the first one a minute after launch.
    func checkIfDue(force: Bool = false) {
        guard Settings.checkForUpdates || force, !checking else { return }
        if !force {
            if Date().timeIntervalSince(launchedAt) < 60 { return }
            if let last = Settings.lastUpdateCheck, Date().timeIntervalSince(last) < 24 * 3600 { return }
            if let attempt = lastAttempt, Date().timeIntervalSince(attempt) < Self.retryAfterFailure { return }
        }
        checking = true
        lastAttempt = Date()
        var request = URLRequest(url: latestURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("BreakReminder/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.checking = false
                // Only a real answer counts as a check; offline or rate limited, the next try is in minutes.
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String
                else { return }
                Settings.lastUpdateCheck = Date()
                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                Settings.latestKnownVersion = latest
                // A failed install is tried again after the next daily check.
                if case .failed = self.state { self.state = .idle }
                if Self.isNewer(latest, than: Self.currentVersion), case .idle = self.state {
                    self.state = .available(latest)
                }
            }
        }.resume()
    }

    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }, pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    /// Installs the update: `brew upgrade` in the background, then relaunch from the stable opt path.
    func install() {
        guard case .available(let version) = state else { return }
        guard Self.installedWithHomebrew, let brew = Self.brewPath else {
            NSWorkspace.shared.open(releasesPage)
            return
        }
        state = .installing(version)
        let task = Process()
        task.executableURL = URL(fileURLWithPath: brew)
        task.arguments = ["upgrade", "vasylherman/tap/break-reminder"]
        var env = ProcessInfo.processInfo.environment
        env["HOMEBREW_NO_ENV_HINTS"] = "1"
        env["HOMEBREW_NO_INSTALL_CLEANUP"] = "1"
        task.environment = env
        // Output goes to a file, not a pipe: nobody reads a pipe while brew runs, and a full one blocks it.
        let log = FileManager.default.temporaryDirectory.appendingPathComponent("break-reminder-upgrade-\(UUID().uuidString).log")
        FileManager.default.createFile(atPath: log.path, contents: nil)
        let output = try? FileHandle(forWritingTo: log)
        task.standardOutput = output
        task.standardError = output
        task.terminationHandler = { [weak self] process in
            let text = (try? String(contentsOf: log, encoding: .utf8)) ?? ""
            try? FileManager.default.removeItem(at: log)
            DispatchQueue.main.async {
                guard let self else { return }
                // Exit 0 is not enough: brew also exits 0 when the tap is behind and nothing was upgraded.
                if process.terminationStatus == 0, let installed = Self.installedVersion(), Self.isNewer(installed, than: Self.currentVersion) {
                    self.state = .installed(version)
                    self.relaunch(version: version)
                } else {
                    NSLog("brew upgrade failed: \(text.suffix(400))")
                    self.state = .failed(version)
                }
            }
        }
        do { try task.run() } catch { state = .failed(version) }
    }

    /// The app Homebrew's opt path points at, which after an upgrade is the new version.
    private static var optApp: URL {
        URL(fileURLWithPath: brewPath ?? "/opt/homebrew/bin/brew")
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("opt/break-reminder/BreakReminder.app")
    }

    private static func installedVersion() -> String? {
        Bundle(url: optApp)?.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// Start the new copy from the opt path, which Homebrew repoints at the new version; it takes over this one.
    private func relaunch(version: String) {
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: Self.optApp, configuration: config) { _, error in
            guard let error else { return }
            NSLog("relaunch failed: \(error)")
            DispatchQueue.main.async { self.state = .failed(version) }
        }
    }

    func openReleasePage() { NSWorkspace.shared.open(releasesPage) }
}
