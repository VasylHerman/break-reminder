import XCTest
@testable import BreakReminder

final class LogicTests: XCTestCase {
    func testVersionComparison() {
        XCTAssertTrue(Updater.isNewer("0.22.1", than: "0.22.0"))
        XCTAssertTrue(Updater.isNewer("0.10.0", than: "0.9.9"))
        XCTAssertFalse(Updater.isNewer("0.22.0", than: "0.22.0"))
        XCTAssertFalse(Updater.isNewer("0.21.9", than: "0.22.0"))
    }

    func testGaugeUnwindsAndEmpties() {
        func input(_ state: ActivityState, current: TimeInterval, idle: TimeInterval = 0) -> RecoveryGauge.Input {
            .init(state: state, currentSeconds: current, idleSeconds: idle, carrySeconds: 0, lastWorkSeconds: 1500,
                  workLimit: 1500, restThreshold: 300, carryOver: false)
        }
        XCTAssertEqual(RecoveryGauge.evaluate(input(.working, current: 750)).level, 0.5, accuracy: 0.001)
        let half = RecoveryGauge.evaluate(input(.resting, current: 150))
        XCTAssertEqual(half.level, 0.5, accuracy: 0.001)
        XCTAssertTrue(half.unwinding)
        XCTAssertFalse(RecoveryGauge.evaluate(input(.resting, current: 300)).unwinding)
    }

    func testFirmnessLevels() {
        XCTAssertEqual(FirmnessPolicy.level(forScore: 0.95).level, .gentle)
        XCTAssertEqual(FirmnessPolicy.level(forScore: 0.6).level, .normal)
        XCTAssertEqual(FirmnessPolicy.level(forScore: 0.2).level, .firm)
        XCTAssertTrue(FirmnessPolicy.level(forScore: 0.05).steppedDown)
    }

    private func tempHistory() -> (History, URL) {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("history-\(UUID().uuidString).json")
        return (History(fileURL: url), url)
    }

    func testBreakDueIsOncePerBlockAndFollowedWithinFiveMinutes() {
        let (history, _) = tempHistory()
        let start = Date()
        history.breakDue(at: start, held: false, blockStart: start.addingTimeInterval(-1500))
        history.breakDue(at: start.addingTimeInterval(5), held: false, blockStart: start.addingTimeInterval(-1500))
        XCTAssertEqual(history.day(for: start).due, 1)
        history.restStarted(at: start.addingTimeInterval(120))
        XCTAssertEqual(history.day(for: start).followed, 1)
    }

    func testWorkAcrossMidnightIsSplit() {
        let (history, _) = tempHistory()
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: Date())
        history.recordWork(start: midnight.addingTimeInterval(-600), end: midnight.addingTimeInterval(900))
        XCTAssertEqual(history.day(for: midnight.addingTimeInterval(-1)).work, 600, accuracy: 0.5)
        XCTAssertEqual(history.day(for: midnight).work, 900, accuracy: 0.5)
    }

    func testUnreadableHistoryIsKeptNotOverwritten() throws {
        let (_, url) = tempHistory()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let history = History(fileURL: url)
        history.save()
        let backup = url.deletingLastPathComponent().appendingPathComponent("history.corrupt.json")
        XCTAssertEqual(try String(contentsOf: backup, encoding: .utf8), "not json")
        try? FileManager.default.removeItem(at: backup)
    }
}

final class HeartStyleTests: XCTestCase {
    func testFadingLevelIsDarkAtFullScoreAndGrayAtNone() {
        XCTAssertEqual(ScoreHeart.levelAlpha(fill: 1, style: .fades), ScoreHeart.levelOpacity, accuracy: 0.001)
        XCTAssertEqual(ScoreHeart.levelAlpha(fill: 0, style: .fades), ScoreHeart.fadedLevelOpacity, accuracy: 0.001)
        XCTAssertEqual(ScoreHeart.levelAlpha(fill: 0.3, style: .rises), ScoreHeart.levelOpacity, accuracy: 0.001)
    }
}
