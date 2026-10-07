import Foundation

/// User-tunable values, persisted in UserDefaults.
enum Settings {
    private static let defaults = UserDefaults.standard

    enum Key {
        static let workLimit = "workLimitMinutes"
        static let restThreshold = "restThresholdMinutes"
        static let remindEvery = "remindEveryMinutes"
        static let sound = "notificationSound"
        static let warnBefore = "warnBeforeMinutes"
        static let pausedUntil = "remindersPausedUntil"
        static let reminderTitle = "reminderTitle"
        static let reminderBody = "reminderBody"
        static let reminderStyle = "reminderStyle"           // "activities" or "custom"
        static let activityCategories = "activityCategories"
        static let customActivities = "customActivities"
        static let recentActivities = "recentActivities"
        static let activityWhy = "activityWhy"
        static let warnBlink = "warnBlink"
        static let carryOverRest = "carryOverRest"
        static let carrySeconds = "carrySeconds"
        static let beatNormal = "beatNormalBPM"
        static let beatWarning = "beatWarningBPM"
        static let beatOver = "beatOverBPM"
        static let beatWhileWorking = "beatWhileWorking"
        static let beatBody = "beatBody"
        static let beatLevel = "beatLevel"
        static let beatArc = "beatArc"
        static let outlineStyle = "outlineStyle"
        static let outlineSpan = "outlineSpanPercent"
        static let showUnit = "showUnit"          // 0.9 to 0.10, migrated into counterStyle
        static let counterStyle = "counterStyle"
        static let showScore = "showScore"
        static let theme = "theme"
        static let smartPauseEnabled = "smartPauseEnabled"
        static let smartPauseCall = "smartPauseCall"
        static let smartPauseScreenShare = "smartPauseScreenShare"
        static let smartPauseFullscreen = "smartPauseFullscreen"
        static let smartPauseGrace = "smartPauseGraceMinutes"
        static let checkForUpdates = "checkForUpdates"
        static let autoInstallUpdates = "autoInstallUpdates"
        static let lastUpdateCheck = "lastUpdateCheck"
        static let latestKnownVersion = "latestKnownVersion"
        static let firmnessMode = "firmnessMode"
        static let autoFirmness = "autoFirmness"
        static let autoFirmnessDay = "autoFirmnessDay"
        static let autoSteppedDown = "autoSteppedDown"
        static let steppedDownCardDay = "steppedDownCardDay"
    }

    static let defaultReminderTitle = "Time for a break"
    /// {minutes} is the length of the work block, {rest} the rest threshold in minutes.
    static let defaultReminderBody = "You have been working for {minutes} minutes. Step away from the keyboard for {rest} minutes."

    /// Built-in macOS alert sounds, found in /System/Library/Sounds.
    static let availableSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse",
        "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]
    static let defaultSound = "Submarine"

    static func registerDefaults() {
        defaults.register(defaults: [
            Key.workLimit: 25,
            Key.restThreshold: 5,
            Key.remindEvery: 10,
            Key.sound: defaultSound,
            Key.warnBefore: 5,
            Key.reminderTitle: "",
            Key.reminderBody: defaultReminderBody,
            Key.reminderStyle: "activities",
            Key.activityCategories: BreakActivities.Category.allCases.map(\.rawValue),
            Key.customActivities: [String](),
            Key.activityWhy: true,
            Key.warnBlink: true,
            Key.carryOverRest: false,
            Key.beatNormal: 10,
            Key.beatWarning: 40,
            Key.beatOver: 80,
            Key.beatWhileWorking: true,
            Key.beatBody: true,
            Key.beatLevel: false,
            Key.beatArc: false,
            Key.outlineStyle: OutlineStyle.spentFromBottom.rawValue,
            Key.outlineSpan: 50,
            Key.counterStyle: CounterStyle.heart.rawValue,
            Key.showScore: false,
            Key.theme: Theme.quiet.rawValue,
            Key.smartPauseEnabled: true,
            Key.smartPauseCall: true,
            Key.smartPauseScreenShare: true,
            Key.smartPauseFullscreen: false,
            Key.smartPauseGrace: 2,
            Key.checkForUpdates: true,
            Key.autoInstallUpdates: true,
            Key.firmnessMode: FirmnessMode.automatic.rawValue,
            Key.autoFirmness: Firmness.normal.rawValue,
        ])
    }

    /// Removes every user setting so the registered defaults apply again. Timer state is untouched.
    static func resetAll() {
        for key in [Key.workLimit, Key.restThreshold, Key.remindEvery, Key.sound, Key.warnBefore,
                    Key.pausedUntil, Key.reminderTitle, Key.reminderBody, Key.reminderStyle,
                    Key.activityCategories, Key.customActivities, Key.recentActivities, Key.activityWhy, Key.warnBlink,
                    Key.carryOverRest, Key.carrySeconds,
                    Key.beatNormal, Key.beatWarning, Key.beatOver, Key.beatWhileWorking,
                    Key.beatBody, Key.beatLevel, Key.beatArc,
                    Key.outlineStyle, Key.outlineSpan, Key.showUnit, Key.counterStyle, Key.showScore, Key.theme, Key.smartPauseEnabled, Key.smartPauseCall,
                    Key.smartPauseScreenShare, Key.smartPauseFullscreen, Key.smartPauseGrace,
                    Key.checkForUpdates, Key.autoInstallUpdates, Key.lastUpdateCheck, Key.latestKnownVersion,
                    Key.firmnessMode, Key.autoFirmness, Key.autoFirmnessDay, Key.autoSteppedDown,
                    Key.steppedDownCardDay] {
            defaults.removeObject(forKey: key)
        }
    }

    /// Continuous work after which the first reminder fires.
    static var workLimitMinutes: Int {
        get { max(1, defaults.integer(forKey: Key.workLimit)) }
        set { defaults.set(newValue, forKey: Key.workLimit) }
    }

    /// How long input must be idle before it counts as a rest (and the work counter resets).
    static var restThresholdMinutes: Int {
        get { max(1, defaults.integer(forKey: Key.restThreshold)) }
        set { defaults.set(newValue, forKey: Key.restThreshold) }
    }

    /// Interval between repeated reminders while the user keeps working past the limit.
    static var remindEveryMinutes: Int {
        get { max(1, defaults.integer(forKey: Key.remindEvery)) }
        set { defaults.set(newValue, forKey: Key.remindEvery) }
    }

    /// Minutes before the work limit at which the counter turns yellow. 0 disables the warning.
    static var warnBeforeMinutes: Int {
        get { max(0, defaults.integer(forKey: Key.warnBefore)) }
        set { defaults.set(newValue, forKey: Key.warnBefore) }
    }

    /// With activities this is an optional prefix before the activity; with own text it is the title.
    static var reminderTitle: String {
        get { defaults.string(forKey: Key.reminderTitle) ?? "" }
        set { defaults.set(newValue, forKey: Key.reminderTitle) }
    }

    static var reminderBody: String {
        get { defaults.string(forKey: Key.reminderBody) ?? defaultReminderBody }
        set { defaults.set(newValue, forKey: Key.reminderBody) }
    }

    /// True when reminders suggest an activity; false for the user's own title and message.
    static var suggestsActivities: Bool {
        get { (defaults.string(forKey: Key.reminderStyle) ?? "activities") == "activities" }
        set { defaults.set(newValue ? "activities" : "custom", forKey: Key.reminderStyle) }
    }
    static var activityCategories: Set<BreakActivities.Category> {
        get { Set((defaults.stringArray(forKey: Key.activityCategories) ?? []).compactMap(BreakActivities.Category.init)) }
        set { defaults.set(newValue.map(\.rawValue).sorted(), forKey: Key.activityCategories) }
    }
    /// The user's own activity lines, one per element.
    static var customActivities: [String] {
        get { defaults.stringArray(forKey: Key.customActivities) ?? [] }
        set { defaults.set(newValue, forKey: Key.customActivities) }
    }
    /// Add the one-line reason after the activity.
    static var activityWhy: Bool {
        get { defaults.bool(forKey: Key.activityWhy) }
        set { defaults.set(newValue, forKey: Key.activityWhy) }
    }

    /// Titles of the last two activities, so the same one is not suggested twice in a row.
    static var recentActivities: [String] {
        get { defaults.stringArray(forKey: Key.recentActivities) ?? [] }
        set { defaults.set(Array(newValue.suffix(2)), forKey: Key.recentActivities) }
    }

    /// Reminders are silenced until this date. Nil or past means active.
    static var remindersPausedUntil: Date? {
        get {
            guard let date = defaults.object(forKey: Key.pausedUntil) as? Date, date > Date() else { return nil }
            return date
        }
        set { defaults.set(newValue, forKey: Key.pausedUntil) }
    }

    // Smart Pause master switch and triggers.
    static var smartPauseEnabled: Bool {
        get { defaults.bool(forKey: Key.smartPauseEnabled) }
        set { defaults.set(newValue, forKey: Key.smartPauseEnabled) }
    }
    static var smartPauseCall: Bool {
        get { defaults.bool(forKey: Key.smartPauseCall) }
        set { defaults.set(newValue, forKey: Key.smartPauseCall) }
    }
    static var smartPauseScreenShare: Bool {
        get { defaults.bool(forKey: Key.smartPauseScreenShare) }
        set { defaults.set(newValue, forKey: Key.smartPauseScreenShare) }
    }
    static var smartPauseFullscreen: Bool {
        get { defaults.bool(forKey: Key.smartPauseFullscreen) }
        set { defaults.set(newValue, forKey: Key.smartPauseFullscreen) }
    }
    /// Minutes to wait after a Smart Pause ends before an overdue reminder fires.
    static var smartPauseGraceMinutes: Int {
        get { max(0, defaults.integer(forKey: Key.smartPauseGrace)) }
        set { defaults.set(newValue, forKey: Key.smartPauseGrace) }
    }
    static var smartPauseGrace: TimeInterval { TimeInterval(smartPauseGraceMinutes * 60) }

    // Updates.
    static var checkForUpdates: Bool {
        get { defaults.bool(forKey: Key.checkForUpdates) }
        set { defaults.set(newValue, forKey: Key.checkForUpdates) }
    }
    /// Install a newer version through Homebrew at the next rest, without asking.
    static var autoInstallUpdates: Bool {
        get { defaults.bool(forKey: Key.autoInstallUpdates) }
        set { defaults.set(newValue, forKey: Key.autoInstallUpdates) }
    }
    static var lastUpdateCheck: Date? {
        get { defaults.object(forKey: Key.lastUpdateCheck) as? Date }
        set { defaults.set(newValue, forKey: Key.lastUpdateCheck) }
    }
    static var latestKnownVersion: String? {
        get { defaults.string(forKey: Key.latestKnownVersion) }
        set { defaults.set(newValue, forKey: Key.latestKnownVersion) }
    }

    // Firmness.
    static var firmnessMode: FirmnessMode {
        get { FirmnessMode(rawValue: defaults.string(forKey: Key.firmnessMode) ?? "") ?? .automatic }
        set { defaults.set(newValue.rawValue, forKey: Key.firmnessMode) }
    }
    /// Level earned by the automatic mode at the last daily evaluation.
    static var autoFirmness: Firmness {
        get { Firmness(rawValue: defaults.string(forKey: Key.autoFirmness) ?? "") ?? .normal }
        set { defaults.set(newValue.rawValue, forKey: Key.autoFirmness) }
    }
    /// Day key ("yyyy-MM-dd") of the last automatic evaluation.
    static var autoFirmnessDay: String? {
        get { defaults.string(forKey: Key.autoFirmnessDay) }
        set { defaults.set(newValue, forKey: Key.autoFirmnessDay) }
    }
    /// True when the last evaluation stepped down to Gentle because reminders were being ignored.
    static var autoSteppedDown: Bool {
        get { defaults.bool(forKey: Key.autoSteppedDown) }
        set { defaults.set(newValue, forKey: Key.autoSteppedDown) }
    }
    static var steppedDownCardDay: String? {
        get { defaults.string(forKey: Key.steppedDownCardDay) }
        set { defaults.set(newValue, forKey: Key.steppedDownCardDay) }
    }
    /// The level in force right now.
    static var firmness: Firmness { firmnessMode.fixed ?? autoFirmness }

    static var theme: Theme {
        get { Theme(rawValue: defaults.string(forKey: Key.theme) ?? "") ?? .quiet }
        set { defaults.set(newValue.rawValue, forKey: Key.theme) }
    }

    /// Share of the outline that represents a whole block, in percent. 50 means a finished block
    /// fills half the ring. Adjustable with `defaults write dev.vasyl.BreakReminder outlineSpanPercent -int 75`.
    static var outlineSpanPercent: Int {
        get { min(100, max(10, defaults.integer(forKey: Key.outlineSpan))) }
        set { defaults.set(newValue, forKey: Key.outlineSpan) }
    }
    static var outlineSpan: Double { Double(outlineSpanPercent) / 100 }

    /// How the outline around the counter shows the block's progress.
    static var outlineStyle: OutlineStyle {
        get { OutlineStyle(stored: defaults.string(forKey: Key.outlineStyle)) }
        set { defaults.set(newValue.rawValue, forKey: Key.outlineStyle) }
    }

    /// Show a heart filled to the week's on-time score next to the counter.
    static var showScore: Bool {
        get { defaults.bool(forKey: Key.showScore) }
        set { defaults.set(newValue, forKey: Key.showScore) }
    }

    /// What the menu bar item shows: the number with or without a unit, or only a dot.
    static var counterStyle: CounterStyle {
        get {
            if let raw = defaults.string(forKey: Key.counterStyle), let style = CounterStyle(rawValue: raw) { return style }
            // Pre-0.11 installs chose a number style through the unit toggle; keep that choice.
            if defaults.object(forKey: Key.showUnit) != nil {
                return defaults.bool(forKey: Key.showUnit) ? .numberWithUnit : .number
            }
            return .heart
        }
        set { defaults.set(newValue.rawValue, forKey: Key.counterStyle) }
    }

    /// Carry unfinished rest into the next block: the arc starts from what was not recovered.
    static var carryOverRest: Bool {
        get { defaults.bool(forKey: Key.carryOverRest) }
        set { defaults.set(newValue, forKey: Key.carryOverRest) }
    }
    /// Work seconds left on the gauge when the last rest ended.
    static var carrySeconds: TimeInterval {
        get { carryOverRest ? max(0, defaults.double(forKey: Key.carrySeconds)) : 0 }
        set { defaults.set(newValue, forKey: Key.carrySeconds) }
    }

    // Heartbeat rates, beats per minute. Adjustable with
    // `defaults write dev.vasyl.BreakReminder beatWarningBPM -int 120` and friends.
    static var beatNormalBPM: Int {
        get { min(200, max(5, defaults.integer(forKey: Key.beatNormal))) }
        set { defaults.set(newValue, forKey: Key.beatNormal) }
    }
    static var beatWarningBPM: Int {
        get { min(200, max(5, defaults.integer(forKey: Key.beatWarning))) }
        set { defaults.set(newValue, forKey: Key.beatWarning) }
    }
    static var beatOverBPM: Int {
        get { min(200, max(5, defaults.integer(forKey: Key.beatOver))) }
        set { defaults.set(newValue, forKey: Key.beatOver) }
    }
    // Which parts of the heart item beat.
    static var beatBody: Bool {
        get { defaults.bool(forKey: Key.beatBody) }
        set { defaults.set(newValue, forKey: Key.beatBody) }
    }
    static var beatLevel: Bool {
        get { defaults.bool(forKey: Key.beatLevel) }
        set { defaults.set(newValue, forKey: Key.beatLevel) }
    }
    static var beatArc: Bool {
        get { defaults.bool(forKey: Key.beatArc) }
        set { defaults.set(newValue, forKey: Key.beatArc) }
    }

    /// Beat at the normal rate while working, not only in the warning.
    static var beatWhileWorking: Bool {
        get { defaults.bool(forKey: Key.beatWhileWorking) }
        set { defaults.set(newValue, forKey: Key.beatWhileWorking) }
    }

    /// Blink the menu bar counter during the warning window and past the limit.
    static var warnBlink: Bool {
        get { defaults.bool(forKey: Key.warnBlink) }
        set { defaults.set(newValue, forKey: Key.warnBlink) }
    }

    /// Name of the alert sound played with each reminder. Empty string means silent.
    static var notificationSound: String {
        get { defaults.string(forKey: Key.sound) ?? defaultSound }
        set { defaults.set(newValue, forKey: Key.sound) }
    }

    /// Cheap fingerprint of every user setting, used to detect real changes.
    static var signature: String {
        "\(workLimitMinutes)|\(restThresholdMinutes)|\(warnBeforeMinutes)|\(remindEveryMinutes)|\(notificationSound)|\(beatNormalBPM)|\(beatWarningBPM)|\(beatOverBPM)|\(beatWhileWorking)|\(carryOverRest)|\(beatBody)|\(beatLevel)|\(beatArc)|\(outlineStyle.rawValue)|\(outlineSpanPercent)|\(counterStyle.rawValue)|\(showScore)|\(theme.rawValue)|\(firmnessMode.rawValue)"
    }

    static var workLimit: TimeInterval { TimeInterval(workLimitMinutes * 60) }
    static var warnBefore: TimeInterval { TimeInterval(warnBeforeMinutes * 60) }
    static var restThreshold: TimeInterval { TimeInterval(restThresholdMinutes * 60) }
    static var remindEvery: TimeInterval { TimeInterval(remindEveryMinutes * 60) }
}

/// Outline styles around the menu bar counter. All of them close fully in red past the limit.
enum OutlineStyle: String, CaseIterable, Identifiable {
    case off
    // Time spent: the outline grows.
    case spentClockwise          // from the top, clockwise
    case spentCounterclockwise   // from the top, counterclockwise
    case spentFromBottom         // from the bottom, both sides toward the top
    case spentFromTop            // from the top, both sides toward the bottom
    // Time left: the outline shrinks.
    case leftClockwise           // the gap opens at the top and grows clockwise
    case leftCounterclockwise    // the gap opens at the top and grows counterclockwise
    case leftToBottom            // shrinks from both sides toward the bottom
    case leftToTop               // shrinks from both sides toward the top

    var id: String { rawValue }

    /// Where the stroke path starts; the range below is measured clockwise from here.
    enum Anchor { case top, bottom }

    var label: String {
        switch self {
        case .off: return "Off"
        case .spentClockwise: return "Time spent, grows clockwise"
        case .spentCounterclockwise: return "Time spent, grows counterclockwise"
        case .spentFromBottom: return "Time spent, grows from the bottom"
        case .spentFromTop: return "Time spent, grows from the top"
        case .leftClockwise: return "Time left, unwinds clockwise"
        case .leftCounterclockwise: return "Time left, unwinds counterclockwise"
        case .leftToBottom: return "Time left, shrinks to the bottom"
        case .leftToTop: return "Time left, shrinks to the top"
        }
    }

    var isTimeLeft: Bool {
        switch self {
        case .leftClockwise, .leftCounterclockwise, .leftToBottom, .leftToTop: return true
        default: return false
        }
    }

    /// Visible stroke range (0...1 clockwise from the anchor) for a block `progress` of 0...1.
    /// `span` is the share of the outline a whole block covers, 1 for the full ring.
    func stroke(progress: Double, span: Double = Settings.outlineSpan) -> (anchor: Anchor, start: Double, end: Double)? {
        let spent = min(max(progress, 0), 1) * span
        let left = span - spent
        switch self {
        case .off: return nil
        case .spentClockwise: return (.top, 0, spent)
        case .spentCounterclockwise: return (.top, 1 - spent, 1)
        case .spentFromBottom: return (.top, 0.5 - spent / 2, 0.5 + spent / 2)
        case .spentFromTop: return (.bottom, 0.5 - spent / 2, 0.5 + spent / 2)
        case .leftClockwise: return (.top, spent, span)
        case .leftCounterclockwise: return (.top, 0, left)
        case .leftToBottom: return (.top, 0.5 - left / 2, 0.5 + left / 2)
        case .leftToTop: return (.bottom, 0.5 - left / 2, 0.5 + left / 2)
        }
    }

    enum Mode: String, CaseIterable, Identifiable {
        case left, spent, off
        var id: String { rawValue }
        var label: String {
            switch self {
            case .left: return "Time left"
            case .spent: return "Time spent"
            case .off: return "Off"
            }
        }
    }

    enum Direction: String, CaseIterable, Identifiable {
        case clockwise, counterclockwise, bottom, top
        var id: String { rawValue }
        var label: String {
            switch self {
            case .clockwise: return "Clockwise"
            case .counterclockwise: return "Counterclockwise"
            case .bottom: return "From the bottom"
            case .top: return "From the top"
            }
        }
    }

    var mode: Mode {
        if self == .off { return .off }
        return isTimeLeft ? .left : .spent
    }

    var direction: Direction {
        switch self {
        case .spentClockwise, .leftClockwise: return .clockwise
        case .spentCounterclockwise, .leftCounterclockwise: return .counterclockwise
        case .spentFromBottom, .leftToBottom: return .bottom
        case .spentFromTop, .leftToTop, .off: return .top
        }
    }

    static func make(mode: Mode, direction: Direction) -> OutlineStyle {
        switch (mode, direction) {
        case (.off, _): return .off
        case (.spent, .clockwise): return .spentClockwise
        case (.spent, .counterclockwise): return .spentCounterclockwise
        case (.spent, .bottom): return .spentFromBottom
        case (.spent, .top): return .spentFromTop
        case (.left, .clockwise): return .leftClockwise
        case (.left, .counterclockwise): return .leftCounterclockwise
        case (.left, .bottom): return .leftToBottom
        case (.left, .top): return .leftToTop
        }
    }

    /// The arc shown past the limit: the whole covered span, never more. For the time-left styles,
    /// which are empty at the limit, the full span is shown so "over" stays visible.
    func overStroke(span: Double = Settings.outlineSpan) -> (anchor: Anchor, start: Double, end: Double)? {
        stroke(progress: isTimeLeft ? 0 : 1, span: span)
    }

    /// Migrates names from 0.9.0.
    init(stored: String?) {
        switch stored {
        case "fillClockwise": self = .spentClockwise
        case "unwindFromTop": self = .leftClockwise
        case "retreatToTop": self = .leftCounterclockwise
        case "shrinkToBottom": self = .leftToBottom
        default: self = OutlineStyle(rawValue: stored ?? "") ?? .spentFromBottom
        }
    }
}

/// What the menu bar item shows.
enum CounterStyle: String, CaseIterable, Identifiable {
    case numberWithUnit, number, hidden, heart
    var id: String { rawValue }
    var label: String {
        switch self {
        case .numberWithUnit: return "Minutes with unit"
        case .number: return "Minutes"
        case .hidden: return "Dot"
        case .heart: return "Heart"
        }
    }
    /// Glyph-only modes: no digits, the outline becomes a ring.
    var isGlyph: Bool { self == .hidden || self == .heart }
}
