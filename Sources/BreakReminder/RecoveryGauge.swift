import Foundation

/// The arc around the menu bar item as a recovery gauge: it fills with work and unwinds with rest.
///
/// It unwinds from the first idle seconds, before the app knows whether the pause is a rest, at a
/// rate where the rest the block deserves brings it to empty. If input resumes before the idle
/// threshold the block continues and the arc is back at the work level. With carry-over on, rest
/// that was long enough to count but shorter than deserved leaves the arc partly wound, and the
/// next block starts from there.
enum RecoveryGauge {
    /// Idle time below which a pause is not shown as unwinding, to avoid flicker between keystrokes.
    static let idleGrace: TimeInterval = 10

    struct Input {
        var state: ActivityState
        /// Seconds in the current block (work elapsed, or rest elapsed backdated to the last input).
        var currentSeconds: TimeInterval
        var idleSeconds: TimeInterval
        /// Work seconds carried into this block from an unfinished rest.
        var carrySeconds: TimeInterval
        /// Length of the work block that the current rest follows (resting only).
        var lastWorkSeconds: TimeInterval?
        var workLimit: TimeInterval
        var restThreshold: TimeInterval
        var carryOver: Bool
    }

    struct Output {
        /// Arc level as a share of the limit; may exceed 1 past the limit.
        var level: Double
        /// True while the arc is unwinding (idle past the grace, or resting) and not yet empty.
        var unwinding: Bool
        /// Work level, as a share of the limit, that the unwinding started from.
        var workLevel: Double
        /// Share of the deserved rest taken so far, 0...1.
        var recovered: Double
    }

    /// Rest the block deserves: the threshold, or proportional to the work with carry-over on.
    static func restNeeded(forWork work: TimeInterval, input: Input) -> TimeInterval {
        guard input.carryOver, input.workLimit > 0 else { return input.restThreshold }
        return max(input.restThreshold, work * input.restThreshold / input.workLimit)
    }

    static func evaluate(_ input: Input) -> Output {
        let limit = max(input.workLimit, 1)
        switch input.state {
        case .working:
            if input.idleSeconds < idleGrace {
                let level = (input.carrySeconds + input.currentSeconds) / limit
                return Output(level: level, unwinding: false, workLevel: level, recovered: 0)
            }
            // Paused: the work stopped at the last input.
            let work = input.carrySeconds + max(0, input.currentSeconds - input.idleSeconds)
            let needed = restNeeded(forWork: work, input: input)
            let recovered = min(1, input.idleSeconds / max(needed, 1))
            let workLevel = work / limit
            return Output(level: workLevel * (1 - recovered), unwinding: recovered < 1, workLevel: workLevel, recovered: recovered)
        case .resting:
            let work = input.carrySeconds + (input.lastWorkSeconds ?? 0)
            let needed = restNeeded(forWork: work, input: input)
            let recovered = min(1, input.currentSeconds / max(needed, 1))
            let workLevel = work / limit
            return Output(level: workLevel * (1 - recovered), unwinding: recovered < 1, workLevel: workLevel, recovered: recovered)
        }
    }
}
