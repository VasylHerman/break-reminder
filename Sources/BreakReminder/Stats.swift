import Foundation

/// Aggregates history rows into the numbers the Stats window and the menu show.
enum Stats {
    enum Period: String, CaseIterable, Identifiable {
        case day, week, month
        var id: String { rawValue }
        var label: String {
            switch self {
            case .day: return "Day"
            case .week: return "Week"
            case .month: return "Month"
            }
        }
    }

    struct Summary {
        var work: TimeInterval = 0
        var rest: TimeInterval = 0
        var longestWork: TimeInterval = 0
        var due = 0
        var taken = 0
        var counted = 0
        var adherencePoints = 0.0
        var goodDays = 0
        var activeDays = 0
        var streak = 0

        var adherence: Double? { counted > 0 ? adherencePoints / Double(counted) : nil }
    }

    static func interval(for period: Period, now: Date = Date()) -> DateInterval {
        let calendar = Calendar.current
        switch period {
        case .day:
            return calendar.dateInterval(of: .day, for: now)!
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: now)!
        case .month:
            return calendar.dateInterval(of: .month, for: now)!
        }
    }

    /// Totals for a period. The current block is added live so "today" never lags behind the menu bar.
    static func summary(
        period: Period,
        history: History,
        live: ActivityTracker.Snapshot?,
        blockStart: Date?,
        now: Date = Date()
    ) -> Summary {
        var summary = Summary()
        let interval = interval(for: period, now: now)
        for (_, day) in history.days(in: interval) {
            summary.work += day.work
            summary.rest += day.rest
            summary.longestWork = max(summary.longestWork, day.longestWork)
            summary.due += day.due
            summary.taken += day.taken
            summary.counted += day.counted
            summary.adherencePoints += Double(day.followed) + 0.5 * Double(day.late)
            if day.work > 0 || day.due > 0 { summary.activeDays += 1 }
            if let adherence = day.adherence, adherence >= 0.75 { summary.goodDays += 1 }
        }
        if let live, let blockStart, interval.contains(blockStart) {
            switch live.state {
            case .working:
                summary.work += live.currentSeconds
                summary.longestWork = max(summary.longestWork, live.currentSeconds)
            case .resting:
                summary.rest += live.currentSeconds
            }
        }
        summary.streak = history.streak(asOf: now)
        return summary
    }
}
