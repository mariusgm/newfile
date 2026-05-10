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
    }
}
