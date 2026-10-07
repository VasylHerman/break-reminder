import Foundation

/// Small on-disk history: one row per day with totals, plus recent "break due" events.
/// Events are kept for 14 days and daily rows for 62 days, so the file never grows past a few KB.
final class History {
    static let shared = History()

    enum Outcome: String, Codable {
        case pending, followed, late, skipped
    }

    struct Event: Codable {
        var dueAt: Date
        var held: Bool              // Smart Pause was holding the reminder when the limit was reached
        var outcome: Outcome
        var restAt: Date?
    }

    struct Day: Codable {
        var work: TimeInterval = 0
        var rest: TimeInterval = 0
        var longestWork: TimeInterval = 0
        var due = 0
        var followed = 0
        var late = 0
        var skipped = 0
        var heldSkipped = 0         // skipped while Smart Pause was holding; not counted against the user

        var taken: Int { followed + late }
        var counted: Int { due - heldSkipped }
        var adherence: Double? {
            counted > 0 ? (Double(followed) + 0.5 * Double(late)) / Double(counted) : nil
        }
    }

    private struct Store: Codable {
        var version = 1
        var days: [String: Day] = [:]
        var events: [Event] = []
    }

    static let followedWithin: TimeInterval = 5 * 60
    static let lateWithin: TimeInterval = 15 * 60
    static let eventRetention: TimeInterval = 14 * 86_400
    static let dayRetention: TimeInterval = 62 * 86_400

    private var store = Store()
    private let fileURL: URL
    private var saveScheduled = false
    private let dayKey: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(fileURL: URL? = nil) {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("BreakReminder", isDirectory: true)
        self.fileURL = fileURL ?? support.appendingPathComponent("history.json")
        load()
    }

    // MARK: Recording

    func recordWork(start: Date, end: Date) {
        let length = max(0, end.timeIntervalSince(start))
        guard length > 0 else { return }
        var day = self.day(for: start)
        day.work += length
        day.longestWork = max(day.longestWork, length)
        setDay(day, for: start)
    }

    func recordRest(start: Date, end: Date) {
        let length = max(0, end.timeIntervalSince(start))
        guard length > 0 else { return }
        var day = self.day(for: start)
        day.rest += length
        setDay(day, for: start)
    }

    /// The work limit was reached. One event per work block.
    func breakDue(at date: Date, held: Bool) {
        store.events.append(Event(dueAt: date, held: held, outcome: .pending, restAt: nil))
        var day = self.day(for: date)
        day.due += 1
        setDay(day, for: date)
        scheduleSave()
    }

    /// A rest started; resolves the pending event if there is one.
    func restStarted(at date: Date) {
        guard let index = store.events.lastIndex(where: { $0.outcome == .pending }) else { return }
        let delay = date.timeIntervalSince(store.events[index].dueAt)
        let outcome: Outcome = delay <= Self.followedWithin ? .followed : (delay <= Self.lateWithin ? .late : .skipped)
        resolve(index: index, outcome: outcome, restAt: date)
    }

    /// Called every tick: a pending event older than the late window is a skip. `reset` forces it.
    func expirePending(now: Date, reset: Bool = false) {
        guard let index = store.events.lastIndex(where: { $0.outcome == .pending }) else { return }
        if reset || now.timeIntervalSince(store.events[index].dueAt) > Self.lateWithin {
            resolve(index: index, outcome: .skipped, restAt: nil)
        }
    }

    private func resolve(index: Int, outcome: Outcome, restAt: Date?) {
        store.events[index].outcome = outcome
        store.events[index].restAt = restAt
        let event = store.events[index]
        var day = self.day(for: event.dueAt)
        switch outcome {
        case .followed: day.followed += 1
        case .late: day.late += 1
        case .skipped:
            day.skipped += 1
            if event.held { day.heldSkipped += 1 }
        case .pending: break
        }
        setDay(day, for: event.dueAt)
        scheduleSave()
    }

    // MARK: Reading

    func day(for date: Date) -> Day {
        store.days[dayKey.string(from: date)] ?? Day()
    }

    /// Days in a date interval, oldest first, including empty ones.
    func days(in interval: DateInterval) -> [(date: Date, day: Day)] {
        var result: [(Date, Day)] = []
        var cursor = Calendar.current.startOfDay(for: interval.start)
        while cursor < interval.end {
            result.append((cursor, day(for: cursor)))
            cursor = Calendar.current.date(byAdding: .day, value: 1, to: cursor)!
        }
        return result
    }

    /// Events since a date, oldest first.
    func events(since: Date) -> [Event] {
        store.events.filter { $0.dueAt >= since }
    }

    /// Consecutive days ending today or yesterday with adherence of 75% or better and at least one counted break.
    func streak(asOf now: Date = Date()) -> Int {
        let calendar = Calendar.current
        var cursor = calendar.startOfDay(for: now)
        var count = 0
        // Today counts if good so far; if today has nothing yet, start from yesterday.
        if day(for: cursor).counted == 0 {
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        while let adherence = day(for: cursor).adherence, adherence >= 0.75 {
            count += 1
            cursor = calendar.date(byAdding: .day, value: -1, to: cursor)!
        }
        return count
    }

    // MARK: Storage

    private func setDay(_ day: Day, for date: Date) {
        store.days[dayKey.string(from: date)] = day
        scheduleSave()
    }

    private func prune(now: Date = Date()) {
        store.events.removeAll { now.timeIntervalSince($0.dueAt) > Self.eventRetention }
        let cutoff = dayKey.string(from: now.addingTimeInterval(-Self.dayRetention))
        store.days = store.days.filter { $0.key >= cutoff }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let loaded = try? decoder.decode(Store.self, from: data) {
            store = loaded
            prune()
        }
    }

    private func scheduleSave() {
        guard !saveScheduled else { return }
        saveScheduled = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.saveScheduled = false
            self?.save()
        }
    }

    func save() {
        prune()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(store) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
