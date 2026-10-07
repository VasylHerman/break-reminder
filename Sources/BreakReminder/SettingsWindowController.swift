import AppKit
import SwiftUI

/// Preferences-style window: icon tabs in the toolbar, each pane a SwiftUI view,
/// and the window resizes to the selected pane. Stats is the first pane.
final class SettingsWindowController: NSWindowController {
    enum Pane: Int {
        case stats, general, appearance, reminders, smartPause, about
    }

    private let tabs = NSTabViewController()

    convenience init() {
        self.init(window: nil)
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = true

        let panes: [(title: String, symbol: String, view: AnyView)] = [
            ("Stats", "chart.bar", AnyView(StatsView(history: History.shared, liveProvider: {
                (Feedback.snapshotProvider(), Feedback.blockStartProvider())
            }))),
            ("General", "gearshape", AnyView(GeneralSettingsView())),
            ("Appearance", "paintbrush", AnyView(AppearanceSettingsView())),
            ("Reminders", "bell", AnyView(ReminderSettingsView())),
            ("Smart Pause", "pause.circle", AnyView(SmartPauseSettingsView())),
            ("About", "info.circle", AnyView(AboutView())),
        ]
        for pane in panes {
            let host = NSHostingController(rootView: pane.view.frame(width: 460))
            host.title = pane.title
            host.sizingOptions = [.preferredContentSize]
            let item = NSTabViewItem(viewController: host)
            item.image = NSImage(systemSymbolName: pane.symbol, accessibilityDescription: pane.title)
            tabs.addTabViewItem(item)
        }
        tabs.selectedTabViewItemIndex = Pane.general.rawValue

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.title = "General"
        window.subtitle = "Break Reminder"
        window.isReleasedWhenClosed = false
        window.center()
        self.window = window
    }

    /// Opens the window on a pane. The app is an accessory (no Dock icon), so it activates explicitly.
    func show(pane: Pane) {
        tabs.selectedTabViewItemIndex = pane.rawValue
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible != true { window?.center() }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
