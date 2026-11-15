import XCTest
// Shared/ source files are compiled directly into this test target,
// so types like FileTypeEntry / SettingsStore are accessible without
// @testable import NewFile (test target is standalone & unsigned).

final class FilenameGeneratorTests: XCTestCase {

    func testNonEmptyBaseName_noCollision_returnsBareName() {
        let exists: (URL) -> Bool = { _ in false }
        let dir = URL(fileURLWithPath: "/tmp")
        let url = FilenameGenerator.uniqueFileURL(
            in: dir, baseName: "New Text File", ext: "txt", fileExists: exists
        )
        XCTAssertEqual(url.lastPathComponent, "New Text File.txt")
    }

    func testNonEmptyBaseName_oneCollision_returnsTwo() {
        let dir = URL(fileURLWithPath: "/tmp")
        let exists: (URL) -> Bool = { $0.lastPathComponent == "New Text File.txt" }
        let url = FilenameGenerator.uniqueFileURL(
            in: dir, baseName: "New Text File", ext: "txt", fileExists: exists
        )
        XCTAssertEqual(url.lastPathComponent, "New Text File 2.txt")
    }

    func testNonEmptyBaseName_threeCollisions_returnsFour() {
        let dir = URL(fileURLWithPath: "/tmp")
        let taken: Set<String> = ["x.txt", "x 2.txt", "x 3.txt"]
        let exists: (URL) -> Bool = { taken.contains($0.lastPathComponent) }
        let url = FilenameGenerator.uniqueFileURL(
            in: dir, baseName: "x", ext: "txt", fileExists: exists
        )
        XCTAssertEqual(url.lastPathComponent, "x 4.txt")
    }

    func testEmptyBaseName_noCollision_returnsDotExt() {
        let exists: (URL) -> Bool = { _ in false }
        let dir = URL(fileURLWithPath: "/tmp")
        let url = FilenameGenerator.uniqueFileURL(
            in: dir, baseName: "", ext: "env", fileExists: exists
        )
        XCTAssertEqual(url.lastPathComponent, ".env")
    }

    func testEmptyBaseName_oneCollision_returnsDotExtSpaceTwo() {
        let dir = URL(fileURLWithPath: "/tmp")
        let exists: (URL) -> Bool = { $0.lastPathComponent == ".env" }
        let url = FilenameGenerator.uniqueFileURL(
            in: dir, baseName: "", ext: "env", fileExists: exists
        )
        XCTAssertEqual(url.lastPathComponent, ".env 2")
    }

    func testEmptyBaseName_gitignore_returnsDotGitignore() {
        let exists: (URL) -> Bool = { _ in false }
        let dir = URL(fileURLWithPath: "/tmp")
        let url = FilenameGenerator.uniqueFileURL(
            in: dir, baseName: "", ext: "gitignore", fileExists: exists
        )
        XCTAssertEqual(url.lastPathComponent, ".gitignore")
    }

    // MARK: - Redundant-extension guard (.env.env / data.json.json)

    func testBaseNameEqualToDotExt_becomesDotfile() {
        let url = FilenameGenerator.uniqueFileURL(
            in: URL(fileURLWithPath: "/tmp"), baseName: ".env", ext: "env",
            fileExists: { _ in false })
        XCTAssertEqual(url.lastPathComponent, ".env")
    }

    func testBaseNameWithFullFilename_stripsDuplicateExtension() {
        let url = FilenameGenerator.uniqueFileURL(
            in: URL(fileURLWithPath: "/tmp"), baseName: "data.json", ext: "json",
            fileExists: { _ in false })
        XCTAssertEqual(url.lastPathComponent, "data.json")
    }

    func testBaseNameSuffixStrip_isCaseInsensitive() {
        let url = FilenameGenerator.uniqueFileURL(
            in: URL(fileURLWithPath: "/tmp"), baseName: "Data.JSON", ext: "json",
            fileExists: { _ in false })
        XCTAssertEqual(url.lastPathComponent, "Data.json")
    }

    func testNormalBaseName_unchangedByGuard() {
        let url = FilenameGenerator.uniqueFileURL(
            in: URL(fileURLWithPath: "/tmp"), baseName: "config", ext: "yml",
            fileExists: { _ in false })
        XCTAssertEqual(url.lastPathComponent, "config.yml")
    }

    // Issue #7: the extension's case reaches the filename unchanged.
    func testUppercaseExtension_keptInFilename() {
        let url = FilenameGenerator.uniqueFileURL(
            in: URL(fileURLWithPath: "/tmp"), baseName: "Untitled", ext: "R",
            fileExists: { _ in false })
        XCTAssertEqual(url.lastPathComponent, "Untitled.R")
    }

    func testUppercaseExtension_redundantSuffixStrippedIgnoringCase() {
        let url = FilenameGenerator.uniqueFileURL(
            in: URL(fileURLWithPath: "/tmp"), baseName: "analysis.r", ext: "R",
            fileExists: { _ in false })
        XCTAssertEqual(url.lastPathComponent, "analysis.R")
    }
}
