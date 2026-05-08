import Foundation

final class SettingsStore {
    static let appGroupID = "group.dev.newfile.NewFile"

    private enum Key {
        static let fileTypes = "fileTypes"
        static let submenu = "useRightClickSubmenu"
        static let schema = "schemaVersion"
    }

    private static let currentSchema = 1

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
                return decoded
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

    private func persist(_ types: [FileTypeEntry]) {
        guard let data = try? JSONEncoder().encode(types) else { return }
        defaults.set(data, forKey: Key.fileTypes)
    }
}
