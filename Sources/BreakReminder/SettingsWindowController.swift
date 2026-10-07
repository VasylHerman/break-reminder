import AppKit
import SwiftUI

/// Hosts the SwiftUI settings form in a single reusable window.
final class SettingsWindowController: NSWindowController {
    convenience init() {
        let hosting = NSHostingController(rootView: SettingsView())
        let window = NSWindow(contentViewController: hosting)
        window.title = "Break Reminder Settings"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func show() {
        // The app is an accessory (no Dock icon), so activate explicitly to bring the window forward.
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
