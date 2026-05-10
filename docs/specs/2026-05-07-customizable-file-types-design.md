# Customizable file types — design

**Date:** 2026-05-07
**Status:** Design approved, pending implementation plan
**Repo:** `mariusgm/newfile`

## Problem

NewFile currently creates one hardcoded file: `New Text File.txt` (empty, UTF-8). Users want:

- More file types — especially `.md` and `.env` — without waiting on a release for each.
- Editable default base names per type (`.env` should be just `.env`, not `Untitled.env`).
- Optional starter content (templates) so a new `.md` can come up with `# Heading` already in place.
- A way to manage all of the above without leaving the app.

The literal "right-click on the New Text File menu row to expand options" interaction the user originally asked about is **not possible** — macOS NSMenu/Finder context menus don't expose a secondary action on individual menu items. The achievable shape is a settings window in the host app + multiple menu rows surfaced in Finder.

## Non-goals (v1)

These are explicitly deferred so v1 stays narrow:

- Template variable substitution (`${filename}`, `${date}`, `${author}`).
- Per-type icons in the menu.
- Multiple named templates per file type.
- Syntax highlighting in the template editor.
- Import/export of preset bundles.
- A menu bar item.
- Localization beyond English.

## Architecture

Three pieces, two of which already exist:

- **`NewFile.app`** (host app) — currently onboarding-only. Grows a Preferences window (SwiftUI) with the file-type list editor and the template popup editor. Window opens on launch when invoked from "Customize…", or via standard `⌘,` if app is already foregrounded.
- **`NewFile Extension`** (Finder Sync, sandboxed) — reads settings on every `menu(for:)` call (cheap; rebuilds NSMenu each invocation already), writes nothing.
- **App Group `group.dev.newfile.NewFile`** — single shared `UserDefaults` suite. Settings written by the host app are read by the extension. App Group is the standard sandbox-crossing path for `FIFinderSync`; no custom XPC needed.

**Live updates:** extension calls `menu(for:)` on every right-click / toolbar tap, so it always reads current settings. No notification plumbing required for settings to "take effect."

## Data model

One ordered list of file-type entries, persisted as JSON in App Group `UserDefaults` under key `fileTypes`, plus one boolean for the right-click submenu toggle and a schema version.

```swift
struct FileTypeEntry: Codable, Identifiable {
    var id: UUID
    var ext: String          // e.g. "txt", "md", "env" — no leading dot, lowercase
    var baseName: String     // e.g. "New Text File", "Untitled", "" for ".env"
    var displayName: String  // shown in the menu — e.g. "New Text File", "New Markdown", "New .env"
    var template: String     // starter file content; empty string = empty file
    var enabled: Bool        // shown in menus when true
    var isBuiltIn: Bool      // curated preset (cannot be deleted, can be disabled / edited)
}

// settings keys in App Group UserDefaults
"fileTypes"            // [FileTypeEntry] as JSON Data
"useRightClickSubmenu" // Bool, default false
"schemaVersion"        // Int, default 1
```

**Ordering:** array order. **Default fast-path file** = first entry whose `enabled == true`.

**Curated presets seeded on first launch** (in this order, only `.txt` enabled by default):

| ext | baseName | displayName |
|---|---|---|
| txt | "New Text File" | New Text File |
| md | "Untitled" | New Markdown |
| env | "" | New .env |
| json | "data" | New JSON |
| yml | "config" | New YAML |
| sh | "script" | New Shell Script |
| gitignore | "" | New .gitignore |
| html | "index" | New HTML |

Custom user types are appended below the presets, `isBuiltIn = false`, and can be deleted.

## Settings UI (Preferences window)

Single-window, single-pane SwiftUI. ~520×560pt, resizable.

```
┌─ NewFile Preferences ────────────────────────────────┐
│                                                      │
│  File types                            [+ Add type…] │
│  ┌────────────────────────────────────────────────┐  │
│  │ ☰  ☑  .txt    "New Text File"     [Template…] │  │
│  │ ☰  ☐  .md     "Untitled"          [Template…] │  │
│  │ ☰  ☐  .env    ""                  [Template…] │  │
│  │ ☰  ☐  .json   "data"              [Template…] │  │
│  │ ☰  ☐  .yml    "config"            [Template…] │  │
│  │ ☰  ☐  .sh     "script"            [Template…] │  │
│  │ ☰  ☐  .gitignore  ""              [Template…] │  │
│  │ ☰  ☐  .html   "index"             [Template…] │  │
│  ├ — your types — ────────────────────────────────┤  │
│  │ ☰  ☑  .tsx    "Component"   [Template…]  [⊖]  │  │
│  └────────────────────────────────────────────────┘  │
│                                                      │
│  ☐  Use submenu in right-click menu                  │
│      (when off: each enabled type is its own row)    │
│                                                      │
│                                       [ Done ]       │
└──────────────────────────────────────────────────────┘
```

- **☰** drag handle — reorders rows. Built-in and custom rows can both be dragged. Order in this list = order in the menus. The first *checked* row is the toolbar/right-click fast-path default.
- **☑/☐** enables/disables the type in menus.
- **Extension label** — read-only for built-ins; editable inline for custom types.
- **Base name text field** — inline-editable for every row. Empty allowed (file becomes `.ext`, with auto-increment `.ext 2` on collision).
- **[Template…]** opens the template popup (next section).
- **[⊖]** delete — only on custom types.
- **[+ Add type…]** appends a new custom row with focus on its extension field.
- **Submenu checkbox** controls right-click layout (see Menu rendering rules).
- **[Done]** saves and closes. Settings auto-save on every field change so closing via ⌘W or red button is also safe.

**Validation on custom extension input:** trim leading dot, lowercase, allow `[a-z0-9._-]+`, max 16 chars; reject empty. Inline red border + tooltip on bad input; row not saved until valid.

## Template editor popup

Triggered by the `[Template…]` button on a row.

```
┌─ Template — .md ─────────────────────────┐
│                                          │
│  ┌────────────────────────────────────┐  │
│  │                                    │  │
│  │                                    │  │
│  │  (TextEditor — plain text)         │  │
│  │                                    │  │
│  │                                    │  │
│  └────────────────────────────────────┘  │
│  Plain text. Saved as the file's content.│
│                                          │
│              [ Cancel ]   [ OK ]         │
└──────────────────────────────────────────┘
```

- Modal sheet attached to the Preferences window. ~440×320pt.
- Title shows the extension being edited (`Template — .md`).
- One `TextEditor` filling the body. Monospaced font (`SF Mono` 12pt). No formatting, no syntax highlighting.
- Caption: *"Plain text. Saved as the file's content."*
- **OK** writes the buffer to that row's `template` and closes.
- **Cancel** / **⎋** discards the buffer and closes.
- Clipboard paste is the system gesture in `TextEditor` — no extra UI needed.
- **Empty template ⇒ empty (zero-byte) file** (matches current `.txt` behavior exactly).
- **No variable substitution** — what you type is what you get. Forward-compatible: a future `templateVariablesEnabled` per-row flag can opt rows in.

## Menu rendering rules

The extension's `menu(for:)` returns one NSMenu, but the kind passed in (`FIMenuKind`) tells us the surface.

**Toolbar dropdown** (`.toolbarItemMenu`):
1. One row per *enabled* type, in configured order, each labelled by its `displayName`.
2. Separator.
3. **"Customize…"** — sends a Distributed Notification to the host app to launch and show Preferences.

**Right-click in folder background** (`.contextualMenuForContainer`):
- If `useRightClickSubmenu == false` (default): one inline row per enabled type. **No "Customize…" row** (keeps the Finder context menu lean).
- If `useRightClickSubmenu == true`: one parent item **"New File ▸"** whose submenu lists every enabled type, in configured order. Still **no "Customize…" row** — toolbar remains the settings entry point.

**Right-click on a selected file** (`.contextualMenuForItems`): no NewFile rows. Matches current behavior.

**Empty enabled list** (user disabled every type): both surfaces show a single row "**Enable a file type in NewFile…**" that opens Preferences. Defends against silent-no-op.

**Icons:** v1 keeps the single shared `square.and.pencil` SF Symbol on every row.

**"Open Preferences" notification:** new name `dev.newfile.NewFile.openPreferences`. Host app installs an observer on launch; if app isn't running, the extension also calls `NSWorkspace.shared.open(...)` on the host bundle URL (sandbox allows opening own host app).

## File creation behavior

Generalizes the current `createNewFile(_:)` action. Same target-directory resolution, same reveal-and-select; the type/name/contents come from the chosen `FileTypeEntry`.

```swift
func createFile(for entry: FileTypeEntry, in directory: URL) throws -> URL {
    let url = uniqueFileURL(in: directory, baseName: entry.baseName, ext: entry.ext)
    let scoped = directory.startAccessingSecurityScopedResource()
    defer { if scoped { directory.stopAccessingSecurityScopedResource() } }
    let data = entry.template.data(using: .utf8) ?? Data()
    try data.write(to: url, options: [.withoutOverwriting])
    return url
}
```

**Naming rules** (generalize current `uniqueFileURL`):

- `baseName` non-empty: `"<baseName>.<ext>"`, then `"<baseName> 2.<ext>"`, `"<baseName> 3.<ext>"`, … on collision.
- `baseName` empty: `".<ext>"`, then `".<ext> 2"`, `".<ext> 3"`, … on collision. The increment goes after the extension because the dotfile has no base — keeps the file recognizable as the type.
- All collision checks are `FileManager.fileExists`-based and stop at the first free name.

**Encoding:** UTF-8, no BOM. Empty template ⇒ zero-byte file.

**Failure modes** (each calls `NSSound.beep()`, logs via `os.Logger`; `.withoutOverwriting` ensures no partial file):
- No target directory resolvable.
- Sandbox refuses write.
- Disk full / I/O error.

**Selected-file edge case:** if user right-clicks with a file selected and `targetedURL == nil`, fall back to that file's parent directory via `selectedItemURLs()` — same as today.

## Edge cases & migration

- **First launch after upgrade** (existing user, no `fileTypes` key): seed the curated preset list with only `.txt` enabled. Identical to fresh install; preserves today's behavior.
- **Schema migration:** `schemaVersion` defaults to 1. Future versions read it before decoding `fileTypes`; mismatch ⇒ run a migration step or fall back to seeded defaults (logged warning).
- **App Group not entitled** (build-config bug): host app falls back to `UserDefaults.standard`; extension uses the App Group suite — they'd silently disagree. Defense: at host-app launch, assert the App Group suite is reachable; show a one-time "Reinstall NewFile" alert if not.
- **Empty `displayName`:** treated as invalid (inline red border, row not saved).
- **Two custom types with the same extension:** allowed. They're separate entries with separate `baseName`/`template`/`displayName`, and the menu shows both (e.g. `.md` "README" and `.md` "Notes" as distinct presets).
- **Reordering is fully manual.** No alphabetical sort, no separate default-type picker — first enabled = default. One source of truth.
- **Preferences window is the only writer** of settings; the extension is read-only.

## Affected files (preview, for the implementation plan)

- `Extension/FinderSync.swift` — generalize `menu(for:)` and `createNewFile(_:)`; load settings from App Group; handle `FIMenuKind` branching; emit "open Preferences" notification.
- `Extension/Settings.swift` *(new)* — `FileTypeEntry`, App Group `UserDefaults` reader, default-seeding helpers. Shared between targets.
- `App/PreferencesView.swift` *(new)* — SwiftUI Preferences window.
- `App/TemplateEditorSheet.swift` *(new)* — modal sheet for template editing.
- `App/AppDelegate.swift` (or `NewFileApp.swift`) — observe `dev.newfile.NewFile.openPreferences`; expose Preferences as a standard `⌘,` window.
- `project.yml` — add App Group entitlement to both targets; ensure the new Swift files are in both build phases as appropriate.
- `setup.md` — note App Group provisioning step in the codesigning section.
- `README.md` — short paragraph under "Use it" describing the customization surface.
