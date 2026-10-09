# Changelog

Release notes are taken from this file by the Release workflow: the section whose heading
matches the tag becomes the GitHub release body.

## 0.22.0

### Added
- A chime when the rest a block deserved is complete: Bottle by default, any alert sound or silent in
  Reminders settings. It plays once per rest, only while you are away, never during a call or while
  paused.

### Changed
- A break that comes due during a Smart Pause is delivered the moment the pause ends, with the
  headline "Call over · …" (or "Sharing over", "Back from full screen"). It used to wait for the
  grace period and then for the repeat interval, so after a call it came late or, at Gentle, never.
  The wait is now 0 by default; the Smart Pause setting still allows up to 15 minutes.

## 0.21.2

### Fixed
- The heart's level was measured against the symbol's padded box, so any score above about 80% looked
  full. It now fills the heart itself, so 83% leaves a visible gap at the top.

### Changed
- Gentle keeps the calm heartbeat. Earning Gentle used to stop the heart entirely, which looked like a
  bug; now only the warning ramp and the fast over-limit beat are dropped, along with the repeats.

## 0.21.1

### Fixed
- Stats day headline: under a minute of focus no longer reads "Focused 0m, longest stretch 0m";
  it says nothing was recorded yet. The longest stretch is only named when it is at least a minute
  and shorter than the total.

## 0.21.0

### Changed
- Launch at login is turned on the first time an installed copy runs, from Homebrew or /Applications.
  Turning it off in Settings sticks.
- Reminders always suggest an activity. The "My own text" style and the "My own" activity lines are gone;
  the optional prefix stays, and with every category off the plain reminder is used.

## 0.20.2

### Changed
- The menu shows the installed version above Quit, and the menu bar tooltip starts with it.
- Stats… sits with Reset Work Timer and Pause Reminders.

## 0.20.1

### Changed
- Settings › General shows when the last update check ran.

## 0.20.0

### Added
- Self-updating. Once a day the app checks the latest GitHub release; with a Homebrew install it upgrades itself through `brew upgrade` at the next rest and restarts in the same state. The menu offers "Update to x.y.z…" to do it right away. Both are toggles in Settings › General, on by default. Copies not installed with Homebrew get a link to the release page.
- Release automation. Pushing a version tag publishes the GitHub release from CHANGELOG.md, verifies the source tarball, bumps the Homebrew formula in the tap, and the tap builds and publishes bottles.

## 0.19.0

### Added
- More activities: 47 built-in now, in nine categories. New Home (feed the pet, water the plants, clear your desk, a quick shower, freshen up, open the curtains) and Mac (install updates, check your backup, lock your screen, review a security setting, clean the keyboard), plus hug your partner and turn on some music.
- A one-line reason on every built-in activity, after the action, worded to what research supports. "Add the reason why it helps" in Reminders turns it off.

### Changed
- The activity is the banner headline: "Drink some water" instead of "Time for a break · Drink some water". The Title field became an optional prefix. Repeats lead with "Still here" or "12 min over".

## 0.18.0

### Added
- Suggested activities. Each reminder now proposes one concrete thing to do, like "Drink some water" or "Look out the window", from 34 built-in activities in seven categories: Move, Eyes, Drink and eat, Air and light, Breathe and reset, People, Enjoy. Turn categories off in Settings › Reminders, and add your own lines such as medication or the plants.
- Rules: never the same activity as the last two, outdoor ones only in daylight, coffee not after 16:00, and "Dance" only while a music app is playing. Repeats keep the activity and shorten the text.
- "My own text" keeps the previous editable title and message. Send Test Notification shows a real pick.

## 0.17.1

### Fixed
- The arc around the heart, the dot and the minutes was invisible on a dark menu bar. It is now drawn like the heart itself, and the faded outline colors resolve where they are drawn.
- A redraw loop after the dark mode fix in 0.17.0 kept the app busy in the background.

## 0.17.0

### Added
- App icon: a white heart gauge on a teal tile, matching the menu bar glyph. It is compiled into an asset catalog, which is what Notification Center reads for banners, plus a classic icns for Finder, and it appears in the About pane.

### Fixed
- In dark mode the heart and its arc were invisible: they were drawn under the app's light appearance. They are now rendered under the menu bar's own appearance.
- The item switches between light and dark instantly, instead of at the next 5 second tick.

### Changed
- By default only the heart's body beats; level and arc stay still. Existing settings are kept.

## 0.16.0

### Added
- Recovery gauge. The arc fills with work and unwinds with rest, starting from the first idle seconds at a rate where the rest the block deserves brings it to empty. Return before the threshold and the block continues with the arc back at the work level. The heartbeat keeps a calm rate until the arc is empty. The menu shows "recovered 60%" while resting.
- Carry unfinished rest into the next block, in Settings › General, off by default. On, a longer block needs a proportionally longer rest, and whatever was not recovered starts the next block's arc. Reminders and the limit are unaffected.
- Choose which parts of the heart beat: body, level, arc, any combination, under Appearance › Advanced.
- A second launch of the app replaces the running one instead of adding a second menu bar item.

### Fixed
- Relaunching the app during a work block logged a duplicate "break due", which then counted as skipped. One due per block now, and existing duplicates are merged on launch with the day counts recomputed.
- Hovering in Stats could crash the app. Hover details now appear in a readout line below the figures, and the timeline's hover area matches the drawn track.

### Notes
- To have the app restarted after a crash, run it as a Homebrew service: `brew services start break-reminder`. The service restarts only after abnormal exits; Quit stays quit.

## 0.15.1

### Changed
- New defaults for fresh installs and Reset All Settings: the outline grows from the bottom toward the top on both sides as time is spent, and the heartbeat is on while working, at the normal rate. Existing settings are kept.

## 0.15.0

### Added
- Heartbeat. The warning blink is now a lub-dub at a heart rate: 10 beats per minute normally, climbing to 40 through the warning, and 80 past the limit. Rates are adjustable in Settings › Appearance › Advanced, or with `defaults write dev.vasyl.BreakReminder beatWarningBPM -int 60`. Beating while working is optional and off by default.
- Outline span. A whole block covers a share of the outline, 50% by default, adjustable in Advanced or with `defaults write dev.vasyl.BreakReminder outlineSpanPercent -int 75`.

### Changed
- Past the limit the arc keeps its covered share and turns red; it no longer closes into a full ring.
- In Heart mode the ring stays in the neutral tone in every state; the heartbeat carries the warning.
- The heartbeat works with Reduce Motion on, stepping instead of fading. It used to be off entirely.

## 0.14.0

### Added
- Firmness. Gentle sends one reminder per block with no repeats and no blink, Normal repeats on your interval, Firm repeats every 5 minutes. Automatic, the default, earns calm from the last 7 days: 90% on time means Gentle, 40 to 89 Normal, 15 to 39 Firm. Below 15 the app steps down to Gentle and asks once, through a notification with Pause for Today and Change Limit buttons. Re-evaluated daily once 5 breaks were due. Pick a level in Settings › Reminders to lock it; the menu shows the level in force.
- Stats redesign. A one-line headline with the score heart, then today as a timeline of focus and rest with skipped breaks marked, the week as bars of focused time, or the month as a calendar grid tinted by on-time share, all with hover readouts. Figures show deltas against the previous period; the rules moved into tooltips. History keeps finished blocks for two days for the timeline.

### Changed
- The heart is drawn like the battery icon: a lighter body around a solid level, the same stroke width and gap, centered on the glyph. It keeps the menu bar color in every state; the ring around it carries the state, orange in the warning, red when over, hidden while resting, and follows the outline settings.
- All outlines, pill, dot ring and heart ring, use one tone family: 1 point at 40% of the menu bar color while working, 65% of the state color in the warning and over.

## 0.13.1

### Fixed
- The heart and dot were too small and too faint next to the other menu bar icons. The heart is now larger and semibold, the dot larger, both in the full menu bar color while working, and their rings use a heavier line in a stronger color.
- The heart's fill is drawn lighter than its outline, so the weekly score level is readable at any value.
- The Appearance preview uses the same sizes and colors as the menu bar.

## 0.13.0

### Changed
- Stats moved into the settings window as its first tab. One window: Stats, General, Appearance, Reminders, Smart Pause, About. "Stats…" (⌘S) opens it on Stats, "Settings…" (⌘,) on General.
- The Stats pane uses the same grouped layout as the other panes, with Time and Breaks sections.
- In Appearance the "Counter" picker is now "Show as", with Minutes with unit, Minutes, Dot, Heart. Captions use the same wording.

## 0.12.0

### Added
- Break history. Every time the limit is reached the app records whether a rest followed: on time within 5 minutes, late within 15, otherwise skipped. Reset Work Timer counts as skipped. Breaks held by Smart Pause are not counted against you.
- Stats window (⌘S from the menu) with Day, Week and Month: focused and resting time, longest block, breaks taken of due, on-time share, good days and streak. Today includes the running block live.
- Menu line "Breaks this week: 9 of 12".
- Heart counter mode. The menu bar item is a heart that fills with the week's on-time share, takes the state color, and is ringed by the outline. This is the default for new installs; existing installs keep their counter choice.
- Optional heart beside the number or the dot, off by default, in Appearance.

### Storage
- History lives in `~/Library/Application Support/BreakReminder/history.json`. Daily totals are kept for 62 days and break events for 14 days; older data is dropped automatically, so the file stays a few KB.

## 0.11.0

### Added
- Smart Pause. Reminders, sound and blink are held while the camera or microphone is in use, while the screen is shared (Zoom share and macOS screen recording), or while a fullscreen app is in front. The counter and outline keep going. After a pause ends, an overdue reminder waits a 2 minute grace period, unless a rest has started. All detection works without permission prompts.
- Smart Pause pane in Settings: master switch, one toggle per trigger with a live "Now" indicator when that situation is detected, and the grace period. Fullscreen is off by default since a fullscreen editor would count. Focus modes are not offered because macOS reveals them only to apps with Full Disk Access.
- Counter picker in Appearance: Number with unit, Number, or Hidden. Hidden shows a small dot in the state color with the outline drawn as a ring around it, so every outline option applies to the ring as well.
- The menu shows "Reminders held: …" with the reason while a Smart Pause is active.

### Changed
- The "Show minutes unit" toggle is replaced by the Counter picker. The old setting migrates.

## 0.10.0

### Added
- Appearance pane in Settings with the live preview, a theme picker and the outline options. Direction, minutes unit and blink moved under Advanced.
- Themes. Quiet (default): monochrome number, the outline carries the state, red only once you are over. Signal: orange warning, red over, green rest, the previous look. Accent: your macOS accent color for the warning and the outline.
- Outline direction is now complete: clockwise, counterclockwise, from the bottom, from the top, for both time spent and time left.
- Reset All Settings… in About, with confirmation. Timer state and history are kept.
- Reduce Motion in System Settings turns the blink off; Increase Contrast thickens the outline.

### Changed
- New defaults: 25 minute work limit, Submarine reminder sound, outline shows time spent growing clockwise. Existing settings are kept.
- The Reminders button is now Restore Default Text and resets only the title and message.
- General keeps login and the timer values only.

### Fixed
- The outline in the menu bar was mirrored compared to the preview: it started at the bottom and ran counterclockwise. Direction and anchor now match the preview for every style.

## 0.9.0

### Added
- Progress outline. A thin outline around the menu bar counter shows how the work block is going. By default it is full at the start and unwinds from the top as time runs out; past the limit it closes in red.
- Outline styles in Settings › General › Menu bar: Off, time spent fills clockwise, time left unwinds from the top, time left retreats to the top, time left shrinks to the bottom.
- Blink during the warning. The counter fades out and back on a schedule that follows the minutes left: every 5 seconds at 5 minutes, every second at 1 minute and past the limit. Toggle in Settings, silenced while reminders are paused.
- Live preview in Settings: a mock menu bar plays a whole work block with the chosen outline, unit, warning color and blink.

### Changed
- The menu bar counter shows just the number by default (23, or 1:05 from an hour on). "Show minutes unit" in Settings brings back 23m and 1h 05m.

## 0.8.0

### Added
- Editable reminder. Title and message can be changed in Settings › Reminders. The message supports `{minutes}` for the length of the work block and `{rest}` for the rest threshold. Restore Defaults brings the original text back.
- Send Test Notification button that shows the reminder exactly as it will appear, with the selected sound.

### Changed
- Settings is now a native preferences window: General, Reminders and About as toolbar tabs with icons, the pane name in the title, and the window resizing to each pane.
- Title and message are full-width bordered fields. Choosing a sound plays it immediately, so the separate Preview button is gone.
- Settings… sits in its own menu group so the Work Limit and Rest Counts After Idle submenus are no longer indented.

## 0.7.0

### Added
- Settings window (⌘, from the menu) with three tabs. General: launch at login, work limit, rest threshold and warn-before as steppers, so any value works. Reminders: repeat interval and alert sound with preview. About: version, install method, feedback links and the Homebrew install command.
- Pause Reminders submenu: silence reminders for 30 minutes, 1 hour, 2 hours or until tomorrow. The counter keeps running, the menu shows when reminders resume, and a Resume Reminders item appears while paused.
- Custom… entries in the Work Limit and Rest Counts After Idle submenus open Settings for values outside the presets.

### Changed
- The menu is shorter: status, Reset Work Timer, Pause Reminders, Work Limit, Rest Counts After Idle, Settings…, Feedback, Quit. Warn-before, sound and launch at login now live in Settings.
- The menu bar counter uses the regular menu bar font, matching the clock, with monospaced digits.

### Fixed
- Settings changed in the window apply immediately without restarting the app.

## 0.6.0

### Added
- Feedback submenu. "Request a Feature…" and "Report a Bug…" open GitHub issue forms with the environment already filled in: app version, macOS version, install method, current settings and current timer state.
- Release Notes, Star on GitHub and Project on GitHub links in the same submenu.
- Issue form templates for feature requests and bug reports. Blank issues are disabled.

### Removed
- The plain "Open on GitHub" menu item, replaced by the Feedback submenu.

## 0.5.1

### Fixed
- The pre-limit warning color is now orange instead of yellow, which was hard to read on a light menu bar.

## 0.5.0

### Added
- Warning color. The counter turns yellow during the last 5 minutes before the work limit, then red once the limit is reached.
- "Warn Before Limit" submenu with Off, 2, 3, 5 or 10 minutes.

## 0.4.0

### Added
- Reminder sound. Every reminder, including repeats, plays a macOS alert sound. Glass is the default.
- "Sound" submenu with Off and all 14 built-in alert sounds. Picking one plays a preview.

## 0.3.0

### Added
- State persistence. The current work or rest block, the history and the pending reminder are saved every few seconds and restored on launch, so an upgrade, crash or relaunch no longer resets the counter.
- If the app was away longer than the rest threshold the current block starts fresh, since the gap cannot be classified, but the last work and rest history is kept.

### Changed
- The version line in the menu no longer shows the bundle build number.

## 0.2.0

### Added
- Version line in the menu, read from the app bundle.
- "Open on GitHub" menu item.
- "Copy Homebrew Install Command" menu item, puts `brew install vasylherman/tap/break-reminder` on the clipboard.

## 0.1.0

First release of Break Reminder, a macOS menu bar app that counts how long you have been working and reminds you to take a break.

### Features
- Tracks continuous work from system-wide keyboard, mouse and trackpad activity. Reads only the system idle time, so no Accessibility or Input Monitoring permission is needed.
- Rest starts after 5 minutes without input and resets the work counter. Short pauses stay inside the work block.
- Notification Center reminder after 45 minutes of continuous work, repeated every 10 minutes until you rest.
- Menu bar counter: default color while working, red over the limit, green while resting.
- Menu: reset work timer, work limit (25 to 90 minutes), rest threshold (2 to 10 minutes), launch at login, last work block and last rest.
- `build.sh` assembles an ad-hoc signed `.app` bundle. Installable from the Homebrew tap `vasylherman/tap`.
