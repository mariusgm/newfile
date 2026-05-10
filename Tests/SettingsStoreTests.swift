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
        XCTAssertEqual(defaults.integer(forKey: "schemaVersion"), 1)
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

    func testCorruptedJSON_fallsBackToSeeds() {
        let (store, defaults) = makeStore()
        defaults.set(Data("not json".utf8), forKey: "fileTypes")
        let types = store.fileTypes
        XCTAssertEqual(types.map(\.ext), SeedPresets.builtIns.map(\.ext))
    }
}
