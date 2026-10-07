import AppKit
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let pollInterval: TimeInterval = 5

    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private let notifier = Notifier()
    private var tracker: ActivityTracker!


    private let stateLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let lastWorkLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let lastRestLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
    private let workLimitMenu = NSMenu()
    private let restThresholdMenu = NSMenu()
    private let soundMenu = NSMenu()
    private let warnBeforeMenu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        tracker = ActivityTracker(restThreshold: Settings.restThreshold, pollInterval: Self.pollInterval)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = buildMenu()

        notifier.requestAuthorization()
        tick()

        // .common mode keeps the title updating while the menu is open.
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    // MARK: - Polling

    private func tick() {
        let now = Date()
        let snapshot = tracker.tick(now: now)
        updateStatusItem(snapshot)
        remindIfNeeded(snapshot, now: now)
    }

    private func remindIfNeeded(_ snapshot: ActivityTracker.Snapshot, now: Date) {
        guard snapshot.state == .working, snapshot.currentSeconds >= Settings.workLimit else { return }
        if let last = tracker.lastReminder, now.timeIntervalSince(last) < Settings.remindEvery { return }
        tracker.lastReminder = now

        let minutes = Int(snapshot.currentSeconds / 60)
        notifier.send(
            title: "Time for a break",
            body: "You have been working for \(minutes) minutes. Step away from the keyboard for \(Settings.restThresholdMinutes) minutes.",
            sound: Settings.notificationSound
        )
    }

    // MARK: - Status bar

    private func updateStatusItem(_ snapshot: ActivityTracker.Snapshot) {
        guard let button = statusItem.button else { return }
        let time = Self.format(snapshot.currentSeconds)

        let color: NSColor
        let description: String
        switch snapshot.state {
        case .working where snapshot.currentSeconds >= Settings.workLimit:
            color = .systemRed
            description = "Over work limit"
        case .working where Settings.warnBefore > 0 && snapshot.currentSeconds >= Settings.workLimit - Settings.warnBefore:
            color = .systemYellow
            description = "Break coming up"
        case .working:
            color = .labelColor
            description = "Working"
        case .resting:
            color = .systemGreen
            description = "Resting"
        }

        // Monospaced digits keep the item from jittering as the counter changes.
        let font = NSFont.monospacedDigitSystemFont(ofSize: NSFont.menuBarFont(ofSize: 0).pointSize, weight: .medium)
        button.attributedTitle = NSAttributedString(
            string: time,
            attributes: [.foregroundColor: color, .font: font]
        )
        button.toolTip = "\(description): \(time)"
    }

    static func format(_ seconds: TimeInterval) -> String {
        let total = Int(seconds) / 60
        let hours = total / 60
        let minutes = total % 60
        return hours > 0 ? String(format: "%dh %02dm", hours, minutes) : "\(minutes)m"
    }

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        for line in [stateLine, lastWorkLine, lastRestLine] {
            line.isEnabled = false
            menu.addItem(line)
        }
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Reset Work Timer", action: #selector(resetWork), keyEquivalent: "r"))
        menu.addItem(.separator())

        let workLimitItem = NSMenuItem(title: "Work Limit", action: nil, keyEquivalent: "")
        for minutes in [25, 30, 45, 60, 90] {
            let item = NSMenuItem(title: "\(minutes) minutes", action: #selector(setWorkLimit(_:)), keyEquivalent: "")
            item.tag = minutes
            workLimitMenu.addItem(item)
        }
        workLimitItem.submenu = workLimitMenu
        menu.addItem(workLimitItem)

        let restItem = NSMenuItem(title: "Rest Counts After Idle", action: nil, keyEquivalent: "")
        for minutes in [2, 3, 5, 10] {
            let item = NSMenuItem(title: "\(minutes) minutes", action: #selector(setRestThreshold(_:)), keyEquivalent: "")
            item.tag = minutes
            restThresholdMenu.addItem(item)
        }
        restItem.submenu = restThresholdMenu
        menu.addItem(restItem)

        let warnItem = NSMenuItem(title: "Warn Before Limit", action: nil, keyEquivalent: "")
        let warnOff = NSMenuItem(title: "Off", action: #selector(setWarnBefore(_:)), keyEquivalent: "")
        warnOff.tag = 0
        warnBeforeMenu.addItem(warnOff)
        warnBeforeMenu.addItem(.separator())
        for minutes in [2, 3, 5, 10] {
            let item = NSMenuItem(title: "\(minutes) minutes", action: #selector(setWarnBefore(_:)), keyEquivalent: "")
            item.tag = minutes
            warnBeforeMenu.addItem(item)
        }
        warnItem.submenu = warnBeforeMenu
        menu.addItem(warnItem)

        let soundItem = NSMenuItem(title: "Sound", action: nil, keyEquivalent: "")
        let off = NSMenuItem(title: "Off", action: #selector(setSound(_:)), keyEquivalent: "")
        off.representedObject = ""
        soundMenu.addItem(off)
        soundMenu.addItem(.separator())
        for name in Settings.availableSounds {
            let item = NSMenuItem(title: name, action: #selector(setSound(_:)), keyEquivalent: "")
            item.representedObject = name
            soundMenu.addItem(item)
        }
        soundItem.submenu = soundMenu
        menu.addItem(soundItem)

        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())

        let versionItem = NSMenuItem(title: "Break Reminder \(Self.versionString)", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(versionItem)
        menu.addItem(NSMenuItem(title: "Open on GitHub", action: #selector(openGitHub), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Copy Homebrew Install Command", action: #selector(copyInstallCommand), keyEquivalent: ""))
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Break Reminder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    private static let repositoryURL = URL(string: "https://github.com/VasylHerman/break-reminder")!
    private static let installCommand = "brew install vasylherman/tap/break-reminder"

    private static var versionString: String {
        guard let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else { return "dev" }
        return "v\(short)"
    }

    func menuWillOpen(_ menu: NSMenu) {
        let snapshot = tracker.tick()
        let time = Self.format(snapshot.currentSeconds)
        switch snapshot.state {
        case .working:
            stateLine.title = "Working for \(time) (limit \(Settings.workLimitMinutes)m)"
        case .resting:
            stateLine.title = "Resting for \(time)"
        }
        lastWorkLine.title = "Last work block: " + (snapshot.lastWorkSeconds.map(Self.format) ?? "–")
        lastRestLine.title = "Last rest: " + (snapshot.lastRestSeconds.map(Self.format) ?? "–")

        for item in workLimitMenu.items { item.state = item.tag == Settings.workLimitMinutes ? .on : .off }
        for item in restThresholdMenu.items { item.state = item.tag == Settings.restThresholdMinutes ? .on : .off }
        for item in warnBeforeMenu.items where !item.isSeparatorItem {
            item.state = item.tag == Settings.warnBeforeMinutes ? .on : .off
        }
        for item in soundMenu.items {
            guard let name = item.representedObject as? String else { continue }
            item.state = name == Settings.notificationSound ? .on : .off
        }

        if #available(macOS 13.0, *) {
            launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
            launchAtLoginItem.isEnabled = Bundle.main.bundleIdentifier != nil
        }
    }

    // MARK: - Actions

    @objc private func resetWork() {
        tracker.resetWork()
        tick()
    }

    @objc private func setWorkLimit(_ sender: NSMenuItem) {
        Settings.workLimitMinutes = sender.tag
        tracker.lastReminder = nil
        tick()
    }

    @objc private func setRestThreshold(_ sender: NSMenuItem) {
        Settings.restThresholdMinutes = sender.tag
        tracker.restThreshold = Settings.restThreshold
        tick()
    }

    @objc private func openGitHub() {
        NSWorkspace.shared.open(Self.repositoryURL)
    }

    @objc private func copyInstallCommand() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(Self.installCommand, forType: .string)
    }

    @objc private func setWarnBefore(_ sender: NSMenuItem) {
        Settings.warnBeforeMinutes = sender.tag
        tick()
    }

    @objc private func setSound(_ sender: NSMenuItem) {
        guard let name = sender.representedObject as? String else { return }
        Settings.notificationSound = name
        if !name.isEmpty {
            NSSound(named: NSSound.Name(name))?.play()
        }
    }

    @objc private func toggleLaunchAtLogin() {
        guard #available(macOS 13.0, *) else { return }
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Launch at login toggle failed: \(error)")
        }
    }
}
