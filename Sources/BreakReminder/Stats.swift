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

    static func interval(for period: Period, now: Date = Date(), offset: Int = 0) -> DateInterval {
        let calendar = Calendar.current
        let component: Calendar.Component
        switch period {
        case .day: component = .day
        case .week: component = .weekOfYear
        case .month: component = .month
        }
        let shifted = calendar.date(byAdding: component, value: offset, to: now)!
        return calendar.dateInterval(of: component, for: shifted)!
    }

    /// Previous period, for comparison.
    static func previousSummary(period: Period, history: History, now: Date = Date()) -> Summary {
        var summary = Summary()
        for (_, day) in history.days(in: interval(for: period, now: now, offset: -1)) {
            summary.work += day.work
            summary.rest += day.rest
            summary.longestWork = max(summary.longestWork, day.longestWork)
            summary.due += day.due
            summary.taken += day.taken
            summary.counted += day.counted
            summary.adherencePoints += Double(day.followed) + 0.5 * Double(day.late)
        }
        return summary
    }

    /// One row per day of the period, for the week bars and the month grid.
    struct DayRow: Identifiable {
        let date: Date
        let day: History.Day
        let isToday: Bool
        var id: Date { date }
        var work: TimeInterval { day.work }
    }

    /// Seconds of the live block that fall inside an interval, so a block over midnight counts on both days.
    private static func liveSeconds(_ live: ActivityTracker.Snapshot, in interval: DateInterval) -> TimeInterval {
        let start = live.takenAt.addingTimeInterval(-live.currentSeconds)
        return max(0, min(live.takenAt, interval.end).timeIntervalSince(max(start, interval.start)))
    }

    static func dayRows(period: Period, history: History, live: ActivityTracker.Snapshot?, blockStart: Date?, now: Date = Date()) -> [DayRow] {
        let calendar = Calendar.current
        return history.days(in: interval(for: period, now: now)).map { date, day in
            var day = day
            let isToday = calendar.isDate(date, inSameDayAs: now)
            if isToday, let live {
                let dayInterval = calendar.dateInterval(of: .day, for: date) ?? DateInterval(start: date, duration: 86_400)
                let seconds = liveSeconds(live, in: dayInterval)
                switch live.state {
                case .working:
                    day.work += seconds
                    day.longestWork = max(day.longestWork, seconds)
                case .resting:
                    day.rest += seconds
                }
            }
            return DayRow(date: date, day: day, isToday: isToday)
        }
    }

    /// The one sentence at the top of the Stats pane.
    static func headline(period: Period, summary: Summary, previous: Summary, longestStart: Date?) -> String {
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short
        switch period {
        case .day:
            // Under a minute of work is a touch of the keyboard, not a day: say nothing about it.
            guard summary.work >= 60 || summary.due > 0 else { return "Nothing recorded yet today." }
            var text = "Focused \(TimeFormat.minutes(summary.work))"
            if summary.due > 0 { text += ", \(summary.taken) of \(summary.due) breaks taken" }
            if summary.longestWork >= 60, summary.longestWork < summary.work {
                text += ", longest stretch \(TimeFormat.minutes(summary.longestWork))"
                if let longestStart { text += " at \(timeFormatter.string(from: longestStart))" }
            }
            return text + "."
        case .week, .month:
            let name = period == .week ? "week" : "month"
            guard let adherence = summary.adherence else {
                return summary.work > 0 ? "Focused \(TimeFormat.minutes(summary.work)) so far, no breaks due yet this \(name)." : "Nothing recorded yet this \(name)."
            }
            let percent = Int((adherence * 100).rounded())
            var text = "On time \(percent)% this \(name)"
            if let before = previous.adherence {
                let delta = Int(((adherence - before) * 100).rounded())
                text += delta > 2 ? ", better than last \(name)" : (delta < -2 ? ", below last \(name)" : ", same as last \(name)")
            }
            return text + "."
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
        if let live {
            let seconds = liveSeconds(live, in: interval)
            switch live.state {
            case .working:
                summary.work += seconds
                summary.longestWork = max(summary.longestWork, seconds)
            case .resting:
                summary.rest += seconds
            }
        }
        summary.streak = history.streak(asOf: now)
        return summary
    }
}
