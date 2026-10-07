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
    private let history = History.shared
    private var dueRecordedFor: Date?
    private var appliedSettings = Settings.signature
    private var smartPauseReason: SmartPauseReason?
    private var smartPauseEndedAt: Date?

    private let stateLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let lastWorkLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let lastRestLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let pausedLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let breaksLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let firmnessLine = NSMenuItem(title: "", action: nil, keyEquivalent: "")
    private let resumeItem = NSMenuItem(title: "Resume Reminders", action: #selector(resumeReminders), keyEquivalent: "")
    private let workLimitMenu = NSMenu()
    private let restThresholdMenu = NSMenu()

    func applicationDidFinishLaunching(_ notification: Notification) {
        Settings.registerDefaults()
        tracker = ActivityTracker(restThreshold: Settings.restThreshold, pollInterval: Self.pollInterval)
        tracker.onBlockEnded = { [weak self] state, start, end in
            guard let self else { return }
            switch state {
            case .working:
                self.history.recordWork(start: start, end: end)
            case .resting:
                self.history.recordRest(start: start, end: end)
            }
            if state == .working {
                // A rest begins where the work block ended.
                self.history.restStarted(at: end)
            }
        }
        Feedback.snapshotProvider = { [weak self] in self?.lastSnapshot }
        Feedback.blockStartProvider = { [weak self] in self?.tracker.currentBlockStart }
        notifier.onPauseToday = { [weak self] in self?.pauseUntilTomorrow() }
        notifier.onOpenSettings = { [weak self] in self?.openSettings() }

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

        // Heartbeat scheduler: checks ten times a second whether the next beat is due.
        let blinkTimer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in self?.blinkIfDue() }
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
        updateSmartPause(now: now)
        evaluateFirmnessIfDue(now: now)
        updateStatusItem(snapshot)
        recordDueIfNeeded(snapshot, now: now)
        remindIfNeeded(snapshot, now: now)
    }

    /// Once a day: earn the automatic level from the last 7 days, once at least 5 breaks were due.
    private func evaluateFirmnessIfDue(now: Date) {
        let today = Self.dayKey(now)
        guard Settings.autoFirmnessDay != today else { return }
        Settings.autoFirmnessDay = today
        let rolling = FirmnessPolicy.rollingScore(history: history, now: now)
        guard rolling.counted >= FirmnessPolicy.minimumBreaks else { return }
        let earned = FirmnessPolicy.level(forScore: rolling.score)
        Settings.autoFirmness = earned.level
        Settings.autoSteppedDown = earned.steppedDown
        if earned.steppedDown, Settings.firmnessMode == .automatic, Settings.steppedDownCardDay != today {
            Settings.steppedDownCardDay = today
            notifier.sendSteppedDownCard()
        }
    }

    private static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Logs one "break due" event per work block when the limit is reached, and expires stale ones.
    private func recordDueIfNeeded(_ snapshot: ActivityTracker.Snapshot, now: Date) {
        history.expirePending(now: now)
        guard snapshot.state == .working, snapshot.currentSeconds >= Settings.workLimit else { return }
        let blockStart = tracker.currentBlockStart
        if dueRecordedFor != blockStart {
            dueRecordedFor = blockStart
            history.breakDue(at: now, held: smartPauseReason != nil)
        }
    }

    private func updateSmartPause(now: Date) {
        let reason = SmartPause.activeReason()
        if smartPauseReason != nil, reason == nil {
            smartPauseEndedAt = now
        }
        smartPauseReason = reason
    }

    /// Reminders and the blink are held while a Smart Pause is active and for the grace period after it.
    private var remindersHeld: Bool {
        if Settings.remindersPausedUntil != nil || smartPauseReason != nil { return true }
        if let ended = smartPauseEndedAt, Date().timeIntervalSince(ended) < Settings.smartPauseGrace { return true }
        return false
    }

    private func remindIfNeeded(_ snapshot: ActivityTracker.Snapshot, now: Date) {
        guard snapshot.state == .working, snapshot.currentSeconds >= Settings.workLimit else { return }
        if remindersHeld { return }
        if let last = tracker.lastReminder {
            // Repeats depend on the firmness level; Gentle sends one reminder per block.
            guard let interval = Settings.firmness.repeatInterval(normal: Settings.remindEvery),
                  now.timeIntervalSince(last) >= interval
            else { return }
        }
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

    /// Seconds between beats from the heart rate for the current phase, nil when the heart is still.
    /// In the warning the rate climbs from the normal rate to the warning rate as the limit nears.
    private func blinkPeriod(now: Date) -> TimeInterval? {
        guard Settings.warnBlink, Settings.firmness.allowsBlink,
              let snapshot = lastSnapshot, snapshot.state == .working,
              !remindersHeld
        else { return nil }
        let elapsed = snapshot.currentSeconds + now.timeIntervalSince(snapshot.takenAt)
        let remaining = Settings.workLimit - elapsed
        let bpm: Double
        if remaining <= 0 {
            bpm = Double(Settings.beatOverBPM)
        } else if Settings.warnBefore > 0, remaining <= Settings.warnBefore {
            let into = 1 - remaining / Settings.warnBefore       // 0 at the start of the warning, 1 at the limit
            bpm = Double(Settings.beatNormalBPM) + (Double(Settings.beatWarningBPM) - Double(Settings.beatNormalBPM)) * into
        } else if Settings.beatWhileWorking {
            bpm = Double(Settings.beatNormalBPM)
        } else {
            return nil
        }
        return 60 / max(bpm, 1)
    }

    private func blinkIfDue() {
        let now = Date()
        guard let period = blinkPeriod(now: now), now.timeIntervalSince(lastBlink) >= period - 0.05 else { return }
        lastBlink = now
        guard let button = statusItem.button, let buttonLayer = button.layer else { return }
        // Heart mode beats only the chosen parts; the other modes beat the whole item.
        var layers: [CALayer] = [buttonLayer]
        if Settings.counterStyle == .heart, let border = progressBorder {
            layers = []
            if Settings.beatBody { layers.append(border.bodyLayer) }
            if Settings.beatLevel { layers.append(border.levelLayer) }
            if Settings.beatArc { layers.append(border.ringLayer) }
        }
        Self.beat(layers, period: period)
    }

    /// One heartbeat: a strong pulse, a lighter one, then rest. The keyframes span 0.55 s and are
    /// compressed to fit faster rates. The outline layer is a sublayer, so it beats too.
    static let beatTimes: [Double] = [0, 0.09, 0.18, 0.27, 0.36, 0.45, 0.55]
    static let beatValues: [Double] = [1, 0.3, 1, 1, 0.55, 1, 1]

    static func beat(_ layers: [CALayer], period: TimeInterval) {
        guard !layers.isEmpty else { return }
        let duration = min(beatTimes.last!, period * 0.85)
        let scale = duration / beatTimes.last!
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            // Reduce Motion: the same rhythm as plain steps, no interpolation.
            for (time, value) in zip(beatTimes, beatValues) {
                DispatchQueue.main.asyncAfter(deadline: .now() + time * scale) {
                    CATransaction.begin()
                    CATransaction.setDisableActions(true)
                    layers.forEach { $0.opacity = Float(value) }
                    CATransaction.commit()
                }
            }
            return
        }
        let animation = CAKeyframeAnimation(keyPath: "opacity")
        animation.duration = duration
        animation.keyTimes = beatTimes.map { NSNumber(value: $0 / beatTimes.last!) }
        animation.values = beatValues
        animation.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: beatValues.count - 1)
        layers.forEach { $0.add(animation, forKey: "beat") }
    }

    // MARK: - Status bar

    private func updateStatusItem(_ snapshot: ActivityTracker.Snapshot) {
        guard let button = statusItem.button else { return }
        let counterStyle = Settings.counterStyle
        let time = TimeFormat.counter(snapshot.currentSeconds, showUnit: counterStyle == .numberWithUnit)

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
        let borderColor = theme.outlineColor(
            for: phase,
            highContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast,
            glyph: Settings.counterStyle.isGlyph
        )

        var tooltip = "\(description): \(TimeFormat.minutes(snapshot.currentSeconds))"

        // Weekly score: a heart beside the counter, or the counter itself.
        let week = Stats.summary(period: .week, history: history, live: snapshot, blockStart: tracker.currentBlockStart)
        if let adherence = week.adherence {
            tooltip += "\nOn time this week: \(Int((adherence * 100).rounded()))%"
        }
        var heart: NSImage?
        if Settings.showScore, counterStyle != .heart, let adherence = week.adherence {
            heart = ScoreHeart.image(fill: adherence, color: color)
        }
        button.toolTip = tooltip
        button.imagePosition = .imageLeading

        if counterStyle == .heart {
            // The heart is the item: a gauge of the weekly score, like the battery icon is a gauge.
            // Body and level are separate layers over an empty canvas so each part can beat on its own.
            button.attributedTitle = NSAttributedString(string: "")
            button.image = ScoreHeart.emptyCanvas(22)
            progressBorder?.ringDiameter = 21
            progressBorder?.glyphCanvas = 22
            progressBorder?.setGlyph(
                body: ScoreHeart.canvas(fill: week.adherence ?? 0, color: .labelColor, canvas: 22, parts: .body),
                level: ScoreHeart.canvas(fill: week.adherence ?? 0, color: .labelColor, canvas: 22, parts: .level)
            )
            // The ring stays in the neutral tone in every state; the blink carries the warning.
            let progress: Double? = snapshot.state == .working ? snapshot.currentSeconds / Settings.workLimit : nil
            let ringColor = theme.outlineColor(for: .working, highContrast: NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast, glyph: true)
            progressBorder?.update(progress: progress, style: Settings.outlineStyle, color: ringColor)
            return
        } else if counterStyle == .hidden {
            // Dot in the state color, with the outline drawn as a ring around it.
            progressBorder?.setGlyph(body: nil, level: nil)
            button.attributedTitle = NSAttributedString(string: "")
            progressBorder?.ringDiameter = 16
            progressBorder?.glyphCanvas = 18
            let dot = Self.dotImage(color: (phase == .working ? NSColor.labelColor : borderColor)
                                        .withAlphaComponent(ScoreHeart.levelOpacity))
            button.image = heart.map { ScoreHeart.compose(heart: $0, with: dot) } ?? dot
        } else {
            progressBorder?.setGlyph(body: nil, level: nil)
            button.image = heart
            button.attributedTitle = NSAttributedString(
                string: time,
                attributes: [.foregroundColor: color, .font: Self.counterFont]
            )
        }

        // Outline around the counter (or ring around the dot) shows the block's progress; hidden while resting.
        let progress: Double? = snapshot.state == .working ? snapshot.currentSeconds / Settings.workLimit : nil
        progressBorder?.update(progress: progress, style: Settings.outlineStyle, color: borderColor)
    }

    /// A 7 pt filled circle on a canvas the size of the ring, so the status item is wide enough for both.
    /// Dynamic colors resolve when the image is drawn, so it follows the menu bar appearance.
    private static func dotImage(color: NSColor) -> NSImage {
        let canvas: CGFloat = 18
        let image = NSImage(size: NSSize(width: canvas, height: canvas), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: (canvas - 7) / 2, dy: (canvas - 7) / 2)).fill()
            return true
        }
        image.isTemplate = false
        return image
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

        for line in [stateLine, lastWorkLine, lastRestLine, breaksLine, firmnessLine, pausedLine] {
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
        menu.addItem(NSMenuItem(title: "Stats…", action: #selector(openStats), keyEquivalent: "s"))
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
        let week = Stats.summary(period: .week, history: history, live: snapshot, blockStart: tracker.currentBlockStart)
        breaksLine.title = week.due > 0 ? "Breaks this week: \(week.taken) of \(week.due)" : "No breaks due yet this week"
        firmnessLine.title = Self.firmnessDescription()

        if let until = Settings.remindersPausedUntil {
            let formatter = DateFormatter()
            formatter.dateStyle = Calendar.current.isDateInToday(until) ? .none : .short
            formatter.timeStyle = .short
            formatter.doesRelativeDateFormatting = true
            pausedLine.title = "Reminders paused until \(formatter.string(from: until))"
            pausedLine.isHidden = false
            resumeItem.isHidden = false
        } else if let reason = smartPauseReason {
            pausedLine.title = "Reminders held: \(reason.rawValue)"
            pausedLine.isHidden = false
            resumeItem.isHidden = true
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

    /// "Firmness: Gentle, earned" / "Firmness: Firm, locked".
    static func firmnessDescription() -> String {
        let level = Settings.firmness
        switch Settings.firmnessMode {
        case .automatic:
            let how = Settings.autoSteppedDown ? "stepped down" : (Settings.autoFirmnessDay == nil ? "starting level" : "earned")
            return "Firmness: \(level.label), \(how)"
        default:
            return "Firmness: \(level.label), locked"
        }
    }

    // MARK: - Actions

    @objc private func resetWork() {
        history.expirePending(now: Date(), reset: true)
        tracker.resetWork()
        tick()
    }

    @objc private func openStats() {
        settingsWindow.show(pane: .stats)
    }

    func applicationWillTerminate(_ notification: Notification) {
        history.save()
    }

    @objc private func openSettings() {
        settingsWindow.show(pane: .general)
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
