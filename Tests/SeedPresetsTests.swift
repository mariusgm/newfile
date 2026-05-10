import XCTest
// Shared/ source files are compiled directly into this test target,
// so types like FileTypeEntry / SettingsStore are accessible without
// @testable import NewFile (test target is standalone & unsigned).

final class SeedPresetsTests: XCTestCase {

    func testSeed_orderMatchesSpec() {
        let exts = SeedPresets.builtIns.map { $0.ext }
        XCTAssertEqual(exts, ["txt", "md", "env", "json", "yml", "sh", "gitignore", "html"])
    }

    func testSeed_onlyTxtEnabled() {
        for entry in SeedPresets.builtIns {
            if entry.ext == "txt" {
                XCTAssertTrue(entry.enabled, "txt should be enabled by default")
            } else {
                XCTAssertFalse(entry.enabled, "\(entry.ext) should be disabled by default")
            }
        }
    }

    func testSeed_envAndGitignoreHaveEmptyBaseName() {
        let env = SeedPresets.builtIns.first { $0.ext == "env" }
        let gi = SeedPresets.builtIns.first { $0.ext == "gitignore" }
        XCTAssertEqual(env?.baseName, "")
        XCTAssertEqual(gi?.baseName, "")
    }

    func testSeed_allMarkedBuiltIn() {
        XCTAssertTrue(SeedPresets.builtIns.allSatisfy { $0.isBuiltIn })
    }

    func testSeed_allTemplatesEmpty() {
        XCTAssertTrue(SeedPresets.builtIns.allSatisfy { $0.template.isEmpty })
    }

    func testSeed_displayNamesNonEmpty() {
        XCTAssertTrue(SeedPresets.builtIns.allSatisfy { !$0.displayName.isEmpty })
    }
}
