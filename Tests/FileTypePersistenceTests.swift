import XCTest

/// Settings must never drop a saved custom type because its extension field is
/// mid-edit (empty or invalid). Reproduced on v0.2.5: clear a saved `.R` type's
/// extension, close Settings, and the type and its template were gone.
final class FileTypePersistenceTests: XCTestCase {

    private let rTemplate = "library(tidyverse)\nx <- 1\n"

    private func savedR() -> FileTypeEntry {
        FileTypeEntry(ext: "R", baseName: "analysis", displayName: "New R Script",
                      template: rTemplate, enabled: true, isBuiltIn: false)
    }

    private func saved() -> [FileTypeEntry] { SeedPresets.builtIns + [savedR()] }

    func testSavedCustomType_withClearedExtension_keepsLastSavedVersion() {
        let lastSaved = saved()
        var edited = lastSaved
        edited[edited.count - 1].ext = ""

        let out = FileTypePersistence.entriesToSave(edited: edited, lastSaved: lastSaved)

        let r = out.first { $0.id == lastSaved.last!.id }
        XCTAssertNotNil(r, "saved .R type must survive an empty extension field")
        XCTAssertEqual(r?.template, rTemplate, "its template must survive too")
    }

    func testSavedCustomType_withInvalidCharacter_keepsLastSavedVersion() {
        let lastSaved = saved()
        var edited = lastSaved
        edited[edited.count - 1].ext = "R!"

        let out = FileTypePersistence.entriesToSave(edited: edited, lastSaved: lastSaved)

        XCTAssertEqual(out.count, lastSaved.count)
        XCTAssertEqual(out.last, lastSaved.last, "the last valid saved entry is written unchanged")
    }

    func testInvalidRow_keepsItsPositionAfterReorder() {
        let lastSaved = saved()
        var edited = lastSaved
        var r = edited.removeLast()
        r.ext = ""
        edited.insert(r, at: 0)

        let out = FileTypePersistence.entriesToSave(edited: edited, lastSaved: lastSaved)

        XCTAssertEqual(out.first?.id, r.id)
        XCTAssertEqual(out.first?.ext, "R")
    }

    func testValidEdit_isSaved() {
        let lastSaved = saved()
        var edited = lastSaved
        edited[edited.count - 1].ext = "Rmd"
        edited[edited.count - 1].template = "---\ntitle: x\n---\n"

        let out = FileTypePersistence.entriesToSave(edited: edited, lastSaved: lastSaved)

        XCTAssertEqual(out.last?.ext, "Rmd")
        XCTAssertEqual(out.last?.template, "---\ntitle: x\n---\n")
    }

    func testNeverValidNewRow_isNotSaved() {
        let lastSaved = SeedPresets.builtIns
        let draft = FileTypeEntry(ext: "", baseName: "", displayName: "", template: "draft",
                                  enabled: true, isBuiltIn: false)
        let out = FileTypePersistence.entriesToSave(edited: lastSaved + [draft], lastSaved: lastSaved)

        XCTAssertFalse(out.contains { $0.id == draft.id },
                       "a row that was never valid must not reach the Finder menu")
    }

    func testDeletedRow_staysDeleted_evenIfItWasInvalidWhenDeleted() {
        let lastSaved = saved()
        // The user cleared the extension, then deleted the row.
        let edited = Array(lastSaved.dropLast())

        let out = FileTypePersistence.entriesToSave(edited: edited, lastSaved: lastSaved)

        XCTAssertFalse(out.contains { $0.ext == "R" }, "deliberate deletion must not be undone")
        XCTAssertEqual(out.count, lastSaved.count - 1)
    }

    func testBuiltIns_alwaysSaved() {
        let lastSaved = SeedPresets.builtIns
        var edited = lastSaved
        edited[1].baseName = ""
        edited[1].displayName = ""

        let out = FileTypePersistence.entriesToSave(edited: edited, lastSaved: lastSaved)

        XCTAssertEqual(out, edited)
    }

    func testHasUnsavedInvalidEdit_onlyForSavedRowsWithInvalidExtension() {
        let lastSaved = saved()
        var edited = lastSaved
        edited[edited.count - 1].ext = ""
        let draft = FileTypeEntry(ext: "", baseName: "", displayName: "", template: "",
                                  enabled: true, isBuiltIn: false)

        XCTAssertTrue(FileTypePersistence.isHoldingLastSaved(edited.last!, lastSaved: lastSaved))
        XCTAssertFalse(FileTypePersistence.isHoldingLastSaved(draft, lastSaved: lastSaved))
        XCTAssertFalse(FileTypePersistence.isHoldingLastSaved(lastSaved.last!, lastSaved: lastSaved))
    }
}
