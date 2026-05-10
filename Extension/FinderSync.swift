import Cocoa
import FinderSync
import os

private let log = Logger(subsystem: "dev.newfile.NewFile", category: "extension")

final class FinderSync: FIFinderSync {

    private let settings: SettingsStore? = SettingsStore.appGroupStore()

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
        let nsMenu = NSMenu(title: "")
        let entries = settings?.enabledTypes ?? []

        if let primary = entries.first {
            addRow(for: primary, to: nsMenu)
        } else {
            // Fallback when no settings available or all disabled.
            let item = NSMenuItem(
                title: "New Text File",
                action: #selector(createDefaultFile(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.image = Self.menuIcon()
            nsMenu.addItem(item)
        }
        return nsMenu
    }

    private func addRow(for entry: FileTypeEntry, to menu: NSMenu) {
        let item = NSMenuItem(
            title: entry.displayName,
            action: #selector(createFromMenuItem(_:)),
            keyEquivalent: ""
        )
        item.target = self
        item.image = Self.menuIcon()
        item.representedObject = entry
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

    @objc func createDefaultFile(_ sender: AnyObject?) {
        // Used only when no settings/entries available — replicate legacy behavior.
        let fallback = FileTypeEntry(
            ext: "txt", baseName: "New Text File",
            displayName: "New Text File", isBuiltIn: true
        )
        performCreate(entry: fallback)
    }

    @objc func createFromMenuItem(_ sender: AnyObject?) {
        guard let item = sender as? NSMenuItem,
              let entry = item.representedObject as? FileTypeEntry else {
            log.error("createFromMenuItem: missing representedObject")
            NSSound.beep()
            return
        }
        performCreate(entry: entry)
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
