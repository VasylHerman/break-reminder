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
        static let warnBlink = "warnBlink"
        static let outlineStyle = "outlineStyle"
        static let showUnit = "showUnit"          // 0.9 to 0.10, migrated into counterStyle
        static let counterStyle = "counterStyle"
        static let showScore = "showScore"
        static let theme = "theme"
        static let smartPauseEnabled = "smartPauseEnabled"
        static let smartPauseCall = "smartPauseCall"
        static let smartPauseScreenShare = "smartPauseScreenShare"
        static let smartPauseFullscreen = "smartPauseFullscreen"
        static let smartPauseGrace = "smartPauseGraceMinutes"
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
            Key.reminderTitle: defaultReminderTitle,
            Key.reminderBody: defaultReminderBody,
            Key.warnBlink: true,
            Key.outlineStyle: OutlineStyle.spentClockwise.rawValue,
            Key.counterStyle: CounterStyle.heart.rawValue,
            Key.showScore: false,
            Key.theme: Theme.quiet.rawValue,
            Key.smartPauseEnabled: true,
            Key.smartPauseCall: true,
            Key.smartPauseScreenShare: true,
            Key.smartPauseFullscreen: false,
            Key.smartPauseGrace: 2,
            Key.firmnessMode: FirmnessMode.automatic.rawValue,
            Key.autoFirmness: Firmness.normal.rawValue,
        ])
    }

    /// Removes every user setting so the registered defaults apply again. Timer state is untouched.
    static func resetAll() {
        for key in [Key.workLimit, Key.restThreshold, Key.remindEvery, Key.sound, Key.warnBefore,
                    Key.pausedUntil, Key.reminderTitle, Key.reminderBody, Key.warnBlink,
                    Key.outlineStyle, Key.showUnit, Key.counterStyle, Key.showScore, Key.theme, Key.smartPauseEnabled, Key.smartPauseCall,
                    Key.smartPauseScreenShare, Key.smartPauseFullscreen, Key.smartPauseGrace,
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

    static var reminderTitle: String {
        get { defaults.string(forKey: Key.reminderTitle) ?? defaultReminderTitle }
        set { defaults.set(newValue, forKey: Key.reminderTitle) }
    }

    static var reminderBody: String {
        get { defaults.string(forKey: Key.reminderBody) ?? defaultReminderBody }
        set { defaults.set(newValue, forKey: Key.reminderBody) }
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
        "\(workLimitMinutes)|\(restThresholdMinutes)|\(warnBeforeMinutes)|\(remindEveryMinutes)|\(notificationSound)|\(outlineStyle.rawValue)|\(counterStyle.rawValue)|\(showScore)|\(theme.rawValue)|\(firmnessMode.rawValue)"
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
    func stroke(progress: Double) -> (anchor: Anchor, start: Double, end: Double)? {
        let spent = min(max(progress, 0), 1)
        let left = 1 - spent
        switch self {
        case .off: return nil
        case .spentClockwise: return (.top, 0, spent)
        case .spentCounterclockwise: return (.top, 1 - spent, 1)
        case .spentFromBottom: return (.top, 0.5 - spent / 2, 0.5 + spent / 2)
        case .spentFromTop: return (.bottom, 0.5 - spent / 2, 0.5 + spent / 2)
        case .leftClockwise: return (.top, spent, 1)
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

    /// Migrates names from 0.9.0.
    init(stored: String?) {
        switch stored {
        case "fillClockwise": self = .spentClockwise
        case "unwindFromTop": self = .leftClockwise
        case "retreatToTop": self = .leftCounterclockwise
        case "shrinkToBottom": self = .leftToBottom
        default: self = OutlineStyle(rawValue: stored ?? "") ?? .spentClockwise
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
