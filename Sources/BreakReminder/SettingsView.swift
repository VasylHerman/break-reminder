import AppKit
import ServiceManagement
import SwiftUI

/// Panes of the Settings window. Values are bound straight to UserDefaults through @AppStorage,
/// using the same keys as `Settings`, so the rest of the app sees changes immediately.

/// A form row with the label on the left, the value right-aligned, and a stepper after it.
struct StepperRow: View {
    let label: String
    let value: String
    @Binding var number: Int
    let range: ClosedRange<Int>
    var step = 1

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            Text(value).foregroundStyle(.secondary).monospacedDigit()
            Stepper("", value: $number, in: range, step: step).labelsHidden()
        }
    }
}

struct GeneralSettingsView: View {
    @AppStorage(Settings.Key.workLimit) private var workLimit = 25
    @AppStorage(Settings.Key.restThreshold) private var restThreshold = 5
    @AppStorage(Settings.Key.warnBefore) private var warnBefore = 5
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var launchAtLoginError: String?

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { enabled in setLaunchAtLogin(enabled) }
                if let launchAtLoginError {
                    Text(launchAtLoginError).font(.caption).foregroundStyle(.red)
                }
            }
            Section("Timer") {
                StepperRow(label: "Work limit", value: "\(workLimit) min", number: $workLimit, range: 5...240, step: 5)
                StepperRow(label: "Rest counts after idle", value: "\(restThreshold) min", number: $restThreshold, range: 1...60)
                StepperRow(label: "Warn before limit", value: warnBefore == 0 ? "Off" : "\(warnBefore) min",
                           number: $warnBefore, range: 0...60)
                Text("The counter turns orange when the warning starts and red once the limit is reached. "
                     + "Rest begins after the keyboard, mouse and trackpad have been idle for the rest threshold.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "Could not change login item: \(error.localizedDescription)"
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}

struct AppearanceSettingsView: View {
    @AppStorage(Settings.Key.workLimit) private var workLimit = 25
    @AppStorage(Settings.Key.warnBefore) private var warnBefore = 5
    @AppStorage(Settings.Key.theme) private var theme = Theme.quiet.rawValue
    @AppStorage(Settings.Key.outlineStyle) private var outlineStyle = OutlineStyle.spentClockwise.rawValue
    @AppStorage(Settings.Key.counterStyle) private var counterStyle = CounterStyle.heart.rawValue
    @AppStorage(Settings.Key.showScore) private var showScore = false
    @AppStorage(Settings.Key.warnBlink) private var warnBlink = true
    @AppStorage(Settings.Key.outlineSpan) private var outlineSpan = 50
    @AppStorage(Settings.Key.beatNormal) private var beatNormal = 10
    @AppStorage(Settings.Key.beatWarning) private var beatWarning = 40
    @AppStorage(Settings.Key.beatOver) private var beatOver = 80
    @AppStorage(Settings.Key.beatWhileWorking) private var beatWhileWorking = false
    @State private var advancedExpanded = false

    private var currentCounter: CounterStyle { CounterStyle(rawValue: counterStyle) ?? .number }

    private var currentTheme: Theme { Theme(rawValue: theme) ?? .quiet }
    private var currentStyle: OutlineStyle { OutlineStyle(stored: outlineStyle) }

    var body: some View {
        Form {
            Section {
                MenuBarPreview(
                    theme: currentTheme,
                    style: currentStyle,
                    counterStyle: currentCounter,
                    span: Double(outlineSpan) / 100,
                    score: showScore || currentCounter == .heart ? previewScore : nil,
                    blink: warnBlink,
                    workLimit: workLimit,
                    warnBefore: warnBefore
                )
            }
            Section("Theme") {
                Picker("Theme", selection: $theme) {
                    ForEach(Theme.allCases) { Text($0.label).tag($0.rawValue) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                Text(currentTheme.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Menu bar item") {
                Picker("Show as", selection: $counterStyle) {
                    ForEach(CounterStyle.allCases) { Text($0.label).tag($0.rawValue) }
                }
                Picker("Outline shows", selection: outlineMode) {
                    ForEach(OutlineStyle.Mode.allCases) { Text($0.label).tag($0) }
                }
                if currentCounter != .heart {
                    Toggle("Weekly score heart beside it", isOn: $showScore)
                }
                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                DisclosureGroup("Advanced", isExpanded: $advancedExpanded) {
                    Picker("Direction", selection: outlineDirection) {
                        ForEach(OutlineStyle.Direction.allCases) { Text($0.label).tag($0) }
                    }
                    .disabled(currentStyle.mode == .off)
                    StepperRow(label: "A whole block covers", value: "\(outlineSpan)% of the outline",
                               number: $outlineSpan, range: 10...100, step: 5)
                        .disabled(currentStyle.mode == .off)
                    Toggle("Heartbeat", isOn: $warnBlink)
                    StepperRow(label: "Normal rate", value: "\(beatNormal) bpm", number: $beatNormal, range: 5...200, step: 5)
                        .disabled(!warnBlink)
                    StepperRow(label: "Warning rate", value: "\(beatWarning) bpm", number: $beatWarning, range: 5...200, step: 5)
                        .disabled(!warnBlink || warnBefore == 0)
                    StepperRow(label: "Over the limit", value: "\(beatOver) bpm", number: $beatOver, range: 5...200, step: 5)
                        .disabled(!warnBlink)
                    Toggle("Beat while working, not only in the warning", isOn: $beatWhileWorking)
                        .disabled(!warnBlink)
                    Text("A lub-dub. In the warning the rate climbs from the normal rate to the warning rate as the "
                         + "limit nears, then holds at the over rate. With Reduce Motion on it steps instead of fading.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var caption: String {
        switch currentCounter {
        case .heart:
            return "A gauge of this week's on-time share, like the battery icon, with the arc showing the block. "
                + "No colors: the blink carries the warning. The arc is gone while you rest."
        case .hidden:
            return "A dot in the state color, with the outline as a ring around it. The exact time is in the menu and the tooltip."
        default:
            return showScore
                ? "The heart beside the minutes fills with this week's on-time share, shown once a break has been due."
                : "The outline wraps the minutes and turns red once the limit is reached."
        }
    }

    /// This week's real score when there is one, otherwise a sample so the heart is visible.
    private var previewScore: Double {
        Stats.summary(period: .week, history: History.shared, live: nil, blockStart: nil).adherence ?? 0.75
    }

    private var outlineMode: Binding<OutlineStyle.Mode> {
        Binding(
            get: { currentStyle.mode },
            set: { mode in
                let direction = currentStyle == .off ? .clockwise : currentStyle.direction
                outlineStyle = OutlineStyle.make(mode: mode, direction: direction).rawValue
            }
        )
    }

    private var outlineDirection: Binding<OutlineStyle.Direction> {
        Binding(
            get: { currentStyle.direction },
            set: { outlineStyle = OutlineStyle.make(mode: currentStyle.mode, direction: $0).rawValue }
        )
    }
}

struct ReminderSettingsView: View {
    @AppStorage(Settings.Key.remindEvery) private var remindEvery = 10
    @AppStorage(Settings.Key.sound) private var sound = Settings.defaultSound
    @AppStorage(Settings.Key.workLimit) private var workLimit = 25
    @AppStorage(Settings.Key.reminderTitle) private var title = Settings.defaultReminderTitle
    @AppStorage(Settings.Key.reminderBody) private var body_ = Settings.defaultReminderBody
    @AppStorage(Settings.Key.firmnessMode) private var firmnessMode = FirmnessMode.automatic.rawValue
    @AppStorage(Settings.Key.autoFirmness) private var autoFirmness = Firmness.normal.rawValue
    @State private var testSent = false

    private var currentMode: FirmnessMode { FirmnessMode(rawValue: firmnessMode) ?? .automatic }
    private var currentLevel: Firmness { currentMode.fixed ?? Firmness(rawValue: autoFirmness) ?? .normal }

    var body: some View {
        Form {
            Section("Firmness") {
                Picker("Firmness", selection: $firmnessMode) {
                    Text(FirmnessMode.automatic.label).tag(FirmnessMode.automatic.rawValue)
                    Divider()
                    ForEach(Firmness.allCases) { Text($0.label).tag($0.rawValue) }
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(currentMode == .automatic ? "Now: \(currentLevel.label)" : currentLevel.label)
                    Text(currentLevel.summary)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if currentMode == .automatic {
                    Text("Automatic earns calm: 90% on time over the last 7 days means Gentle, 40 to 89 Normal, "
                         + "15 to 39 Firm. Below 15 the app steps down to Gentle and asks once whether to change "
                         + "the limit or pause. Re-evaluated daily once 5 breaks were due.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            Section("Reminder") {
                StepperRow(label: "Repeat while over the limit every", value: "\(remindEvery) min",
                           number: $remindEvery, range: 1...120)
                    .disabled(currentLevel == .gentle)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Title")
                    TextField("", text: $title, prompt: Text(Settings.defaultReminderTitle))
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                }
                VStack(alignment: .leading, spacing: 6) {
                    Text("Message")
                    TextField("", text: $body_, prompt: Text(Settings.defaultReminderBody), axis: .vertical)
                        .textFieldStyle(.roundedBorder)
                        .labelsHidden()
                        .lineLimit(2...4)
                    Text("{minutes} is the length of the work block, {rest} the rest threshold.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Picker("Sound", selection: $sound) {
                    Text("Off").tag("")
                    Divider()
                    ForEach(Settings.availableSounds, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .onChange(of: sound) { name in preview(name) }
                HStack {
                    Button("Restore Default Text") {
                        title = Settings.defaultReminderTitle
                        body_ = Settings.defaultReminderBody
                    }
                    .controlSize(.small)
                    Spacer()
                    Button(testSent ? "Sent" : "Send Test Notification") {
                        Notifier.shared.sendBreakReminder(minutes: workLimit)
                        testSent = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { testSent = false }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
    }

    private func preview(_ name: String) {
        guard !name.isEmpty else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }
}

struct SmartPauseSettingsView: View {
    @AppStorage(Settings.Key.smartPauseEnabled) private var enabled = true
    @AppStorage(Settings.Key.smartPauseCall) private var pauseCall = true
    @AppStorage(Settings.Key.smartPauseScreenShare) private var pauseShare = true
    @AppStorage(Settings.Key.smartPauseFullscreen) private var pauseFullscreen = false
    @AppStorage(Settings.Key.smartPauseGrace) private var grace = 2
    @State private var detected = SmartPause.detectAll()

    private let refresh = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        Form {
            Section {
                Toggle(isOn: $enabled) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Smart Pause").font(.headline)
                        Text("Hold reminders, sound and blink when a notification would get in the way. "
                             + "The counter and outline keep going.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
            }
            Section("Hold reminders while") {
                TriggerRow(title: "Camera or microphone in use", detail: "Zoom, Meet, Teams, FaceTime, huddles.",
                           isOn: $pauseCall, detected: detected.call)
                TriggerRow(title: "Screen sharing or recording", detail: "Zoom share and macOS screen recording.",
                           isOn: $pauseShare, detected: detected.screenShare)
                TriggerRow(title: "Fullscreen app in front", detail: "Video, games, presentations. Also a fullscreen editor, so off by default.",
                           isOn: $pauseFullscreen, detected: detected.fullscreen)
            }
            .disabled(!enabled)
            Section {
                Text("Focus modes are not listed because macOS only reveals them to apps with Full Disk Access. "
                     + "Banners are already silenced by Focus itself.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("After a pause ends") {
                StepperRow(label: "Wait before an overdue reminder", value: grace == 0 ? "No wait" : "\(grace) min",
                           number: $grace, range: 0...15)
                Text("If you are over the limit when the pause ends, the reminder fires after this wait, "
                     + "unless a rest has started by then.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!enabled)
        }
        .formStyle(.grouped)
        .scrollDisabled(true)
        .fixedSize(horizontal: false, vertical: true)
        .onReceive(refresh) { _ in detected = SmartPause.detectAll() }
    }
}

/// A trigger toggle with a live "detected now" indicator, so the feature can be verified rather than trusted.
private struct TriggerRow: View {
    let title: String
    let detail: String
    @Binding var isOn: Bool
    let detected: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if detected {
                    Label("Now", systemImage: "circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
    }
}

struct AboutView: View {
    @State private var copied = false
    @State private var confirmReset = false

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 4) {
                Text("Break Reminder").font(.title2).bold()
                Text("\(Feedback.versionString) · \(Feedback.installMethod)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Text("Counts how long you have been working from keyboard, mouse and trackpad activity "
                 + "and reminds you to take a break. No keystrokes are recorded.")
                .font(.callout)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 360)

            HStack(spacing: 12) {
                Button("Request a Feature…") { Feedback.requestFeature() }
                Button("Report a Bug…") { Feedback.reportBug() }
            }
            HStack(spacing: 12) {
                Button("Release Notes") { Feedback.openReleaseNotes() }
                Button("Project on GitHub") { Feedback.openRepository() }
            }
            Button(copied ? "Copied" : "Copy Homebrew Install Command") {
                Feedback.copyInstallCommand()
                copied = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
            }
            .font(.callout)
            Text("MIT License").font(.caption).foregroundStyle(.tertiary)

            Button("Reset All Settings…", role: .destructive) { confirmReset = true }
                .controlSize(.small)
                .padding(.top, 8)
                .confirmationDialog(
                    "Reset all settings to their defaults?",
                    isPresented: $confirmReset,
                    titleVisibility: .visible
                ) {
                    Button("Reset All Settings", role: .destructive) { Settings.resetAll() }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Timer values, appearance, reminder text and sound go back to their defaults. "
                         + "The current work block and history are kept. This cannot be undone.")
                }
        }
        .padding(24)
    }
}
