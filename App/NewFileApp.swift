import AppKit
import os
import Sparkle
import SwiftUI

// SPIKE (issue #5), Route 2: a Services entry. Never ships as is.
private let spikeLog = Logger(subsystem: "dev.newfile.NewFile.spike", category: "service")

@main
struct NewFileApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    private static let sponsorsURL = URL(string: "https://github.com/sponsors/mariusgm")!

    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    var body: some Scene {
        WindowGroup("NewFile") {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(after: .appInfo) {
                Button("Check for Updates…") {
                    updaterController.checkForUpdates(nil)
                }
                Divider()
                // Tip link only: opens the GitHub Sponsors page in the browser.
                // Leave it out of any Mac App Store build (App Review 3.1.1).
                Button("Support NewFile…") {
                    NSWorkspace.shared.open(Self.sponsorsURL)
                }
                Button("Uninstall NewFile…") {
                    UninstallHelper.run()
                }
            }
            // One Settings window for every entry point (see
            // PreferencesWindowController); no SwiftUI Settings scene.
            CommandGroup(replacing: .appSettings) {
                Button("Settings…") {
                    PreferencesWindowController.shared.show()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
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

        NSApp.servicesProvider = self
        NSUpdateDynamicServices()
        spikeLog.info("servicesProvider registered")
    }

    /// NSServices provider for "New Text File Here" (NSMessage `newTextFileHere`).
    /// The folder arrives as a file URL on the service pasteboard.
    @objc func newTextFileHere(
        _ pboard: NSPasteboard,
        userData: String,
        error: AutoreleasingUnsafeMutablePointer<NSString>
    ) {
        let urls = (pboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ) as? [URL]) ?? []
        let types = (pboard.types ?? []).map(\.rawValue).joined(separator: ",")
        spikeLog.info("service invoked urls=\(urls.count) first=\(urls.first?.path ?? "nil", privacy: .public) types=\(types, privacy: .public)")
        guard let directory = urls.first else {
            error.pointee = "No folder on the service pasteboard."
            return
        }
        let scoped = directory.startAccessingSecurityScopedResource()
        defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
        let url = FilenameGenerator.uniqueFileURL(in: directory, baseName: "New Text File", ext: "txt")
        do {
            try Data().write(to: url, options: [.withoutOverwriting])
            spikeLog.info("service created file=\(url.path, privacy: .public) scoped=\(scoped)")
        } catch let failure {
            spikeLog.error("service create failed scoped=\(scoped) path=\(url.path, privacy: .public) error=\(String(describing: failure), privacy: .public)")
            error.pointee = failure.localizedDescription as NSString
        }
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
