import AppKit
import SwiftUI

final class StatsWindowController: NSWindowController {
    convenience init() {
        let view = StatsView(history: History.shared, liveProvider: {
            (Feedback.snapshotProvider(), Feedback.blockStartProvider())
        })
        let hosting = NSHostingController(rootView: view)
        hosting.sizingOptions = [.preferredContentSize]
        let window = NSWindow(contentViewController: hosting)
        window.title = "Stats"
        window.subtitle = "Break Reminder"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        self.init(window: window)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if window?.isVisible != true { window?.center() }
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
    }
}
