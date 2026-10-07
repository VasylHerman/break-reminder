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
    @AppStorage(Settings.Key.workLimit) private var workLimit = 45
    @AppStorage(Settings.Key.restThreshold) private var restThreshold = 5
    @AppStorage(Settings.Key.warnBefore) private var warnBefore = 5
    @AppStorage(Settings.Key.warnBlink) private var warnBlink = true
    @AppStorage(Settings.Key.outlineStyle) private var outlineStyle = OutlineStyle.leftClockwise.rawValue
    @AppStorage(Settings.Key.showUnit) private var showUnit = false
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
            Section("Menu bar") {
                MenuBarPreview(
                    style: OutlineStyle(stored: outlineStyle),
                    showUnit: showUnit,
                    blink: warnBlink,
                    workLimit: workLimit,
                    warnBefore: warnBefore
                )
                Picker("Outline", selection: $outlineStyle) {
                    Text(OutlineStyle.off.label).tag(OutlineStyle.off.rawValue)
                    Divider()
                    ForEach(OutlineStyle.allCases.filter { $0 != .off && !$0.isTimeLeft }) { style in
                        Text(style.label).tag(style.rawValue)
                    }
                    Divider()
                    ForEach(OutlineStyle.allCases.filter { $0.isTimeLeft }) { style in
                        Text(style.label).tag(style.rawValue)
                    }
                }
                Toggle("Show minutes unit (23m instead of 23)", isOn: $showUnit)
                Toggle("Blink the counter during the warning", isOn: $warnBlink)
                    .disabled(warnBefore == 0)
                Text("The outline closes in red once the limit is reached. "
                     + "While blinking, the pace follows the minutes left: every 5 seconds at 5 minutes, "
                     + "every second at 1 minute and past the limit.")
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

struct ReminderSettingsView: View {
    @AppStorage(Settings.Key.remindEvery) private var remindEvery = 10
    @AppStorage(Settings.Key.sound) private var sound = Settings.defaultSound
    @AppStorage(Settings.Key.workLimit) private var workLimit = 45
    @AppStorage(Settings.Key.reminderTitle) private var title = Settings.defaultReminderTitle
    @AppStorage(Settings.Key.reminderBody) private var body_ = Settings.defaultReminderBody
    @State private var testSent = false

    var body: some View {
        Form {
            Section("Reminder") {
                StepperRow(label: "Repeat while over the limit every", value: "\(remindEvery) min",
                           number: $remindEvery, range: 1...120)
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
                    Button("Restore Defaults") {
                        title = Settings.defaultReminderTitle
                        body_ = Settings.defaultReminderBody
                        sound = Settings.defaultSound
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

struct AboutView: View {
    @State private var copied = false

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
        }
        .padding(24)
    }
}
