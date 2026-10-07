import AppKit
import CoreAudio
import Foundation

/// Suggested break activities: one concrete thing to do, picked per reminder.
enum BreakActivities {
    enum Category: String, CaseIterable, Identifiable {
        case move, eyes, drink, air, breathe, people, enjoy, home, mac, custom
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
            case .home: return "Home"
            case .mac: return "Mac"
            case .custom: return "My own"
            }
        }
    }

    struct Activity {
        let category: Category
        let title: String
        let body: String
        /// One sentence on why it helps, worded to what research supports.
        var why: String = ""
        /// Only between 7:00 and 19:00.
        var daylightOnly = false
        /// Not from this hour on (24 h), for caffeine.
        var notAfterHour: Int? = nil
        /// Only when this is true at pick time, for example music playing.
        var requires: (() -> Bool)? = nil
    }

    static let all: [Activity] = [
        // Move
        Activity(category: .move, title: "Stand up and stretch", body: "Reach for the ceiling, then roll your shoulders back five times.",
                 why: "Long sitting is linked to heart risk; even short movement restores blood flow."),
        Activity(category: .move, title: "Walk a little", body: "Two minutes to the farthest window and back.",
                 why: "Light walking after sitting lowers blood sugar peaks and lifts mood."),
        Activity(category: .move, title: "Loosen your neck", body: "Tilt your head to each shoulder and hold for ten seconds.",
                 why: "Screen posture loads the neck; gentle stretching reduces tension headaches."),
        Activity(category: .move, title: "Shake out your hands", body: "Open and close your fists ten times, then shake them loose.",
                 why: "Typing strains tendons; brief release helps prevent repetitive strain injury."),
        Activity(category: .move, title: "Ten squats", body: "Right next to your desk. Nobody is watching.",
                 why: "Big muscles pumping counteracts hours of sitting and wakes you up."),
        Activity(category: .move, title: "Fix your posture", body: "Feet flat, shoulders down, screen at eye level. Then a short walk.",
                 why: "Posture resets reduce back and neck pain from desk work."),
        Activity(category: .move, title: "Climb some stairs", body: "One flight up and down counts.",
                 why: "Stair climbing is one of the most efficient ways to raise your heart rate."),
        // Eyes
        Activity(category: .eyes, title: "Rest your eyes", body: "Look at something far away for twenty seconds.",
                 why: "Focusing far relaxes the eye muscles; the 20-20-20 rule reduces digital eye strain."),
        Activity(category: .eyes, title: "Blink slowly", body: "Ten slow blinks, then close your eyes for a few seconds.",
                 why: "Blink rate roughly halves at screens, which dries the eyes."),
        Activity(category: .eyes, title: "Look out the window", body: "Find the farthest thing you can see and watch it for a moment.",
                 why: "Distance viewing and daylight ease eye strain and steady your body clock.", daylightOnly: true),
        // Drink and eat
        Activity(category: .drink, title: "Drink some water", body: "A full glass, now, not later.",
                 why: "Even mild dehydration measurably worsens attention and mood."),
        Activity(category: .drink, title: "Coffee or tea?", body: "Make it properly and drink it away from the screen.",
                 why: "Caffeine sharpens alertness; stopping by mid-afternoon protects your sleep.", notAfterHour: 16),
        Activity(category: .drink, title: "Have a small snack", body: "Fruit or nuts, not the third cookie.",
                 why: "Steady blood sugar keeps concentration steady; sugar spikes end in a crash."),
        // Air and light
        Activity(category: .air, title: "Open a window", body: "Let fresh air in for a few minutes.",
                 why: "CO2 builds up in closed rooms and measurably dulls decision-making."),
        Activity(category: .air, title: "Step outside", body: "Five minutes of daylight does more than another coffee.",
                 why: "Daylight anchors your circadian rhythm and lifts mood; sun also makes vitamin D.", daylightOnly: true),
        Activity(category: .air, title: "Get some sun", body: "Face the light for a minute, even through a window.",
                 why: "Bright light during the day improves alertness now and sleep tonight.", daylightOnly: true),
        // Breathe and reset
        Activity(category: .breathe, title: "Breathe", body: "Four seconds in, four seconds hold, four seconds out. Five rounds.",
                 why: "Slow breathing engages the calming branch of the nervous system and lowers heart rate."),
        Activity(category: .breathe, title: "Do nothing", body: "Sit back, hands off the keyboard, and let your mind wander for a minute.",
                 why: "Mind-wandering helps the brain consolidate and find creative solutions."),
        Activity(category: .breathe, title: "Tidy one thing", body: "Clear the cup, the papers, or the cables. A small reset.",
                 why: "Visual clutter competes for attention and makes focus harder."),
        Activity(category: .breathe, title: "Write down the next step", body: "Then let it go for five minutes.",
                 why: "Writing an open task down stops it looping in your head, so the rest is real."),
        // People
        Activity(category: .people, title: "Call a friend", body: "A two minute call beats another scroll.",
                 why: "Social contact lowers stress hormones; loneliness is a real health risk."),
        Activity(category: .people, title: "Say hi to a colleague", body: "Not about work.",
                 why: "Small friendly contact raises wellbeing and makes teams work better."),
        Activity(category: .people, title: "Write to someone", body: "The message you have been meaning to send.",
                 why: "Reaching out strengthens ties that protect mental health."),
        Activity(category: .people, title: "Hug your partner", body: "A real one, at least twenty seconds.",
                 why: "Hugs release oxytocin, which lowers blood pressure and stress."),
        Activity(category: .people, title: "Check on the people around you", body: "Family, pets, or the plants.",
                 why: "Caring for others is one of the most reliable mood boosters."),
        // Enjoy
        Activity(category: .enjoy, title: "Play a quick game", body: "One round of anything. Table tennis, a puzzle, a level.",
                 why: "Play lowers stress and restores the attention you spend on work."),
        Activity(category: .enjoy, title: "Turn on some music", body: "Something you love, not background noise.",
                 why: "Favorite music releases dopamine and lowers cortisol.", requires: { !musicPlaying() }),
        Activity(category: .enjoy, title: "One favorite song", body: "Headphones on, eyes closed, the whole track.",
                 why: "Music you love releases dopamine and lowers the stress hormone cortisol."),
        Activity(category: .enjoy, title: "Dance", body: "The music is already on. One song, the whole body.",
                 why: "Dancing is exercise plus music: it lifts mood faster than either alone.", requires: musicPlaying),
        Activity(category: .enjoy, title: "Take the car for a spin", body: "Around the block with the windows down.",
                 why: "A short change of scene resets attention better than staying put.", daylightOnly: true),
        Activity(category: .enjoy, title: "Pet the cat or the dog", body: "They have been waiting for this.",
                 why: "Minutes with a pet lower cortisol and raise oxytocin in both of you."),
        Activity(category: .enjoy, title: "Doodle something", body: "Pen and paper, no purpose.",
                 why: "Purposeless drawing calms the mind and frees up thinking."),
        Activity(category: .enjoy, title: "Plan the next trip", body: "Five minutes of daydreaming about where to go.",
                 why: "Anticipating a trip raises happiness, often more than the trip itself."),
        Activity(category: .enjoy, title: "Watch something you love", body: "A three minute clip, then back.",
                 why: "A short laugh lowers stress hormones and relaxes muscles."),
        Activity(category: .enjoy, title: "A few minutes with your hobby", body: "The guitar, the camera, the sketchbook, whatever is nearest.",
                 why: "Hobbies are linked to lower stress and better wellbeing in every age group."),
        // Home
        Activity(category: .home, title: "Feed the pet", body: "Dog, cat, bird or fish: check the bowl and the water.",
                 why: "Routine care keeps them healthy, and the contact lowers your stress too."),
        Activity(category: .home, title: "Water the plants", body: "Check the soil with a finger first.",
                 why: "Plants in the room improve mood and perceived air quality."),
        Activity(category: .home, title: "Clear your desk", body: "Everything that is not for the next task goes away.",
                 why: "A clear desk reduces distraction; clutter competes for attention."),
        Activity(category: .home, title: "Take a quick shower", body: "Warm to relax, cool at the end to wake up.",
                 why: "A cool rinse raises alertness; warm water loosens tense muscles."),
        Activity(category: .home, title: "Freshen up", body: "A splash of your favorite scent.",
                 why: "A scent you like lifts mood and confidence; smell links straight to emotion."),
        Activity(category: .home, title: "Open the curtains", body: "Let the daylight in and look out for a moment.",
                 why: "Daylight at the desk improves alertness and sleep quality.", daylightOnly: true),
        // Mac
        Activity(category: .mac, title: "Install pending updates", body: "System Settings, General, Software Update. Let it run while you rest.",
                 why: "Most attacks exploit flaws that already have a patch."),
        Activity(category: .mac, title: "Check your backup", body: "Is Time Machine or your cloud backup current?",
                 why: "Backups are the only cure for ransomware and a dead disk."),
        Activity(category: .mac, title: "Lock your screen when you step away", body: "Control-Command-Q. Make it a habit.",
                 why: "An unlocked Mac is the easiest way in for anyone passing by."),
        Activity(category: .mac, title: "Review one security setting", body: "Two-factor on your main accounts, FileVault on, firewall on.",
                 why: "Two-factor stops the great majority of account takeovers."),
        Activity(category: .mac, title: "Clean the keyboard and screen", body: "A dry cloth, keys and glass.",
                 why: "Keyboards carry more bacteria than most surfaces you touch."),
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
