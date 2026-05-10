import AppKit
import SwiftUI

@main
struct NewFileApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup("NewFile") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)

        Settings {
            PreferencesView()
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DistributedNotificationCenter.default().addObserver(
            forName: NewFileNotification.openPreferences,
            object: nil,
            queue: .main
        ) { _ in
            // Clear the latch so a later cold launch doesn't replay this.
            SettingsStore.appGroupStore()?.pendingOpenPreferences = false
            Task { @MainActor in
                PreferencesWindowController.shared.show()
            }
        }

        // Consume the launch latch set by the extension. The distributed
        // notification posted right before NSWorkspace.shared.open lands
        // before this observer registers, so when the app is launched cold
        // the notification is missed — the latch is the durable handoff.
        if let store = SettingsStore.appGroupStore(), store.pendingOpenPreferences {
            store.pendingOpenPreferences = false
            Task { @MainActor in
                PreferencesWindowController.shared.show()
            }
        }

        verifyAppGroup()
    }

    private func verifyAppGroup() {
        if SettingsStore.appGroupStore() == nil {
            let alert = NSAlert()
            alert.messageText = "NewFile is misconfigured"
            alert.informativeText = """
                NewFile can't reach its shared settings store. \
                This usually means the app needs to be reinstalled. \
                Settings won't sync between the app and the Finder extension until this is fixed.
                """
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }
}
