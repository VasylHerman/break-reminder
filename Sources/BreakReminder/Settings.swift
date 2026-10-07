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
        "\(workLimitMinutes)|\(restThresholdMinutes)|\(warnBeforeMinutes)|\(remindEveryMinutes)|\(notificationSound)"
    }

    static var workLimit: TimeInterval { TimeInterval(workLimitMinutes * 60) }
    static var warnBefore: TimeInterval { TimeInterval(warnBeforeMinutes * 60) }
    static var restThreshold: TimeInterval { TimeInterval(restThresholdMinutes * 60) }
    static var remindEvery: TimeInterval { TimeInterval(remindEveryMinutes * 60) }
}
