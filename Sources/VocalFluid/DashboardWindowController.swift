import AppKit
import SwiftUI

@MainActor
public final class DashboardWindowController: NSObject, NSWindowDelegate {
    public static let shared = DashboardWindowController()

    private var window: NSWindow?

    public override init() {
        super.init()
    }

    public func show() {
        NSApp.setActivationPolicy(.regular)

        if window == nil {
            let dashboard = DashboardView()
            let hosting = NSHostingController(rootView: dashboard)
            let win = NSWindow(contentViewController: hosting)
            win.title = "VocalFluid"
            win.subtitle = "On-Device Dictation"
            win.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            win.titlebarAppearsTransparent = true
            win.titleVisibility = .hidden
            win.isReleasedWhenClosed = false
            win.delegate = self
            win.minSize = NSSize(width: 960, height: 600)
            win.setContentSize(NSSize(width: 1040, height: 680))
            self.window = win
        }

        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    public func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    public func toggle() {
        if let window, window.isVisible {
            window.orderOut(nil)
            NSApp.setActivationPolicy(.accessory)
        } else {
            show()
        }
    }
}
