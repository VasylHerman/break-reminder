# Break Reminder

A tiny macOS menu bar app that counts how long you have been working without a pause
and reminds you through Notification Center to take a break.

- Work time is measured from system-wide keyboard, mouse and trackpad activity.
- Rest starts after the input has been idle for 5 minutes (configurable). The work counter resets.
- After 45 minutes of continuous work (configurable) a notification fires, then repeats every 10 minutes until you rest.
- The menu bar shows a plain minute counter, colored by state: default while working,
  red once you are over the limit, green while resting.

No Accessibility or Input Monitoring permission is needed. The app only reads the system idle
time (`CGEventSource.secondsSinceLastEventType`), never individual keystrokes or pointer events.
The only prompt you will see is the standard notification permission dialog on first launch.

## Requirements

- macOS 13 or newer
- Xcode (or the Command Line Tools) for the Swift toolchain

## Install with Homebrew

```sh
brew install vasylherman/tap/break-reminder
open "$(brew --prefix)/opt/break-reminder/BreakReminder.app"
```

Homebrew builds the app from source on your Mac, so no notarization or Gatekeeper override
is needed. To start it at login either use the in-app toggle or `brew services start break-reminder`.

## Build and run

```sh
./build.sh run       # build, assemble dist/BreakReminder.app and launch it
./build.sh install   # same, but copy the bundle to /Applications and launch from there
./build.sh bundle    # just build the .app bundle into dist/
```

Use `install` if you want "Launch at Login" to work: macOS registers login items by the app's
location, so the bundle has to live somewhere permanent.

The bundle is ad-hoc signed, which is enough for local use. Nothing is uploaded anywhere.

## Menu

| Item | What it does |
| --- | --- |
| Working for / Resting for | Current counter and the configured limit |
| Last work block / Last rest | Length of the previous period, for a quick sanity check |
| Reset Work Timer | Start the current work block from zero |
| Work Limit | 25, 30, 45, 60 or 90 minutes |
| Rest Counts After Idle | 2, 3, 5 or 10 minutes of no input |
| Launch at Login | Registers the app as a login item |

Settings are stored in `UserDefaults` under `dev.vasyl.BreakReminder`.

## How it decides work vs rest

Every 5 seconds the app reads the system idle time.

- While working, an idle time at or above the rest threshold switches to resting. The rest is
  back-dated to the last input event, so the counter is accurate even though it is noticed late.
- While resting, any new input switches back to working and starts a fresh work block.
- Short pauses below the threshold (reading, thinking, a quick chat) stay inside the work block.
- Sleeping the Mac counts as idle, so a closed lid long enough becomes a rest automatically.

## Layout

```
Sources/BreakReminder/
  main.swift             app entry point, menu-bar-only activation policy
  AppDelegate.swift      status item, menu, polling, reminder logic
  ActivityTracker.swift  work/rest state machine on top of system idle time
  Notifier.swift         Notification Center banners (osascript fallback for `swift run`)
  Settings.swift         UserDefaults-backed options
Support/Info.plist       bundle metadata (LSUIElement hides the Dock icon)
build.sh                 build, bundle, run, install
```

## License

MIT
