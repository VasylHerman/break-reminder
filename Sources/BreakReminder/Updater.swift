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

    static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    static var installedWithHomebrew: Bool { Bundle.main.bundlePath.contains("/Cellar/") }

    static var brewPath: String? {
        ["/opt/homebrew/bin/brew", "/usr/local/bin/brew"].first { FileManager.default.isExecutableFile(atPath: $0) }
    }

    /// Daily check; the first one a minute after launch.
    func checkIfDue(force: Bool = false) {
        guard Settings.checkForUpdates || force, !checking else { return }
        if !force, let last = Settings.lastUpdateCheck, Date().timeIntervalSince(last) < 24 * 3600 { return }
        checking = true
        var request = URLRequest(url: latestURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("BreakReminder/\(Self.currentVersion)", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.checking = false
                Settings.lastUpdateCheck = Date()
                guard let data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let tag = json["tag_name"] as? String
                else { return }
                let latest = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
                Settings.latestKnownVersion = latest
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
        let output = Pipe()
        task.standardOutput = output
        task.standardError = output
        task.terminationHandler = { [weak self] process in
            let text = String(data: output.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                guard let self else { return }
                if process.terminationStatus == 0 || text.contains("already installed") {
                    self.state = .installed(version)
                    self.relaunch()
                } else {
                    NSLog("brew upgrade failed: \(text.suffix(400))")
                    self.state = .failed(version)
                }
            }
        }
        do { try task.run() } catch { state = .failed(version) }
    }

    /// Start the new copy from the opt path, which Homebrew repoints at the new version; it takes over this one.
    private func relaunch() {
        let optApp = URL(fileURLWithPath: (Self.brewPath ?? "/opt/homebrew/bin/brew"))
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("opt/break-reminder/BreakReminder.app")
        let config = NSWorkspace.OpenConfiguration()
        config.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: optApp, configuration: config) { _, error in
            if let error { NSLog("relaunch failed: \(error)") }
        }
    }

    func openReleasePage() { NSWorkspace.shared.open(releasesPage) }
}
