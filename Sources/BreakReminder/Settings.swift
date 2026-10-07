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
        static let showUnit = "showUnit"
    }

    static let defaultReminderTitle = "Time for a break"
    /// {minutes} is the length of the work block, {rest} the rest threshold in minutes.
    static let defaultReminderBody = "You have been working for {minutes} minutes. Step away from the keyboard for {rest} minutes."

    /// Built-in macOS alert sounds, found in /System/Library/Sounds.
    static let availableSounds = [
        "Basso", "Blow", "Bottle", "Frog", "Funk", "Glass", "Hero", "Morse",
        "Ping", "Pop", "Purr", "Sosumi", "Submarine", "Tink",
    ]
    static let defaultSound = "Glass"

    static func registerDefaults() {
        defaults.register(defaults: [
            Key.workLimit: 45,
            Key.restThreshold: 5,
            Key.remindEvery: 10,
            Key.sound: defaultSound,
            Key.warnBefore: 5,
            Key.reminderTitle: defaultReminderTitle,
            Key.reminderBody: defaultReminderBody,
            Key.warnBlink: true,
            Key.outlineStyle: OutlineStyle.unwindFromTop.rawValue,
            Key.showUnit: false,
        ])
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

    /// How the outline around the counter shows the block's progress.
    static var outlineStyle: OutlineStyle {
        get { OutlineStyle(rawValue: defaults.string(forKey: Key.outlineStyle) ?? "") ?? .unwindFromTop }
        set { defaults.set(newValue.rawValue, forKey: Key.outlineStyle) }
    }

    /// Show the unit after the counter in the menu bar ("23m" instead of "23").
    static var showUnit: Bool {
        get { defaults.bool(forKey: Key.showUnit) }
        set { defaults.set(newValue, forKey: Key.showUnit) }
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
        "\(workLimitMinutes)|\(restThresholdMinutes)|\(warnBeforeMinutes)|\(remindEveryMinutes)|\(notificationSound)|\(outlineStyle.rawValue)|\(showUnit)"
    }

    static var workLimit: TimeInterval { TimeInterval(workLimitMinutes * 60) }
    static var warnBefore: TimeInterval { TimeInterval(warnBeforeMinutes * 60) }
    static var restThreshold: TimeInterval { TimeInterval(restThresholdMinutes * 60) }
    static var remindEvery: TimeInterval { TimeInterval(remindEveryMinutes * 60) }
}

/// Outline styles around the menu bar counter. All of them close fully in red past the limit.
enum OutlineStyle: String, CaseIterable, Identifiable {
    case off
    /// Time spent: grows clockwise from the top.
    case fillClockwise
    /// Time left: the gap opens at the top and grows clockwise.
    case unwindFromTop
    /// Time left: the far end retreats counterclockwise toward the top.
    case retreatToTop
    /// Time left: shrinks from both sides toward the bottom.
    case shrinkToBottom

    var id: String { rawValue }

    var label: String {
        switch self {
        case .off: return "Off"
        case .fillClockwise: return "Time spent, fills clockwise"
        case .unwindFromTop: return "Time left, unwinds from the top"
        case .retreatToTop: return "Time left, retreats to the top"
        case .shrinkToBottom: return "Time left, shrinks to the bottom"
        }
    }

    /// Visible stroke range (0 = top center, clockwise to 1) for a block `progress` of 0...1.
    func strokeRange(progress: Double) -> (start: Double, end: Double)? {
        let spent = min(max(progress, 0), 1)
        let left = 1 - spent
        switch self {
        case .off: return nil
        case .fillClockwise: return (0, spent)
        case .unwindFromTop: return (spent, 1)
        case .retreatToTop: return (0, left)
        case .shrinkToBottom: return (0.5 - left / 2, 0.5 + left / 2)
        }
    }
}
