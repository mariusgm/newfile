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
            Task { @MainActor in
                PreferencesWindowController.shared.show()
            }
        }
    }
}
