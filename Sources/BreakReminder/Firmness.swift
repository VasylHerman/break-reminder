import Foundation

/// How insistent the reminders are. Automatic mode earns calm from the weekly score.
enum Firmness: String, CaseIterable, Identifiable {
    case gentle, normal, firm

    var id: String { rawValue }

    var label: String {
        switch self {
        case .gentle: return "Gentle"
        case .normal: return "Normal"
        case .firm: return "Firm"
        }
    }

    var summary: String {
        switch self {
        case .gentle: return "One reminder per block, no repeats. The heart keeps its calm beat but never speeds up."
        case .normal: return "Repeats on your interval, blinks in the warning."
        case .firm: return "Repeats every 5 minutes, blinks in the warning."
        }
    }

    /// Seconds between repeated reminders, nil for no repeats.
    func repeatInterval(normal: TimeInterval) -> TimeInterval? {
        switch self {
        case .gentle: return nil
        case .normal: return normal
        case .firm: return min(5 * 60, normal)
        }
    }

    /// Gentle keeps the calm resting beat; only the warning ramp and the fast over-limit beat are its to lose.
    var allowsWarningBeat: Bool { self != .gentle }
}

/// The user's choice: a fixed level, or automatic.
enum FirmnessMode: String, CaseIterable, Identifiable {
    case automatic, gentle, normal, firm
    var id: String { rawValue }
    var label: String {
        switch self {
        case .automatic: return "Automatic"
        case .gentle: return Firmness.gentle.label
        case .normal: return Firmness.normal.label
        case .firm: return Firmness.firm.label
        }
    }
    var fixed: Firmness? {
        switch self {
        case .automatic: return nil
        case .gentle: return .gentle
        case .normal: return .normal
        case .firm: return .firm
        }
    }
}

enum FirmnessPolicy {
    static let minimumBreaks = 5
    static let window = 7

    /// Level earned by a score. Below 15% the app steps down and asks instead of nagging.
    static func level(forScore score: Double) -> (level: Firmness, steppedDown: Bool) {
        switch score {
        case 0.9...: return (.gentle, false)
        case 0.4..<0.9: return (.normal, false)
        case 0.15..<0.4: return (.firm, false)
        default: return (.gentle, true)
        }
    }

    /// Score over the last `window` days ending today, with the number of counted breaks.
    static func rollingScore(history: History, now: Date = Date()) -> (score: Double, counted: Int) {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: now)!)
        let start = calendar.date(byAdding: .day, value: -window, to: end)!
        var points = 0.0
        var counted = 0
        for (_, day) in history.days(in: DateInterval(start: start, end: end)) {
            points += Double(day.followed) + 0.5 * Double(day.late)
            counted += day.counted
        }
        return (counted > 0 ? points / Double(counted) : 0, counted)
    }
}
