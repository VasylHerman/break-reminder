import AppKit
import CoreAudio
import Foundation

/// Suggested break activities: one concrete thing to do, picked per reminder.
enum BreakActivities {
    enum Category: String, CaseIterable, Identifiable {
        case move, eyes, drink, air, breathe, people, enjoy, custom
        var id: String { rawValue }
        var label: String {
            switch self {
            case .move: return "Move"
            case .eyes: return "Eyes"
            case .drink: return "Drink and eat"
            case .air: return "Air and light"
            case .breathe: return "Breathe and reset"
            case .people: return "People"
            case .enjoy: return "Enjoy"
            case .custom: return "My own"
            }
        }
    }

    struct Activity {
        let category: Category
        let title: String
        let body: String
        /// Only between 7:00 and 19:00.
        var daylightOnly = false
        /// Not from this hour on (24 h), for caffeine.
        var notAfterHour: Int? = nil
        /// Only when this is true at pick time, for example music playing.
        var requires: (() -> Bool)? = nil
    }

    static let all: [Activity] = [
        // Move
        Activity(category: .move, title: "Stand up and stretch", body: "Reach for the ceiling, then roll your shoulders back five times."),
        Activity(category: .move, title: "Walk a little", body: "Two minutes to the farthest window and back."),
        Activity(category: .move, title: "Loosen your neck", body: "Tilt your head to each shoulder and hold for ten seconds."),
        Activity(category: .move, title: "Shake out your hands", body: "Open and close your fists ten times, then shake them loose."),
        Activity(category: .move, title: "Ten squats", body: "Right next to your desk. Nobody is watching."),
        Activity(category: .move, title: "Fix your posture", body: "Feet flat, shoulders down, screen at eye level. Then a short walk."),
        Activity(category: .move, title: "Climb some stairs", body: "One flight up and down counts."),
        // Eyes
        Activity(category: .eyes, title: "Rest your eyes", body: "Look at something far away for twenty seconds."),
        Activity(category: .eyes, title: "Blink slowly", body: "Ten slow blinks, then close your eyes for a few seconds."),
        Activity(category: .eyes, title: "Look out the window", body: "Find the farthest thing you can see and watch it for a moment.", daylightOnly: true),
        // Drink and eat
        Activity(category: .drink, title: "Drink some water", body: "A full glass, now, not later."),
        Activity(category: .drink, title: "Coffee or tea?", body: "Make it properly and drink it away from the screen.", notAfterHour: 16),
        Activity(category: .drink, title: "Have a small snack", body: "Fruit or nuts, not the third cookie."),
        // Air and light
        Activity(category: .air, title: "Open a window", body: "Let fresh air in for a few minutes."),
        Activity(category: .air, title: "Step outside", body: "Five minutes of daylight does more than another coffee.", daylightOnly: true),
        Activity(category: .air, title: "Get some sun", body: "Face the light for a minute, even through a window.", daylightOnly: true),
        // Breathe and reset
        Activity(category: .breathe, title: "Breathe", body: "Four seconds in, four seconds hold, four seconds out. Five rounds."),
        Activity(category: .breathe, title: "Do nothing", body: "Sit back, hands off the keyboard, and let your mind wander for a minute."),
        Activity(category: .breathe, title: "Tidy one thing", body: "Clear the cup, the papers, or the cables. A small reset."),
        Activity(category: .breathe, title: "Write down the next step", body: "Then let it go for five minutes."),
        // People
        Activity(category: .people, title: "Call a friend", body: "A two minute call beats another scroll."),
        Activity(category: .people, title: "Say hi to a colleague", body: "Not about work."),
        Activity(category: .people, title: "Write to someone", body: "The message you have been meaning to send."),
        Activity(category: .people, title: "Play a quick game", body: "Table tennis, a round of darts, or a chess puzzle."),
        Activity(category: .people, title: "Check on the people around you", body: "Family, pets, or the plants."),
        // Enjoy
        Activity(category: .enjoy, title: "Play a quick game", body: "One round of anything. Table tennis, a puzzle, a level."),
        Activity(category: .enjoy, title: "One favorite song", body: "Headphones on, eyes closed, the whole track."),
        Activity(category: .enjoy, title: "Take the car for a spin", body: "Around the block with the windows down.", daylightOnly: true),
        Activity(category: .enjoy, title: "Pet the cat or the dog", body: "They have been waiting for this."),
        Activity(category: .enjoy, title: "Doodle something", body: "Pen and paper, no purpose."),
        Activity(category: .enjoy, title: "Plan the next trip", body: "Five minutes of daydreaming about where to go."),
        Activity(category: .enjoy, title: "Watch something you love", body: "A three minute clip, then back."),
        Activity(category: .enjoy, title: "A few minutes with your hobby", body: "The guitar, the camera, the sketchbook, whatever is nearest."),
        Activity(category: .enjoy, title: "Dance", body: "The music is already on. One song, the whole body.", requires: musicPlaying),
    ]

    /// Music is playing: a music app is running and the default output device is active.
    /// No permission needed; it never looks at what is playing.
    static func musicPlaying() -> Bool {
        let players = ["com.apple.Music", "com.spotify.client", "com.tidal.desktop", "com.apple.iTunes", "com.deezer.deezer-desktop"]
        let playerRunning = NSWorkspace.shared.runningApplications.contains { app in
            app.bundleIdentifier.map(players.contains) ?? false
        }
        return playerRunning && audioPlaying()
    }

    private static func audioPlaying() -> Bool {
        let system = AudioObjectID(kAudioObjectSystemObject)
        var device = AudioObjectID(0)
        var size = UInt32(MemoryLayout<AudioObjectID>.size)
        var address = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultOutputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        guard AudioObjectGetPropertyData(system, &address, 0, nil, &size, &device) == noErr, device != 0 else { return false }
        var running: UInt32 = 0
        var runningSize = UInt32(MemoryLayout<UInt32>.size)
        var runningAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyDeviceIsRunningSomewhere,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        return AudioObjectGetPropertyData(device, &runningAddress, 0, nil, &runningSize, &running) == noErr && running != 0
    }

    /// Picks an activity for now: enabled categories, time rules, and never one of the last two.
    static func pick(enabled: Set<Category>, custom: [String], recent: [String], now: Date = Date()) -> Activity? {
        let hour = Calendar.current.component(.hour, from: now)
        var pool = all.filter { enabled.contains($0.category) }
        pool = pool.filter { !($0.daylightOnly && (hour < 7 || hour >= 19)) }
        pool = pool.filter { $0.notAfterHour.map { hour < $0 } ?? true }
        pool = pool.filter { $0.requires?() ?? true }
        if enabled.contains(.custom) {
            pool += custom.map { Activity(category: .custom, title: $0, body: "") }
        }
        let fresh = pool.filter { !recent.contains($0.title) }
        return (fresh.isEmpty ? pool : fresh).randomElement()
    }
}
