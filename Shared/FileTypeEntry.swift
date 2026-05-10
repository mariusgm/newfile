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

    enum ValidationError: Error, Equatable {
        case empty
        case tooLong
        case badCharacters
    }

    /// Normalizes (trim, drop leading dot, lowercase) and validates a user-typed extension.
    /// Allowed: `[a-z0-9._-]+`, max 16 characters, non-empty after normalization.
    static func validateExtension(_ raw: String) throws -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        while s.hasPrefix(".") { s.removeFirst() }
        if s.isEmpty { throw ValidationError.empty }
        if s.count > 16 { throw ValidationError.tooLong }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789._-")
        if s.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            throw ValidationError.badCharacters
        }
        return s
    }
}
