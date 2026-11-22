import Cocoa
import FinderSync
import os

private let log = Logger(subsystem: "dev.newfile.NewFile", category: "extension")

// SPIKE (issue #5): which folders the extension claims. Switched at runtime by a
// distributed notification so one build covers every route; never ships.
private let spikeLog = Logger(subsystem: "dev.newfile.NewFile.spike", category: "extension")

enum SpikeMode: String {
    case root = "root"                    // shipping behaviour: ["/"]
    case rootPlusICloud = "root+icloud"   // Route 1: "/" plus the iCloud Drive folders
    case iCloudOnly = "icloud-only"       // Route 1-only: just the iCloud Drive folders

    static let defaultsKey = "spikeMode"
    static let changed = Notification.Name("dev.newfile.NewFile.spike.mode")
}

final class FinderSync: FIFinderSync {

    private let settings: SettingsStore? = SettingsStore.appGroupStore()

    // Snapshot of entries indexed by NSMenuItem.tag at menu-construction time.
    // representedObject can't carry a Swift struct across the FinderSync XPC bridge,
    // so the action handler looks the entry up by tag instead.
    private var menuEntrySnapshot: [FileTypeEntry] = []

    override init() {
        super.init()
        let saved = UserDefaults.standard.string(forKey: SpikeMode.defaultsKey) ?? ""
        applySpikeMode(SpikeMode(rawValue: saved) ?? .rootPlusICloud, reason: "init")
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(spikeModeChanged(_:)),
            name: SpikeMode.changed, object: nil,
            suspensionBehavior: .deliverImmediately
        )
        log.info("FinderSync init")
    }

    // MARK: - Spike (issue #5)

    /// The sandbox reports the container as home; iCloud Drive lives under the real one.
    private static func realHome() -> URL {
        if let pw = getpwuid(getuid()), let dir = pw.pointee.pw_dir {
            return URL(fileURLWithFileSystemRepresentation: dir, isDirectory: true, relativeTo: nil)
        }
        return FileManager.default.homeDirectoryForCurrentUser
    }

    private static func iCloudURLs() -> [URL] {
        let home = realHome()
        return [
            home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true),
            home.appendingPathComponent("Desktop", isDirectory: true),
            home.appendingPathComponent("Documents", isDirectory: true),
        ]
    }

    private var spikeMode: SpikeMode = .rootPlusICloud

    private func applySpikeMode(_ mode: SpikeMode, reason: String) {
        let root = URL(fileURLWithPath: "/")
        let urls: Set<URL>
        switch mode {
        case .root: urls = [root]
        case .rootPlusICloud: urls = Set([root] + Self.iCloudURLs())
        case .iCloudOnly: urls = Set(Self.iCloudURLs())
        }
        spikeMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: SpikeMode.defaultsKey)
        FIFinderSyncController.default().directoryURLs = urls
        let paths = urls.map(\.path).sorted().joined(separator: " | ")
        spikeLog.info("mode=\(mode.rawValue, privacy: .public) reason=\(reason, privacy: .public) directoryURLs=\(paths, privacy: .public)")
    }

    @objc private func spikeModeChanged(_ note: Notification) {
        guard let raw = note.object as? String, let mode = SpikeMode(rawValue: raw) else {
            spikeLog.error("mode notification ignored object=\(String(describing: note.object), privacy: .public)")
            return
        }
        applySpikeMode(mode, reason: "notification")
    }

    override func beginObservingDirectory(at url: URL) {
        spikeLog.info("beginObserving mode=\(self.spikeMode.rawValue, privacy: .public) url=\(url.path, privacy: .public)")
    }

    override func endObservingDirectory(at url: URL) {
        spikeLog.info("endObserving url=\(url.path, privacy: .public)")
    }

    // MARK: - Toolbar item

    override var toolbarItemName: String { "NewFile" }

    override var toolbarItemToolTip: String { "Create a new file in this folder" }

    override var toolbarItemImage: NSImage {
        Self.toolbarIcon(accessibility: "New File")
    }

    // MARK: - Menus

    override func menu(for menu: FIMenuKind) -> NSMenu? {
        let controller = FIFinderSyncController.default()
        let target = controller.targetedURL()?.path ?? "nil"
        let selected = controller.selectedItemURLs()?.count ?? -1
        spikeLog.info("menu kind=\(menu.rawValue) mode=\(self.spikeMode.rawValue, privacy: .public) target=\(target, privacy: .public) selected=\(selected)")
        switch menu {
        case .contextualMenuForItems:
            return nil
        case .toolbarItemMenu:
            return buildToolbarMenu()
        default:
            return buildContextMenu()
        }
    }

    private func buildToolbarMenu() -> NSMenu {
        let menu = NSMenu(title: "")
        menuEntrySnapshot = []
        let entries = settings?.enabledTypes ?? []
        if entries.isEmpty {
            appendEmptyRow(to: menu)
        } else {
            for entry in entries { addRow(for: entry, to: menu) }
        }
        menu.addItem(NSMenuItem.separator())
        appendCustomizeRow(to: menu)
        return menu
    }

    private func buildContextMenu() -> NSMenu {
        let menu = NSMenu(title: "")
        menuEntrySnapshot = []
        let entries = settings?.enabledTypes ?? []
        if entries.isEmpty {
            appendEmptyRow(to: menu)
            return menu
        }
        if settings?.useRightClickSubmenu == true {
            let parent = NSMenuItem(title: "New File", action: nil, keyEquivalent: "")
            parent.image = Self.menuIcon()
            let sub = NSMenu(title: "")
            for entry in entries { addRow(for: entry, to: sub) }
            parent.submenu = sub
            menu.addItem(parent)
        } else {
            for entry in entries { addRow(for: entry, to: menu) }
        }
        return menu
    }

    private func appendCustomizeRow(to menu: NSMenu) {
        let item = NSMenuItem(
            title: "Customize…",
            action: #selector(openPreferences(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
    }

    private func appendEmptyRow(to menu: NSMenu) {
        let item = NSMenuItem(
            title: "Enable a file type in NewFile…",
            action: #selector(openPreferences(_:)),
            keyEquivalent: ""
        )
        item.target = self
        menu.addItem(item)
    }

    @objc func openPreferences(_ sender: AnyObject?) {
        log.info("openPreferences requested")
        // Latch the launch-intent BEFORE posting the notification + opening
        // the host. If the app is already running, the observer fires and
        // clears the latch immediately. If the app needs to launch, the
        // notification beats the observer's registration; the AppDelegate
        // checks-and-clears the latch on launch as a fallback.
        settings?.pendingOpenPreferences = true
        DistributedNotificationCenter.default().postNotificationName(
            NewFileNotification.openPreferences,
            object: nil, userInfo: nil, deliverImmediately: true
        )
        if let url = hostAppURL() {
            NSWorkspace.shared.open(url)
        }
    }

    private func hostAppURL() -> URL? {
        // Extension bundle is .../NewFile.app/Contents/PlugIns/NewFileExtension.appex.
        // Walk up four levels to land on the host app.
        let bundle = Bundle(for: FinderSync.self).bundleURL
        return bundle
            .deletingLastPathComponent()  // PlugIns
            .deletingLastPathComponent()  // Contents
            .deletingLastPathComponent()  // NewFile.app
    }

    private func addRow(for entry: FileTypeEntry, to menu: NSMenu) {
        let item = NSMenuItem(
            title: entry.menuTitle,
            action: #selector(createFromMenuItem(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.image = Self.menuIcon()
        item.tag = menuEntrySnapshot.count
        menuEntrySnapshot.append(entry)
        menu.addItem(item)
    }

    private static func toolbarIcon(accessibility: String?) -> NSImage {
        let image = NSImage(systemSymbolName: "square.and.pencil",
                            accessibilityDescription: accessibility)
            ?? NSImage()
        image.isTemplate = true
        return image
    }

    private static func menuIcon() -> NSImage {
        guard let base = NSImage(systemSymbolName: "square.and.pencil",
                                 accessibilityDescription: "New File") else {
            return NSImage()
        }
        let config = NSImage.SymbolConfiguration(paletteColors: [.labelColor])
        return base.withSymbolConfiguration(config) ?? base
    }

    // MARK: - Actions

    @objc func createFromMenuItem(_ sender: AnyObject?) {
        guard let item = sender as? NSMenuItem,
              menuEntrySnapshot.indices.contains(item.tag) else {
            log.error("createFromMenuItem: tag \(((sender as? NSMenuItem)?.tag ?? -1)) out of range (snapshot=\(self.menuEntrySnapshot.count))")
            NSSound.beep()
            return
        }
        performCreate(entry: menuEntrySnapshot[item.tag])
    }

    private func performCreate(entry: FileTypeEntry) {
        log.info("create entry=\(entry.menuTitle, privacy: .public) ext=\(entry.ext, privacy: .public)")

        let controller = FIFinderSyncController.default()
        let target = controller.targetedURL()
        let selected = controller.selectedItemURLs()

        guard let directory = directoryForCreation(target: target, selected: selected) else {
            log.error("No target directory available")
            NSSound.beep()
            return
        }

        do {
            let url = try createFile(for: entry, in: directory)
            log.info("created file=\(url.path, privacy: .public)")
            // Posted only after a successful write: the setup window's step 2
            // checkmark reads this as "NewFile has created a file".
            DistributedNotificationCenter.default().postNotificationName(
                NewFileNotification.toolbarOrMenuUsed,
                object: nil, userInfo: nil, deliverImmediately: true
            )
            revealFile(at: url)
        } catch {
            log.error("create failed: \(error.localizedDescription, privacy: .public)")
            NSSound.beep()
        }
    }

    // MARK: - Helpers

    private func createFile(for entry: FileTypeEntry, in directory: URL) throws -> URL {
        let url = FilenameGenerator.uniqueFileURL(
            in: directory, baseName: entry.baseName, ext: entry.ext
        )
        let scoped = directory.startAccessingSecurityScopedResource()
        defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
        let data = entry.template.data(using: .utf8) ?? Data()
        try data.write(to: url, options: [.withoutOverwriting])
        return url
    }

    private func directoryForCreation(target: URL?, selected: [URL]?) -> URL? {
        if let target { return resolvedDirectory(for: target) }
        if let first = selected?.first { return resolvedDirectory(for: first) }
        return nil
    }

    private func resolvedDirectory(for url: URL) -> URL {
        var isDir: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir),
           isDir.boolValue {
            return url
        }
        return url.deletingLastPathComponent()
    }

    private func revealFile(at url: URL) {
        NSWorkspace.shared.selectFile(
            url.path,
            inFileViewerRootedAtPath: url.deletingLastPathComponent().path
        )
    }
}
