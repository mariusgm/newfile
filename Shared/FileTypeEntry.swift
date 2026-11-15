import Foundation

struct FileTypeEntry: Codable, Identifiable, Equatable, Hashable {
    var id: UUID
    var ext: String
    var baseName: String
    var displayName: String
    var template: String
    var enabled: Bool
    var isBuiltIn: Bool

    init(
        id: UUID = UUID(),
        ext: String,
        baseName: String,
        displayName: String,
        template: String = "",
        enabled: Bool = false,
        isBuiltIn: Bool = false
    ) {
        self.id = id
        self.ext = ext
        self.baseName = baseName
        self.displayName = displayName
        self.template = template
        self.enabled = enabled
        self.isBuiltIn = isBuiltIn
    }

    /// Menu label shown in Finder. Falls back to a label derived from the
    /// extension when `displayName` is blank (custom types created before the
    /// label was editable, or deliberately left empty).
    var menuTitle: String {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? Self.derivedDisplayName(ext: ext) : trimmed
    }

    /// Default menu label for a type with no explicit displayName.
    static func derivedDisplayName(ext: String) -> String {
        let e = ext.trimmingCharacters(in: .whitespacesAndNewlines)
        return e.isEmpty ? "New file" : "New .\(e)"
    }

    enum ValidationError: Error, Equatable {
        case empty
        case tooLong
        case badCharacters
    }

    /// Normalizes (trim, drop leading dot) and validates a user-typed extension.
    /// Allowed: `[A-Za-z0-9._-]+`, max 16 characters, non-empty after normalization.
    /// Case is kept as typed: some formats use uppercase by convention
    /// (`.R`, `.Rproj`; issue #7).
    static func validateExtension(_ raw: String) throws -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.hasPrefix(".") { s.removeFirst() }
        if s.isEmpty { throw ValidationError.empty }
        if s.count > 16 { throw ValidationError.tooLong }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789._-")
        if s.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            throw ValidationError.badCharacters
        }
        return s
    }
}
