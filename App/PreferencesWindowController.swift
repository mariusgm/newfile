import AppKit
import SwiftUI

/// Owns a single Preferences window. Used by the openPreferences distributed
/// notification when the host app is launched headlessly by the extension.
@MainActor
final class PreferencesWindowController {
    static let shared = PreferencesWindowController()

    private var window: NSWindow?

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            window.makeKeyAndOrderFront(nil)
            return
        }
        let host = NSHostingController(rootView: PreferencesView())
        let win = NSWindow(contentViewController: host)
        win.title = "NewFile Preferences"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.setContentSize(NSSize(width: 520, height: 560))
        win.center()
        win.isReleasedWhenClosed = false
        self.window = win
        win.makeKeyAndOrderFront(nil)
    }
}
