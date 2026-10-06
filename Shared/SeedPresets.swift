import Foundation

enum SeedPresets {
    static let builtIns: [FileTypeEntry] = [
        FileTypeEntry(ext: "txt",       baseName: "New Text File", displayName: "New Text File",     enabled: true,  isBuiltIn: true),
        FileTypeEntry(ext: "md",        baseName: "Untitled",      displayName: "New Markdown",      enabled: false, isBuiltIn: true),
        FileTypeEntry(ext: "env",       baseName: "",              displayName: "New .env",          enabled: false, isBuiltIn: true),
        FileTypeEntry(ext: "json",      baseName: "data",          displayName: "New JSON",          enabled: false, isBuiltIn: true),
        FileTypeEntry(ext: "yml",       baseName: "config",        displayName: "New YAML",          enabled: false, isBuiltIn: true),
        FileTypeEntry(ext: "sh",        baseName: "script",        displayName: "New Shell Script",  enabled: false, isBuiltIn: true),
        FileTypeEntry(ext: "gitignore", baseName: "",              displayName: "New .gitignore",    enabled: false, isBuiltIn: true),
        FileTypeEntry(ext: "html",      baseName: "index",         displayName: "New HTML",          enabled: false, isBuiltIn: true),
        rtf,
    ]

    /// An empty .rtf isn't a valid RTF document (issue #4); `{\rtf1}` is the
    /// minimal header TextEdit opens as rich text. Existing stores get it via
    /// `SettingsStore.ensureBuiltIns`.
    static let rtf = FileTypeEntry(ext: "rtf", baseName: "Untitled", displayName: "New Rich Text",
                                   template: "{\\rtf1}", enabled: false, isBuiltIn: true)
}
