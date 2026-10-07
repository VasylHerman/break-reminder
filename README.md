# Break Reminder

A tiny macOS menu bar app that counts how long you have been working without a pause
and reminds you through Notification Center to take a break.

- Work time is measured from system-wide keyboard, mouse and trackpad activity.
- Rest starts after the input has been idle for 5 minutes (configurable). The work counter resets.
- After 25 minutes of continuous work (configurable) a notification fires with a sound (Submarine by default), then repeats every 10 minutes until you rest.
- The menu bar item is a heart by default: it fills with the week's on-time share, takes the state
  color, and the outline rings it. Settings can switch it to a dot, or to the minute counter
  (23, or 1:05 from an hour on, optionally with the unit) wrapped by the outline.
  The default theme is monochrome: the number stays in the menu bar color and the outline
  carries the state, red only once you are over. The Signal theme adds orange for the warning
  and green for rest; Accent uses your macOS accent color.
- A thin outline around the counter shows the block's progress. By default it grows clockwise
  from the top as time is spent. Settings offers time spent, time left or Off, with the
  direction under Advanced. Past the limit the outline closes in red.
- During the warning the counter blinks, and the pace follows the minutes left: every 5 seconds
  at 5 minutes, every second at 1 minute and past the limit. Can be turned off in Settings, and
  stays off while Reduce Motion is on. Increase Contrast thickens the outline.

- Smart Pause holds reminders, sound and blink while the camera or microphone is in use, while
  the screen is shared (Zoom and macOS recording), or while a fullscreen app is in front (off by
  default). Each trigger is a toggle. Focus modes are not detected since macOS reveals them only
  to apps with Full Disk Access. After a pause ends, an overdue
  reminder waits a 2 minute grace period.

- Stats, the first tab of the Settings window (⌘S from the menu): focused and rest time, longest block, breaks taken of due, on-time share,
  good days and streak, for today, the calendar week and the calendar month. An optional heart
  next to the counter fills with the week's on-time share. A break is on time when
  a rest starts within 5 minutes of the limit, half when within 15. Breaks held by Smart Pause are
  not counted against you. History lives in `~/Library/Application Support/BreakReminder/history.json`:
  daily totals for 62 days and break events for 14 days, older data is dropped automatically.

- Firmness. Gentle sends one reminder per block with no repeats and no blink; Normal repeats on
  your interval and blinks in the warning; Firm repeats every 5 minutes. Automatic, the default,
  earns calm from the last 7 days: 90% on time means Gentle, 40 to 89 Normal, 15 to 39 Firm.
  Below 15 the app steps down to Gentle and asks once, through a notification with Pause for
  Today and Change Limit buttons, instead of nagging. Re-evaluated daily once 5 breaks were due.
  Pick a level in Settings to lock it.

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
| Breaks this week | Breaks taken of breaks due in the calendar week |
| Firmness | Current level and whether it is earned, stepped down or locked |
| Last work block / Last rest | Length of the previous period, for a quick sanity check |
| Reset Work Timer | Start the current work block from zero. A pending break counts as skipped |
| Stats… | Opens the window on the Stats tab (⌘S) |
| Pause Reminders | Silence reminders for 30 minutes, 1 hour, 2 hours or until tomorrow. The counter keeps running. A Resume item appears while paused |
| Work Limit | 25, 30, 45, 60, 90 minutes, or Custom… which opens Settings |
| Rest Counts After Idle | 2, 3, 5, 10 minutes, or Custom… which opens Settings |
| Settings… | Opens the window on the General tab (⌘,) |
| Feedback | Request a Feature and Report a Bug open prefilled GitHub issue forms with your app version, macOS version, install method, settings and current state. Also links to Release Notes and the project page |

## Settings

| Tab | Options |
| --- | --- |
| General | Launch at login. Work limit, rest threshold and warn-before minutes as steppers |
| Appearance | Live preview, theme (Quiet, Signal, Accent), show as (minutes with unit, minutes, dot, heart), outline mode, weekly score heart beside it, and under Advanced the outline direction and blink |
| Reminders | Firmness (Automatic, Gentle, Normal, Firm), repeat interval, editable title and message with `{minutes}` and `{rest}` placeholders, sound picker that previews on change, Send Test Notification |
| Smart Pause | Master switch, the three triggers with a live "Now" indicator when detected, and the grace period |
| About | Version, install method, feedback and project links, copy the Homebrew install command, Reset All Settings |

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
  SmartPause.swift       call, screen share and fullscreen detection
  Firmness.swift         firmness levels and the automatic mapping from the weekly score
  History.swift          on-disk daily totals and break events with retention
  Stats.swift            day, week and month aggregation
  StatsView.swift        Stats pane
  Settings.swift         UserDefaults-backed options
  SettingsView.swift     SwiftUI settings panes (General, Appearance, Reminders, Smart Pause, About)
  SettingsWindowController.swift  one window with Stats first, then the settings panes
  Theme.swift            curated menu bar color themes
  MenuBarPreview.swift   animated preview of the menu bar item
  ProgressBorder.swift   outline layer around the counter
  SettingsWindowController.swift  hosts the form in an AppKit window
  Feedback.swift         GitHub links and prefilled issue forms
Support/Info.plist       bundle metadata (LSUIElement hides the Dock icon)
build.sh                 build, bundle, run, install
```

## License

MIT
