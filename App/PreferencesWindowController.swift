import AppKit
import SwiftUI

/// Owns the one Settings window. Every entry point opens this window:
/// NewFile → Settings… (⌘,), the setup window's Customize File Types…, and the
/// extension's Customize… (via the openPreferences notification or launch latch).
///
/// Closing the window discards it, so the next open reads the saved settings
/// again. Two windows, or one window kept from an earlier open, each held their
/// own copy of the list, and saving one could undo a change made in the other.
@MainActor
final class PreferencesWindowController: NSObject, NSWindowDelegate {
    static let shared = PreferencesWindowController()

    private static let frameName = "NewFileSettingsWindow"

    private var window: NSWindow?
    private var model: PreferencesViewModel?

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        if let window {
            // Already open: bring it forward and leave the user's focus alone.
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            return
        }
        let model = PreferencesViewModel()
        let view = PreferencesView(vm: model, onDone: { [weak self] in
            self?.window?.performClose(nil)
        })
        let win = NSWindow(contentViewController: NSHostingController(rootView: view))
        win.title = "NewFile Settings"
        win.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        win.setContentSize(NSSize(width: 660, height: 560))
        win.isReleasedWhenClosed = false
        win.delegate = self
        if !win.setFrameUsingName(Self.frameName) { win.center() }
        win.setFrameAutosaveName(Self.frameName)
        self.window = win
        self.model = model
        win.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        // Save now: an edit still inside the model's 300 ms debounce would be
        // dropped when the model is released.
        model?.persist()
        window?.delegate = nil
        window = nil
        model = nil
    }
}
