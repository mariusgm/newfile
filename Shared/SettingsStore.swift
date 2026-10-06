import Foundation

final class SettingsStore {
    // macOS requires app-group IDs to be Team-ID-prefixed; an iOS-style
    // "group." identifier makes containermanagerd gate the shared container
    // behind TCC (host-app prompt + extension rejection). Team ID: Q7VD7MTRL8.
    static let appGroupID = "Q7VD7MTRL8.dev.newfile.NewFile"

    private enum Key {
        static let fileTypes = "fileTypes"
        static let submenu = "useRightClickSubmenu"
        static let schema = "schemaVersion"
        static let pendingOpenPreferences = "pendingOpenPreferences"
    }

    private static let currentSchema = 3

    private let defaults: UserDefaults

    /// Production callers pass `UserDefaults(suiteName: SettingsStore.appGroupID)!`.
    /// Tests pass an isolated suite.
    init(defaults: UserDefaults) {
        self.defaults = defaults
    }

    /// Convenience factory for production use. Returns nil if the App Group
    /// suite is not entitled — caller decides how to surface the error.
    static func appGroupStore() -> SettingsStore? {
        guard let suite = UserDefaults(suiteName: appGroupID) else { return nil }
        return SettingsStore(defaults: suite)
    }

    var fileTypes: [FileTypeEntry] {
        get {
            if let data = defaults.data(forKey: Key.fileTypes),
               let decoded = try? JSONDecoder().decode([FileTypeEntry].self, from: data) {
                return migrateIfNeeded(decoded)
            }
            // First read or corrupted JSON — seed and persist.
            let seeded = SeedPresets.builtIns
            persist(seeded)
            defaults.set(Self.currentSchema, forKey: Key.schema)
            return seeded
        }
        set {
            persist(newValue)
        }
    }

    var enabledTypes: [FileTypeEntry] {
        fileTypes.filter { $0.enabled }
    }

    var useRightClickSubmenu: Bool {
        get { defaults.bool(forKey: Key.submenu) }
        set { defaults.set(newValue, forKey: Key.submenu) }
    }

    /// Latch flipped by the extension before `NSWorkspace.shared.open(host)`.
    /// AppDelegate consumes-and-clears on launch so the host app shows
    /// Preferences instead of the welcome window when launched via the
    /// extension's "Customize…" / empty-list-recovery row. The distributed
    /// notification alone can't carry this intent across launch because the
    /// observer registers after the notification has already been posted.
    var pendingOpenPreferences: Bool {
        get { defaults.bool(forKey: Key.pendingOpenPreferences) }
        set { defaults.set(newValue, forKey: Key.pendingOpenPreferences) }
    }

    /// Schema 1 -> 2: custom types were created with a hardcoded displayName
    /// of "New file" and no UI to change it (issue #2). Blank those out so the
    /// menu falls back to the ext-derived label.
    /// Schema 2 -> 3: append the RTF built-in (issue #4) — the seed only runs on
    /// first read, so existing stores never got it. Skipped when the user already
    /// has an .rtf type of their own.
    /// Each step runs once, keyed on schemaVersion, so later user edits stick.
    private func migrateIfNeeded(_ types: [FileTypeEntry]) -> [FileTypeEntry] {
        let schema = defaults.integer(forKey: Key.schema)
        guard schema < Self.currentSchema else { return types }
        var migrated = types
        if schema < 2 {
            for i in migrated.indices
            where !migrated[i].isBuiltIn && migrated[i].displayName == "New file" {
                migrated[i].displayName = ""
            }
        }
        if schema < 3, !migrated.contains(where: { $0.ext == SeedPresets.rtf.ext }) {
            migrated.append(SeedPresets.rtf)
        }
        if migrated != types { persist(migrated) }
        defaults.set(Self.currentSchema, forKey: Key.schema)
        return migrated
    }

    private func persist(_ types: [FileTypeEntry]) {
        guard let data = try? JSONEncoder().encode(types) else { return }
        defaults.set(data, forKey: Key.fileTypes)
    }
}
