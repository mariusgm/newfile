import Cocoa
import FinderSync
import os

private let log = Logger(subsystem: "dev.newfile.NewFile", category: "extension")

final class FinderSync: FIFinderSync {

    private let settings: SettingsStore? = SettingsStore.appGroupStore()

    // Snapshot of entries indexed by NSMenuItem.tag at menu-construction time.
    // representedObject can't carry a Swift struct across the FinderSync XPC bridge,
    // so the action handler looks the entry up by tag instead.
    private var menuEntrySnapshot: [FileTypeEntry] = []

    override init() {
        super.init()
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
        log.info("FinderSync init")
    }

    // MARK: - Toolbar item

    override var toolbarItemName: String { "NewFile" }

    override var toolbarItemToolTip: String { "Create a new file in this folder" }

    override var toolbarItemImage: NSImage {
        Self.toolbarIcon(accessibility: "New File")
    }

    // MARK: - Menus

    override func menu(for menu: FIMenuKind) -> NSMenu? {
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
            title: entry.displayName,
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
        let bundle = Bundle(for: FinderSync.self)
        if let image = bundle.image(forResource: "ToolbarIcon") {
            image.isTemplate = true
            image.accessibilityDescription = accessibility
            return image
        }
        let fallback = NSImage(systemSymbolName: "square.and.pencil",
                               accessibilityDescription: accessibility)
            ?? NSImage()
        fallback.isTemplate = true
        return fallback
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
        log.info("create entry=\(entry.displayName, privacy: .public) ext=\(entry.ext, privacy: .public)")
        DistributedNotificationCenter.default().postNotificationName(
            NewFileNotification.toolbarOrMenuUsed,
            object: nil, userInfo: nil, deliverImmediately: true
        )

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
