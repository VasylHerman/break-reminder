import AppKit
import CoreAudio
import CoreMediaIO
import Foundation

/// Why reminders are being held automatically.
enum SmartPauseReason: String {
    case call = "camera or microphone in use"
    case screenShare = "screen sharing"
    case fullscreen = "fullscreen app in front"

    /// Headline cue for the reminder that was held: "Call over · Walk a little".
    var endedCue: String {
        switch self {
        case .call: return "Call over"
        case .screenShare: return "Sharing over"
        case .fullscreen: return "Back from full screen"
        }
    }
}

/// Detects situations in which a reminder would be unwelcome. Every check reads system state
/// that is available without any permission prompt; none of them looks at content.
/// Focus mode is deliberately not detected: macOS exposes it only to apps with Full Disk Access.
enum SmartPause {
    /// Raw detector states, regardless of which triggers are enabled. Used by the Settings pane.
    struct Detected {
        var call = false, screenShare = false, fullscreen = false
    }

    static func detectAll() -> Detected {
        Detected(
            call: cameraInUse() || microphoneInUse(),
            screenShare: screenSharing(),
            fullscreen: fullscreenAppInFront()
        )
    }

    static func activeReason() -> SmartPauseReason? {
        guard Settings.smartPauseEnabled else { return nil }
        if Settings.smartPauseCall, cameraInUse() || microphoneInUse() { return .call }
        if Settings.smartPauseScreenShare, screenSharing() { return .screenShare }
        if Settings.smartPauseFullscreen, fullscreenAppInFront() { return .fullscreen }
        return nil
    }

    // MARK: Camera

    /// True when any process has a camera running (CoreMediaIO "running somewhere").
    static func cameraInUse() -> Bool {
        var address = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIOHardwarePropertyDevices),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        let system = CMIOObjectID(kCMIOObjectSystemObject)
        var size: UInt32 = 0
        guard CMIOObjectGetPropertyDataSize(system, &address, 0, nil, &size) == kCMIOHardwareNoError, size > 0 else { return false }
        var devices = [CMIOObjectID](repeating: 0, count: Int(size) / MemoryLayout<CMIOObjectID>.size)
        var used: UInt32 = 0
        guard CMIOObjectGetPropertyData(system, &address, 0, nil, size, &used, &devices) == kCMIOHardwareNoError else { return false }

        var running = CMIOObjectPropertyAddress(
            mSelector: CMIOObjectPropertySelector(kCMIODevicePropertyDeviceIsRunningSomewhere),
            mScope: CMIOObjectPropertyScope(kCMIOObjectPropertyScopeGlobal),
            mElement: CMIOObjectPropertyElement(kCMIOObjectPropertyElementMain)
        )
        for device in devices {
            var value: UInt32 = 0
            let valueSize = UInt32(MemoryLayout<UInt32>.size)
            var valueUsed: UInt32 = 0
            if CMIOObjectGetPropertyData(device, &running, 0, nil, valueSize, &valueUsed, &value) == kCMIOHardwareNoError,
               value != 0 {
                return true
            }
        }
        return false
    }

    // MARK: Microphone

    /// Bundle ids of apps that hold calls. A headset is input and output in one device and macOS reports
    /// it as running for playback too, so it counts as a call only while one of these is open and no
    /// music app is playing. Calls in a browser tab are not seen this way; the camera still catches video.
    private static let callApps: Set<String> = [
        "us.zoom.xos", "com.microsoft.teams", "com.microsoft.teams2", "com.tinyspeck.slackmacgap",
        "com.apple.FaceTime", "com.hnc.Discord", "com.skype.skype", "com.webex.meetingmanager", "Cisco-Systems.Spark",
    ]

    private static func callAppRunning() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier.map(callApps.contains) ?? false
        }
    }

    /// True when an input device is running somewhere. A device that also plays audio (a headset) and
    /// is the default output counts only with a call app open and no music playing.
    static func microphoneInUse() -> Bool {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(system, &address, 0, nil, &size) == noErr, size > 0 else { return false }
        var devices = [AudioObjectID](repeating: 0, count: Int(size) / MemoryLayout<AudioObjectID>.size)
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &devices) == noErr else { return false }

        var defaultOutput = AudioObjectID(0)
        var defaultSize = UInt32(MemoryLayout<AudioObjectID>.size)
        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        AudioObjectGetPropertyData(system, &defaultAddress, 0, nil, &defaultSize, &defaultOutput)

        for device in devices {
            guard streamCount(device, scope: kAudioObjectPropertyScopeInput) > 0 else { continue }
            if device == defaultOutput, streamCount(device, scope: kAudioObjectPropertyScopeOutput) > 0,
               !(callAppRunning() && !BreakActivities.musicPlaying()) { continue }
            var runningAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            var running: UInt32 = 0
            var runningSize = UInt32(MemoryLayout<UInt32>.size)
            if AudioObjectGetPropertyData(device, &runningAddress, 0, nil, &runningSize, &running) == noErr, running != 0 {
                return true
            }
        }
        return false
    }

    private static func streamCount(_ device: AudioObjectID, scope: AudioObjectPropertyScope) -> Int {
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreams, mScope: scope, mElement: kAudioObjectPropertyElementMain
        )
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(device, &address, 0, nil, &size) == noErr else { return 0 }
        return Int(size) / MemoryLayout<AudioStreamID>.size
    }

    // MARK: Screen sharing

    /// Best effort without the Screen Recording permission: helper processes that only exist
    /// while a screen is being shared or recorded.
    private static let sharingHelpers: Set<String> = [
        "CptHost",            // Zoom screen share
        "screencaptureui",    // macOS screen recording (Shift-Command-5)
        "Screen Sharing Agent",
    ]

    static func screenSharing() -> Bool {
        NSWorkspace.shared.runningApplications.contains { app in
            guard let name = app.localizedName else { return false }
            return sharingHelpers.contains(name)
        }
    }

    // MARK: Fullscreen

    /// True when the frontmost app has a normal-level window covering a whole display.
    static func fullscreenAppInFront() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication,
              app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
              app.bundleIdentifier != "com.apple.finder",
              let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
                as? [[String: Any]]
        else { return false }

        var displayCount: UInt32 = 0
        var displays = [CGDirectDisplayID](repeating: 0, count: 16)
        CGGetActiveDisplayList(16, &displays, &displayCount)
        let displayBounds = displays.prefix(Int(displayCount)).map { CGDisplayBounds($0) }

        for window in windows {
            guard (window[kCGWindowOwnerPID as String] as? pid_t) == app.processIdentifier,
                  (window[kCGWindowLayer as String] as? Int) == 0,
                  let bounds = window[kCGWindowBounds as String] as? [String: CGFloat],
                  let x = bounds["X"], let y = bounds["Y"], let w = bounds["Width"], let h = bounds["Height"]
            else { continue }
            let rect = CGRect(x: x, y: y, width: w, height: h)
            if displayBounds.contains(where: { $0.equalTo(rect) }) { return true }
        }
        return false
    }
}
