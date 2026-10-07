import CoreGraphics
import Foundation

enum ActivityState {
    case working
    case resting
}

/// Tracks continuous work and rest periods using the system-wide input idle time.
///
/// The idle time comes from CoreGraphics (`secondsSinceLastEventType`) and covers keyboard,
/// mouse and trackpad events from every app. No Accessibility or Input Monitoring permission
/// is required, and no individual key or pointer events are observed.
final class ActivityTracker {
    struct Snapshot {
        let state: ActivityState
        /// Seconds spent in the current state.
        let currentSeconds: TimeInterval
        /// Length of the most recently completed work block.
        let lastWorkSeconds: TimeInterval?
        /// Length of the most recently completed rest.
        let lastRestSeconds: TimeInterval?
        /// Raw system idle time at the moment of the snapshot.
        let idleSeconds: TimeInterval
    }

    /// Idle time at or above which the user is considered resting.
    var restThreshold: TimeInterval

    /// Idle time below which the user is considered actively working again.
    /// Kept slightly above the poll interval so a single poll does not miss a return.
    private let activeWindow: TimeInterval

    private(set) var state: ActivityState = .resting
    private var stateStart: Date
    private var lastWorkSeconds: TimeInterval?
    private var lastRestSeconds: TimeInterval?

    init(restThreshold: TimeInterval, pollInterval: TimeInterval) {
        self.restThreshold = restThreshold
        self.activeWindow = pollInterval * 2
        let idle = Self.systemIdleSeconds()
        self.stateStart = Date().addingTimeInterval(-idle)
        self.state = idle >= restThreshold ? .resting : .working
    }

    static func systemIdleSeconds() -> TimeInterval {
        // ~0 is kCGAnyInputEventType: any keyboard, mouse, trackpad or tablet event.
        let anyInput = CGEventType(rawValue: ~0)!
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: anyInput)
    }

    /// Restart the current work block from now.
    func resetWork(now: Date = Date()) {
        state = .working
        stateStart = now
    }

    @discardableResult
    func tick(now: Date = Date()) -> Snapshot {
        let idle = Self.systemIdleSeconds()

        switch state {
        case .working:
            if idle >= restThreshold {
                // The rest actually began at the last input event, not when we noticed it.
                let restStart = now.addingTimeInterval(-idle)
                lastWorkSeconds = max(0, restStart.timeIntervalSince(stateStart))
                state = .resting
                stateStart = restStart
            }
        case .resting:
            if idle < activeWindow {
                let workStart = now.addingTimeInterval(-idle)
                lastRestSeconds = max(0, workStart.timeIntervalSince(stateStart))
                state = .working
                stateStart = workStart
            }
        }

        return Snapshot(
            state: state,
            currentSeconds: max(0, now.timeIntervalSince(stateStart)),
            lastWorkSeconds: lastWorkSeconds,
            lastRestSeconds: lastRestSeconds,
            idleSeconds: idle
        )
    }
}
