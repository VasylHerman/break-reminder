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

    /// One finished work or rest block. Kept for two days, for the day timeline only.
    struct Block: Codable {
        var kind: ActivityState
        var start: Date
        var end: Date
    }

    private struct Store: Codable {
        var version = 1
        var days: [String: Day] = [:]
        var events: [Event] = []
        var blocks: [Block] = []

        init() {}

        // Older files have no "blocks"; decode what is there.
        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
            days = try c.decodeIfPresent([String: Day].self, forKey: .days) ?? [:]
            events = try c.decodeIfPresent([Event].self, forKey: .events) ?? []
            blocks = try c.decodeIfPresent([Block].self, forKey: .blocks) ?? []
        }
    }

    static let followedWithin: TimeInterval = 5 * 60
    static let lateWithin: TimeInterval = 15 * 60
    static let eventRetention: TimeInterval = 14 * 86_400
    static let dayRetention: TimeInterval = 62 * 86_400
    static let blockRetention: TimeInterval = 2 * 86_400

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
        store.blocks.append(Block(kind: .working, start: start, end: end))
    }

    func recordRest(start: Date, end: Date) {
        let length = max(0, end.timeIntervalSince(start))
        guard length > 0 else { return }
        var day = self.day(for: start)
        day.rest += length
        setDay(day, for: start)
        store.blocks.append(Block(kind: .resting, start: start, end: end))
    }

    /// Two dues closer than this are the same block seen twice (a relaunch); the later one is dropped.
    static let minimumDueGap: TimeInterval = 20 * 60

    /// The work limit was reached. One event per work block, even across relaunches.
    func breakDue(at date: Date, held: Bool) {
        if let last = store.events.last, date.timeIntervalSince(last.dueAt) < Self.minimumDueGap { return }
        store.events.append(Event(dueAt: date, held: held, outcome: .pending, restAt: nil))
        var day = self.day(for: date)
        day.due += 1
        setDay(day, for: date)
        scheduleSave()
    }

    /// A rest started; resolves every pending event by its own delay.
    func restStarted(at date: Date) {
        for index in store.events.indices where store.events[index].outcome == .pending {
            let delay = date.timeIntervalSince(store.events[index].dueAt)
            let outcome: Outcome = delay <= Self.followedWithin ? .followed : (delay <= Self.lateWithin ? .late : .skipped)
            resolve(index: index, outcome: outcome, restAt: date)
        }
    }

    /// Merges duplicate dues left by earlier versions and recomputes the day counters from the events.
    func repairDuplicates() {
        var kept: [Event] = []
        for event in store.events.sorted(by: { $0.dueAt < $1.dueAt }) {
            if let last = kept.last, event.dueAt.timeIntervalSince(last.dueAt) < Self.minimumDueGap {
                // Same block: keep the better outcome.
                let rank: [Outcome: Int] = [.followed: 3, .late: 2, .pending: 1, .skipped: 0]
                if (rank[event.outcome] ?? 0) > (rank[last.outcome] ?? 0) { kept[kept.count - 1] = event }
                continue
            }
            kept.append(event)
        }
        guard kept.count != store.events.count else { return }
        store.events = kept
        // Recount the days the events cover.
        var touched = Set<String>()
        for event in kept { touched.insert(dayKey.string(from: event.dueAt)) }
        for key in touched {
            guard var day = store.days[key] else { continue }
            let events = kept.filter { dayKey.string(from: $0.dueAt) == key }
            day.due = events.count
            day.followed = events.filter { $0.outcome == .followed }.count
            day.late = events.filter { $0.outcome == .late }.count
            day.skipped = events.filter { $0.outcome == .skipped }.count
            day.heldSkipped = events.filter { $0.outcome == .skipped && $0.held }.count
            store.days[key] = day
        }
        save()
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

    /// Events due within a date interval.
    func events(in interval: DateInterval) -> [Event] {
        store.events.filter { interval.contains($0.dueAt) }
    }

    /// Finished blocks overlapping a date interval, oldest first.
    func blocks(in interval: DateInterval) -> [Block] {
        store.blocks.filter { $0.end > interval.start && $0.start < interval.end }
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
        store.blocks.removeAll { now.timeIntervalSince($0.end) > Self.blockRetention }
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
