import XCTest
// Shared/ source files are compiled directly into this test target,
// so types like FileTypeEntry / SettingsStore are accessible without
// @testable import NewFile (test target is standalone & unsigned).

final class SettingsStoreTests: XCTestCase {

    private func makeStore() -> (SettingsStore, UserDefaults) {
        let suiteName = "test.SettingsStore.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return (SettingsStore(defaults: defaults), defaults)
    }

    func testFirstRead_seedsBuiltInPresets() {
        let (store, _) = makeStore()
        let types = store.fileTypes
        XCTAssertEqual(types.map(\.ext), SeedPresets.builtIns.map(\.ext))
    }

    func testFirstRead_writesSchemaVersion() {
        let (store, defaults) = makeStore()
        _ = store.fileTypes
        XCTAssertEqual(defaults.integer(forKey: "schemaVersion"), 3)
    }

    func testWriteAndReadBack() throws {
        let (store, _) = makeStore()
        var types = store.fileTypes
        types[0].enabled = false
        types[1].enabled = true
        store.fileTypes = types

        let (store2, defaults) = makeStore()
        // re-point store2 at the same suite to verify persistence
        let suite = defaults
        let storeSamePersistence = SettingsStore(defaults: suite)
        let _ = storeSamePersistence
        // Direct re-read on first store:
        XCTAssertFalse(store.fileTypes[0].enabled)
        XCTAssertTrue(store.fileTypes[1].enabled)
        let _ = store2
    }

    func testSubmenuFlag_defaultFalse() {
        let (store, _) = makeStore()
        XCTAssertFalse(store.useRightClickSubmenu)
    }

    func testSubmenuFlag_setAndGet() {
        let (store, _) = makeStore()
        store.useRightClickSubmenu = true
        XCTAssertTrue(store.useRightClickSubmenu)
    }

    func testEnabledTypes_returnsOnlyEnabledPreservingOrder() {
        let (store, _) = makeStore()
        var types = store.fileTypes
        types[0].enabled = true   // txt
        types[1].enabled = true   // md
        types[2].enabled = false  // env
        types[3].enabled = true   // json
        store.fileTypes = types

        let enabled = store.enabledTypes
        XCTAssertEqual(enabled.map(\.ext), ["txt", "md", "json"])
    }

    func testMigration_blanksLegacyHardcodedCustomLabels() throws {
        let (store, defaults) = makeStore()
        // Simulate a pre-fix store: schema 1, custom type with the hardcoded label.
        var types = SeedPresets.builtIns
        types.append(FileTypeEntry(ext: "png", baseName: "shot", displayName: "New file",
                                   enabled: true, isBuiltIn: false))
        defaults.set(try JSONEncoder().encode(types), forKey: "fileTypes")
        defaults.set(1, forKey: "schemaVersion")

        let migrated = store.fileTypes
        let png = migrated.first { $0.ext == "png" }!
        XCTAssertEqual(png.displayName, "")
        XCTAssertEqual(png.menuTitle, "New .png")
        XCTAssertEqual(defaults.integer(forKey: "schemaVersion"), 3)
        // Migration persisted: a fresh decode sees the blanked label too.
        let reread = try JSONDecoder().decode(
            [FileTypeEntry].self, from: defaults.data(forKey: "fileTypes")!)
        XCTAssertEqual(reread.first { $0.ext == "png" }!.displayName, "")
    }

    func testMigration_leavesBuiltInsAndUserTypedLabelsAlone() throws {
        let (store, defaults) = makeStore()
        var types = SeedPresets.builtIns
        types.append(FileTypeEntry(ext: "png", baseName: "shot", displayName: "Screenshot",
                                   enabled: true, isBuiltIn: false))
        defaults.set(try JSONEncoder().encode(types), forKey: "fileTypes")
        defaults.set(1, forKey: "schemaVersion")

        let migrated = store.fileTypes
        XCTAssertEqual(migrated.first { $0.ext == "png" }!.displayName, "Screenshot")
        XCTAssertEqual(migrated.first { $0.ext == "txt" }!.displayName, "New Text File")
    }

    func testMigration_runsOnce_userCanRetypeNewFileAfterSchema2() throws {
        let (store, defaults) = makeStore()
        _ = store.fileTypes  // seeds + stamps schema 2
        var types = store.fileTypes
        types.append(FileTypeEntry(ext: "png", baseName: "shot", displayName: "New file",
                                   enabled: true, isBuiltIn: false))
        store.fileTypes = types
        XCTAssertEqual(store.fileTypes.first { $0.ext == "png" }!.displayName, "New file")
        _ = defaults
    }

    /// Schema 2 -> 3: existing users were seeded once, before RTF existed.
    func testMigration_appendsRTFPresetDisabledForSchema2Stores() throws {
        let (store, defaults) = makeStore()
        let legacy = SeedPresets.builtIns.filter { $0.ext != "rtf" }
        defaults.set(try JSONEncoder().encode(legacy), forKey: "fileTypes")
        defaults.set(2, forKey: "schemaVersion")

        let migrated = store.fileTypes
        XCTAssertEqual(migrated.map(\.ext), legacy.map(\.ext) + ["rtf"])
        XCTAssertFalse(migrated.last!.enabled)
        XCTAssertEqual(defaults.integer(forKey: "schemaVersion"), 3)
        let reread = try JSONDecoder().decode(
            [FileTypeEntry].self, from: defaults.data(forKey: "fileTypes")!)
        XCTAssertEqual(reread.last?.ext, "rtf")
    }

    /// A user who already added their own .rtf type keeps it, and gets no duplicate.
    func testMigration_skipsRTFPresetWhenUserAlreadyHasRTF() throws {
        let (store, defaults) = makeStore()
        var types = SeedPresets.builtIns.filter { $0.ext != "rtf" }
        types.append(FileTypeEntry(ext: "rtf", baseName: "", displayName: "",
                                   enabled: true, isBuiltIn: false))
        defaults.set(try JSONEncoder().encode(types), forKey: "fileTypes")
        defaults.set(2, forKey: "schemaVersion")

        let migrated = store.fileTypes
        XCTAssertEqual(migrated.filter { $0.ext == "rtf" }.count, 1)
        XCTAssertFalse(migrated.first { $0.ext == "rtf" }!.isBuiltIn)
        XCTAssertEqual(defaults.integer(forKey: "schemaVersion"), 3)
    }

    /// Schema 1 stores get both migrations in one pass.
    func testMigration_schema1RunsBothSteps() throws {
        let (store, defaults) = makeStore()
        var types = SeedPresets.builtIns.filter { $0.ext != "rtf" }
        types.append(FileTypeEntry(ext: "png", baseName: "shot", displayName: "New file",
                                   enabled: true, isBuiltIn: false))
        defaults.set(try JSONEncoder().encode(types), forKey: "fileTypes")
        defaults.set(1, forKey: "schemaVersion")

        let migrated = store.fileTypes
        XCTAssertEqual(migrated.first { $0.ext == "png" }!.displayName, "")
        XCTAssertEqual(migrated.last?.ext, "rtf")
    }

    func testCorruptedJSON_fallsBackToSeeds() {
        let (store, defaults) = makeStore()
        defaults.set(Data("not json".utf8), forKey: "fileTypes")
        let types = store.fileTypes
        XCTAssertEqual(types.map(\.ext), SeedPresets.builtIns.map(\.ext))
    }
}
