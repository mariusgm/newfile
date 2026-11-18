import Foundation

/// Decides what Settings writes to the store.
///
/// A custom row whose extension is mid-edit (empty or invalid) must not reach
/// the Finder menu, but it must not erase the saved type either: until the
/// field is valid again, the last saved version of that row is written in its
/// place. A row that was never valid is left out. A deleted row is absent from
/// `edited`, so it stays deleted.
enum FileTypePersistence {

    static func entriesToSave(edited: [FileTypeEntry],
                              lastSaved: [FileTypeEntry]) -> [FileTypeEntry] {
        let savedByID = Dictionary(lastSaved.map { ($0.id, $0) },
                                   uniquingKeysWith: { first, _ in first })
        return edited.compactMap { row in
            isValid(row) ? row : savedByID[row.id]
        }
    }

    /// True when the row is being shown with an invalid extension while its
    /// last saved version is what Finder still uses.
    static func isHoldingLastSaved(_ row: FileTypeEntry,
                                   lastSaved: [FileTypeEntry]) -> Bool {
        !isValid(row) && lastSaved.contains { $0.id == row.id }
    }

    static func isValid(_ row: FileTypeEntry) -> Bool {
        row.isBuiltIn || (try? FileTypeEntry.validateExtension(row.ext)) != nil
    }
}
