import AppKit
import CoreText

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private static let pollInterval: TimeInterval = 5

    private var statusItem: NSStatusItem!
    private var timer: Timer?
    private var blinkTimer: Timer?
    private var lastBlink = Date.distantPast
    private let notifier = Notifier.shared
    private var tracker: ActivityTracker!
    private var progressBorder: ProgressBorder?
    private var lastSnapshot: ActivityTracker.Snapshot?
    private lazy var settingsWindow = SettingsWindowController()
    private var appliedSettings = Settings.signature

    private let stateLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let lastWorkLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let lastRestLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pausedLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let resumeItem = NSMenuItem(title: "Resume Reminders", action: #selector(resumeReminders), keyEquivalent: "")
    private let workLimitMenu = NSMenu()
    private let restThresholdMenu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        tracker = ActivityTracker(restThreshold: Settings.restThreshold, pollInterval: Self.pollInterval)
        Feedback.snapshotProvider = { [weak self] in self?.lastSnapshot }

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.menu = buildMenu()
        if let button = statusItem.button {
            progressBorder = ProgressBorder(button: button)
        }

        notifier.requestAuthorization()
        tick()

        // .common mode keeps the title updating while the menu is open.
        let timer = Timer(timeInterval: Self.pollInterval, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer

        // Blink scheduler: checks every second whether the warning effect is due.
        let blinkTimer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in self?.blinkIfDue() }
        RunLoop.main.add(blinkTimer, forMode: .common)
        self.blinkTimer = blinkTimer

        // Settings changed in the window apply immediately.
        NotificationCenter.default.addObserver(
            self, selector: #selector(settingsChanged), name: UserDefaults.didChangeNotification, object: nil
        )

        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(settingsChanged),
            name: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification, object: nil
        )

        // `open BreakReminder.app --args --settings` opens the window at launch; handy for development.
        if CommandLine.arguments.contains("--settings") {
            openSettings()
        }
    }

    // MARK: - Polling

    private func tick() {
        let now = Date()
        let snapshot = tracker.tick(now: now)
        lastSnapshot = snapshot
        updateStatusItem(snapshot)
        remindIfNeeded(snapshot, now: now)
    }

    private func remindIfNeeded(_ snapshot: ActivityTracker.Snapshot, now: Date) {
        guard snapshot.state == .working, snapshot.currentSeconds >= Settings.workLimit else { return }
        if Settings.remindersPausedUntil != nil { return }
        if let last = tracker.lastReminder, now.timeIntervalSince(last) < Settings.remindEvery { return }
        tracker.lastReminder = now

        notifier.sendBreakReminder(minutes: Int(snapshot.currentSeconds / 60))
    }

    /// UserDefaults also changes on every tracker persist, so only react when a setting really changed.
    @objc private func settingsChanged(_ note: Notification) {
        guard tracker != nil else { return }
        let accessibility = note.name == NSWorkspace.accessibilityDisplayOptionsDidChangeNotification
        guard accessibility || Settings.signature != appliedSettings else { return }
        appliedSettings = Settings.signature
        tracker.restThreshold = Settings.restThreshold
        tick()
    }

    // MARK: - Warning blink

    /// Seconds between blinks: the number of minutes left before the limit (5m left -> every 5s),
    /// 1s at and past the limit. Nil when no blink is due.
    private func blinkPeriod(now: Date) -> TimeInterval? {
        guard Settings.warnBlink, Settings.warnBefore > 0,
              !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion,
              let snapshot = lastSnapshot, snapshot.state == .working,
              Settings.remindersPausedUntil == nil
        else { return nil }
        let elapsed = snapshot.currentSeconds + now.timeIntervalSince(snapshot.takenAt)
        let remaining = Settings.workLimit - elapsed
        guard remaining <= Settings.warnBefore else { return nil }
        return max(1, ceil(remaining / 60))
    }

    private func blinkIfDue() {
        let now = Date()
        guard let period = blinkPeriod(now: now), now.timeIntervalSince(lastBlink) >= period - 0.1 else { return }
        lastBlink = now
        guard let button = statusItem.button else { return }
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            button.animator().alphaValue = 0.25
        }, completionHandler: {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                button.animator().alphaValue = 1
            }
        })
    }

    // MARK: - Status bar

    private func updateStatusItem(_ snapshot: ActivityTracker.Snapshot) {
        guard let button = statusItem.button else { return }
        let time = TimeFormat.counter(snapshot.currentSeconds, showUnit: Settings.showUnit)

        let phase: CounterPhase
        let description: String
        switch snapshot.state {
        case .working where snapshot.currentSeconds >= Settings.workLimit:
            phase = .over
            description = "Over work limit"
        case .working where Settings.warnBefore > 0 && snapshot.currentSeconds >= Settings.workLimit - Settings.warnBefore:
            phase = .warning
            description = "Break coming up"
        case .working:
            phase = .working
            description = "Working"
        case .resting:
            phase = .resting
            description = "Resting"
        }
        let theme = Settings.theme
        let color = theme.textColor(for: phase)
        let borderColor = theme.outlineColor(for: phase, highContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast)

        button.attributedTitle = NSAttributedString(
            string: time,
            attributes: [.foregroundColor: color, .font: Self.counterFont]
        )
        button.toolTip = "\(description): \(time)"

        // Outline around the counter shows the block's progress; hidden while resting.
        let progress: Double? = snapshot.state == .working ? snapshot.currentSeconds / Settings.workLimit : nil
        progressBorder?.update(progress: progress, style: Settings.outlineStyle, color: borderColor)
    }

    /// The regular menu bar font, same as the clock, with monospaced digits so the item does not jitter.
    private static let counterFont: NSFont = {
        let base = NSFont.menuBarFont(ofSize: 0)
        let descriptor = base.fontDescriptor.addingAttributes([
            .featureSettings: [[
                NSFontDescriptor.FeatureKey.typeIdentifier: kNumberSpacingType,
                NSFontDescriptor.FeatureKey.selectorIdentifier: kMonospacedNumbersSelector,
            ]],
        ])
        return NSFont(descriptor: descriptor, size: base.pointSize) ?? base
    }()

    // MARK: - Menu

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self

        for line in [stateLine, lastWorkLine, lastRestLine, pausedLine] {
            line.isEnabled = false
            menu.addItem(line)
        }
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Reset Work Timer", action: #selector(resetWork), keyEquivalent: "r"))

        let pauseMenu = NSMenu()
        for (title, minutes) in [("30 Minutes", 30), ("1 Hour", 60), ("2 Hours", 120)] {
            let item = NSMenuItem(title: title, action: #selector(pauseReminders(_:)), keyEquivalent: "")
            item.tag = minutes
            pauseMenu.addItem(item)
        }
        pauseMenu.addItem(NSMenuItem(title: "Until Tomorrow", action: #selector(pauseUntilTomorrow), keyEquivalent: ""))
        let pauseItem = NSMenuItem(title: "Pause Reminders", action: nil, keyEquivalent: "")
        pauseItem.submenu = pauseMenu
        menu.addItem(pauseItem)
        menu.addItem(resumeItem)
        menu.addItem(.separator())

        for minutes in [25, 30, 45, 60, 90] {
            let item = NSMenuItem(title: "\(minutes) minutes", action: #selector(setWorkLimit(_:)), keyEquivalent: "")
            item.tag = minutes
            workLimitMenu.addItem(item)
        }
        workLimitMenu.addItem(.separator())
        workLimitMenu.addItem(NSMenuItem(title: "Custom…", action: #selector(openSettings), keyEquivalent: ""))
        let workLimitItem = NSMenuItem(title: "Work Limit", action: nil, keyEquivalent: "")
        workLimitItem.submenu = workLimitMenu
        menu.addItem(workLimitItem)

        for minutes in [2, 3, 5, 10] {
            let item = NSMenuItem(title: "\(minutes) minutes", action: #selector(setRestThreshold(_:)), keyEquivalent: "")
            item.tag = minutes
            restThresholdMenu.addItem(item)
        }
        restThresholdMenu.addItem(.separator())
        restThresholdMenu.addItem(NSMenuItem(title: "Custom…", action: #selector(openSettings), keyEquivalent: ""))
        let restItem = NSMenuItem(title: "Rest Counts After Idle", action: nil, keyEquivalent: "")
        restItem.submenu = restThresholdMenu
        menu.addItem(restItem)
        menu.addItem(.separator())

        // Own group: macOS decorates "Settings…" with an icon and would indent its neighbours.
        menu.addItem(NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())

        let feedbackMenu = NSMenu()
        feedbackMenu.addItem(NSMenuItem(title: "Request a Feature…", action: #selector(requestFeature), keyEquivalent: ""))
        feedbackMenu.addItem(NSMenuItem(title: "Report a Bug…", action: #selector(reportBug), keyEquivalent: ""))
        feedbackMenu.addItem(.separator())
        feedbackMenu.addItem(NSMenuItem(title: "Release Notes", action: #selector(openReleaseNotes), keyEquivalent: ""))
        feedbackMenu.addItem(NSMenuItem(title: "Star on GitHub", action: #selector(openGitHub), keyEquivalent: ""))
        feedbackMenu.addItem(NSMenuItem(title: "Project on GitHub", action: #selector(openGitHub), keyEquivalent: ""))
        let feedbackItem = NSMenuItem(title: "Feedback", action: nil, keyEquivalent: "")
        feedbackItem.submenu = feedbackMenu
        menu.addItem(feedbackItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "Quit Break Reminder", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        return menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        let snapshot = tracker.tick()
        lastSnapshot = snapshot
        let time = TimeFormat.minutes(snapshot.currentSeconds)
        switch snapshot.state {
        case .working:
            stateLine.title = "Working for \(time) (limit \(Settings.workLimitMinutes)m)"
        case .resting:
            stateLine.title = "Resting for \(time)"
        }
        lastWorkLine.title = "Last work block: " + (snapshot.lastWorkSeconds.map(TimeFormat.minutes) ?? "–")
        lastRestLine.title = "Last rest: " + (snapshot.lastRestSeconds.map(TimeFormat.minutes) ?? "–")

        if let until = Settings.remindersPausedUntil {
            let formatter = DateFormatter()
            formatter.dateStyle = Calendar.current.isDateInToday(until) ? .none : .short
            formatter.timeStyle = .short
            formatter.doesRelativeDateFormatting = true
            pausedLine.title = "Reminders paused until \(formatter.string(from: until))"
            pausedLine.isHidden = false
            resumeItem.isHidden = false
        } else {
            pausedLine.isHidden = true
            resumeItem.isHidden = true
        }

        for item in workLimitMenu.items where !item.isSeparatorItem {
            item.state = item.tag == Settings.workLimitMinutes ? .on : .off
        }
        for item in restThresholdMenu.items where !item.isSeparatorItem {
            item.state = item.tag == Settings.restThresholdMinutes ? .on : .off
        }
    }

    // MARK: - Actions

    @objc private func resetWork() {
        tracker.resetWork()
        tick()
    }

    @objc private func openSettings() {
        settingsWindow.show()
    }

    @objc private func setWorkLimit(_ sender: NSMenuItem) {
        Settings.workLimitMinutes = sender.tag
    }

    @objc private func setRestThreshold(_ sender: NSMenuItem) {
        Settings.restThresholdMinutes = sender.tag
    }

    @objc private func pauseReminders(_ sender: NSMenuItem) {
        Settings.remindersPausedUntil = Date().addingTimeInterval(TimeInterval(sender.tag * 60))
    }

    @objc private func pauseUntilTomorrow() {
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        Settings.remindersPausedUntil = Calendar.current.startOfDay(for: tomorrow)
    }

    @objc private func resumeReminders() {
        Settings.remindersPausedUntil = nil
    }

    @objc private func openGitHub() { Feedback.openRepository() }
    @objc private func openReleaseNotes() { Feedback.openReleaseNotes() }
    @objc private func requestFeature() { Feedback.requestFeature() }
    @objc private func reportBug() { Feedback.reportBug() }
}
