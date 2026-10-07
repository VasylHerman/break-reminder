import AppKit
import SwiftUI

/// Preferences-style window: icon tabs in the toolbar, each pane a SwiftUI view,
/// and the window resizes to the selected pane.
final class SettingsWindowController: NSWindowController, NSWindowDelegate {
    private let tabs = NSTabViewController()

    convenience init() {
        let tabs = NSTabViewController()
        tabs.tabStyle = .toolbar
        tabs.canPropagateSelectedChildViewControllerTitle = true

        let panes: [(title: String, symbol: String, view: AnyView)] = [
            ("General", "gearshape", AnyView(GeneralSettingsView())),
            ("Reminders", "bell", AnyView(ReminderSettingsView())),
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
        tabs.selectedTabViewItemIndex = 0

        let window = NSWindow(contentViewController: tabs)
        window.styleMask = [.titled, .closable]
        window.toolbarStyle = .preference
        window.title = "General"
        window.subtitle = "Break Reminder"
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func show() {
        // The app is an accessory (no Dock icon), so activate explicitly to bring the window forward.
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible != true { window?.center() }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
