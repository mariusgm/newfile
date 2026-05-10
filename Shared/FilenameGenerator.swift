import Foundation

enum FilenameGenerator {
    /// Returns a non-colliding file URL inside `directory`.
    /// - If `baseName` is non-empty: `"<baseName>.<ext>"`, `"<baseName> 2.<ext>"`, …
    /// - If `baseName` is empty:     `".<ext>"`,           `".<ext> 2"`,           …
    /// `fileExists` is injected for testability (defaults to FileManager).
    static func uniqueFileURL(
        in directory: URL,
        baseName: String,
        ext: String,
        fileExists: (URL) -> Bool = { FileManager.default.fileExists(atPath: $0.path) }
    ) -> URL {
        let isDotfile = baseName.isEmpty

        func candidate(_ i: Int) -> URL {
            if isDotfile {
                return i == 1
                    ? directory.appendingPathComponent(".\(ext)")
                    : directory.appendingPathComponent(".\(ext) \(i)")
            } else {
                return i == 1
                    ? directory.appendingPathComponent("\(baseName).\(ext)")
                    : directory.appendingPathComponent("\(baseName) \(i).\(ext)")
            }
        }

        var i = 1
        while fileExists(candidate(i)) { i += 1 }
        return candidate(i)
    }
}
