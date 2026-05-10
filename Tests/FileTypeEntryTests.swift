import XCTest
// Shared/ source files are compiled directly into this test target,
// so types like FileTypeEntry / SettingsStore are accessible without
// @testable import NewFile (test target is standalone & unsigned).

final class FileTypeEntryTests: XCTestCase {

    // MARK: - Validation

    func testValidate_simpleExtension_returnsTrimmedLowercase() {
        XCTAssertEqual(try FileTypeEntry.validateExtension("md"), "md")
        XCTAssertEqual(try FileTypeEntry.validateExtension("MD"), "md")
        XCTAssertEqual(try FileTypeEntry.validateExtension(".md"), "md")
        XCTAssertEqual(try FileTypeEntry.validateExtension("  .MD  "), "md")
    }

    func testValidate_compoundExtensionsAllowed() {
        XCTAssertEqual(try FileTypeEntry.validateExtension("tar.gz"), "tar.gz")
        XCTAssertEqual(try FileTypeEntry.validateExtension("d.ts"), "d.ts")
    }

    func testValidate_rejectsEmpty() {
        XCTAssertThrowsError(try FileTypeEntry.validateExtension("")) { err in
            XCTAssertEqual(err as? FileTypeEntry.ValidationError, .empty)
        }
        XCTAssertThrowsError(try FileTypeEntry.validateExtension("   ")) { err in
            XCTAssertEqual(err as? FileTypeEntry.ValidationError, .empty)
        }
        XCTAssertThrowsError(try FileTypeEntry.validateExtension(".")) { err in
            XCTAssertEqual(err as? FileTypeEntry.ValidationError, .empty)
        }
    }

    func testValidate_rejectsBadChars() {
        XCTAssertThrowsError(try FileTypeEntry.validateExtension("md!"))
        XCTAssertThrowsError(try FileTypeEntry.validateExtension("a b"))
        XCTAssertThrowsError(try FileTypeEntry.validateExtension("a/b"))
    }

    func testValidate_rejectsTooLong() {
        XCTAssertThrowsError(try FileTypeEntry.validateExtension(String(repeating: "a", count: 17)))
        XCTAssertNoThrow(try FileTypeEntry.validateExtension(String(repeating: "a", count: 16)))
    }

    // MARK: - Codable

    func testCodable_roundTripsAllFields() throws {
        let id = UUID()
        let original = FileTypeEntry(
            id: id, ext: "md", baseName: "Untitled",
            displayName: "New Markdown", template: "# Hello\n",
            enabled: true, isBuiltIn: false
        )
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(FileTypeEntry.self, from: data)
        XCTAssertEqual(decoded, original)
    }
}
