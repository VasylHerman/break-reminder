# Break Reminder

A tiny macOS menu bar app that counts how long you have been working without a pause
and reminds you through Notification Center to take a break.

- Work time is measured from system-wide keyboard, mouse and trackpad activity.
- Rest starts after the input has been idle for 5 minutes (configurable). The work counter resets.
- After 45 minutes of continuous work (configurable) a notification fires with a sound (Glass by default), then repeats every 10 minutes until you rest.
- The menu bar shows a plain minute counter (23, or 1:05 from an hour on; a unit can be enabled in Settings), colored by state: default while working,
  orange in the last 5 minutes before the limit (configurable), red once you are over it,
  green while resting.
- A thin outline around the counter shows the block's progress. By default it is full at the
  start and unwinds clockwise as time runs out. Settings offers eight styles, time spent or
  time left, each clockwise, counterclockwise, from or to the bottom, from or to the top, or Off.
  Past the limit the outline closes in red.
- During the warning the counter blinks, and the pace follows the minutes left: every 5 seconds
  at 5 minutes, every second at 1 minute and past the limit. Can be turned off in Settings.

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

## Feedback

Use Feedback in the app menu: "Request a Feature…" and "Report a Bug…" open GitHub issue forms
with the environment details already filled in. Or open an issue directly on
[GitHub](https://github.com/VasylHerman/break-reminder/issues/new/choose).

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
| Pause Reminders | Silence reminders for 30 minutes, 1 hour, 2 hours or until tomorrow. The counter keeps running. A Resume item appears while paused |
| Work Limit | 25, 30, 45, 60, 90 minutes, or Custom… which opens Settings |
| Rest Counts After Idle | 2, 3, 5, 10 minutes, or Custom… which opens Settings |
| Settings… | Opens the Settings window (⌘,) |
| Feedback | Request a Feature and Report a Bug open prefilled GitHub issue forms with your app version, macOS version, install method, settings and current state. Also links to Release Notes and the project page |

## Settings

| Tab | Options |
| --- | --- |
| General | Launch at login. Work limit, rest threshold and warn-before minutes as steppers. Outline style, minutes unit and blink toggle for the menu bar |
| Reminders | Repeat interval, editable title and message with `{minutes}` and `{rest}` placeholders, sound picker that previews on change, Send Test Notification |
| About | Version, install method, feedback and project links, copy the Homebrew install command |

Settings are stored in `UserDefaults` under `dev.vasyl.BreakReminder` and apply immediately.
For development, `open BreakReminder.app --args --settings` opens the window at launch.

## How it decides work vs rest

Every 5 seconds the app reads the system idle time.

- While working, an idle time at or above the rest threshold switches to resting. The rest is
  back-dated to the last input event, so the counter is accurate even though it is noticed late.
- While resting, any new input switches back to working and starts a fresh work block.
- Short pauses below the threshold (reading, thinking, a quick chat) stay inside the work block.
- Sleeping the Mac counts as idle, so a closed lid long enough becomes a rest automatically.
- State is saved every few seconds. If the app restarts (upgrade, crash, relaunch) within the rest
  threshold, the running work block and the pending reminder continue where they were. After a
  longer gap the current block starts fresh, but the last work and rest history is kept.

## Layout

```
Sources/BreakReminder/
  main.swift             app entry point, menu-bar-only activation policy
  AppDelegate.swift      status item, menu, polling, reminder logic
  ActivityTracker.swift  work/rest state machine on top of system idle time
  Notifier.swift         Notification Center banners (osascript fallback for `swift run`)
  Settings.swift         UserDefaults-backed options
  SettingsView.swift     SwiftUI settings form (General, Reminders, About)
  SettingsWindowController.swift  hosts the form in an AppKit window
  Feedback.swift         GitHub links and prefilled issue forms
Support/Info.plist       bundle metadata (LSUIElement hides the Dock icon)
build.sh                 build, bundle, run, install
```

## License

MIT
