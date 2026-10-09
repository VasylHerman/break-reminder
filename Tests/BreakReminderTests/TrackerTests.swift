import XCTest
@testable import BreakReminder

final class TrackerTests: XCTestCase {
    private var idle: TimeInterval = 0
    private var defaults: UserDefaults!
    private var ended: [(ActivityState, Date, Date)] = []

    override func setUp() {
        defaults = UserDefaults(suiteName: "BreakReminderTests-\(UUID().uuidString)")!
        idle = 0
        ended = []
    }

    private func makeTracker(now: Date) -> ActivityTracker {
        let tracker = ActivityTracker(
            restThreshold: 300, pollInterval: 5, now: now, defaults: defaults, idle: { [unowned self] in self.idle }
        )
        tracker.onBlockEnded = { [unowned self] in self.ended.append(($0, $1, $2)) }
        return tracker
    }

    func testRestBeginsAtLastInputNotAtDetection() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let tracker = makeTracker(now: t0)
        tracker.tick(now: t0.addingTimeInterval(60))
        idle = 310
        let snap = tracker.tick(now: t0.addingTimeInterval(370))
        XCTAssertEqual(snap.state, .resting)
        XCTAssertEqual(ended.first?.0, .working)
        XCTAssertEqual(ended.first?.2, t0.addingTimeInterval(60))
    }

    func testSleepGapEndsTheWorkBlockAtTheLastTick() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let tracker = makeTracker(now: t0)
        tracker.tick(now: t0.addingTimeInterval(600))
        // The Mac sleeps for eight hours; the idle clock did not run, so input after wake reads as recent.
        idle = 1
        let wake = t0.addingTimeInterval(600 + 8 * 3600)
        let snap = tracker.tick(now: wake)
        XCTAssertEqual(snap.state, .working)
        XCTAssertLessThan(snap.currentSeconds, 10)
        XCTAssertEqual(ended.first?.0, .working)
        XCTAssertEqual(ended.first?.2, t0.addingTimeInterval(600))
        XCTAssertEqual(ended.last?.0, .resting)
    }

    func testShortGapKeepsTheBlock() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let tracker = makeTracker(now: t0)
        tracker.tick(now: t0.addingTimeInterval(60))
        let snap = tracker.tick(now: t0.addingTimeInterval(120))
        XCTAssertEqual(snap.state, .working)
        XCTAssertEqual(snap.currentSeconds, 120, accuracy: 1)
        XCTAssertTrue(ended.isEmpty)
    }

    func testResetDuringRestRecordsTheRest() {
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        idle = 400
        let tracker = makeTracker(now: t0)
        XCTAssertEqual(tracker.state, .resting)
        tracker.resetWork(now: t0.addingTimeInterval(120))
        XCTAssertEqual(ended.first?.0, .resting)
        XCTAssertEqual(tracker.state, .working)
    }
}
