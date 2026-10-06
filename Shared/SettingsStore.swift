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
                return ensureBuiltIns(migrateIfNeeded(decoded))
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
    /// Schema 3 (0.2.4) adds the RTF built-in; that is handled by
    /// `ensureBuiltIns`, not here, so the stamp only marks the version.
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
        if migrated != types { persist(migrated) }
        defaults.set(Self.currentSchema, forKey: Key.schema)
        return migrated
    }

    /// Appends any built-in preset missing from the store (disabled, as seeded).
    /// The seed only runs on first read, so presets added in later versions
    /// (RTF, issue #4) reach existing users here. Built-ins can't be deleted or
    /// have their extension edited in the UI, so a missing one is never a user
    /// choice. Runs on every read rather than once: a one-shot step that skipped
    /// users with a custom .rtf stranded them with no RTF type after they
    /// deleted it. A custom type with the same extension is kept alongside.
    private func ensureBuiltIns(_ types: [FileTypeEntry]) -> [FileTypeEntry] {
        let missing = SeedPresets.builtIns.filter { preset in
            !types.contains { $0.isBuiltIn && $0.ext == preset.ext }
        }
        guard !missing.isEmpty else { return types }
        let restored = types + missing
        persist(restored)
        return restored
    }

    private func persist(_ types: [FileTypeEntry]) {
        guard let data = try? JSONEncoder().encode(types) else { return }
        defaults.set(data, forKey: Key.fileTypes)
    }
}
