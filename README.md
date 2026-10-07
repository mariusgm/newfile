# NewFile — New File button for macOS Finder

**Free, open-source, native.** A small [Finder Sync Extension](https://developer.apple.com/documentation/findersync/fifindersync) that adds the missing "New File" button to macOS Finder — right-click menu and toolbar. No Automator, no shell scripts, no setup beyond enabling the extension once.

- **Any file type** — `.txt` enabled by default, plus 7 built-in presets (`.md`, `.json`, `.sh`, `.env`, `.yml`, `.gitignore`, `.html`). Add your own (`.tsx`, `.toml`, whatever you need).
- **Starter templates** — pre-fill new files with frontmatter, shebang lines, a JSON skeleton, or any boilerplate you reuse.
- **Drag-to-reorder** — set the menu order in Preferences; the first enabled type is the toolbar's one-click action.
- **Submenu mode** — optionally collapse all types under a single "New File ▸" right-click entry.
- **Auto-incrementing names** — `New Text File.txt`, then `New Text File 2.txt`, and so on. Reveals and selects the new file.
- **Auto-updates** via Sparkle — no need to re-download.

> macOS Finder lets you create a New Folder but not a New File. NewFile fixes that — the way it should have shipped.

<p align="center">
  <img src=".github/assets/demo.gif" alt="NewFile demo — right-click in Finder to create a new file">
</p>

## Install

### Homebrew (recommended)

```sh
brew install mariusgm/newfile/newfile
```

### Manual

1. Download the latest `NewFile.dmg` from [Releases](https://github.com/mariusgm/newfile/releases).
2. Drag `NewFile.app` to `/Applications`.
3. Launch it once. Follow the in-app instructions to enable the Finder extension.

## Enable the Finder extension (one time)

System Settings → **General → Login Items & Extensions** → scroll to **Added Extensions** → toggle **NewFile Extension**.

> On macOS Sequoia 15.0 and 15.1 the Extensions UI was buggy — update to 15.2 or later if NewFile Extension doesn't appear in the toggle list.

> On macOS 27 "Golden Gate" this pane was reworked to list only Finder Sync and File Provider
> extensions. NewFile has not been walked through on 27 yet — if the toggle doesn't appear, please
> [open an issue](https://github.com/mariusgm/newfile/issues).

## Add the toolbar button

In any Finder window: **View → Customize Toolbar…** → drag the NewFile icon into the toolbar where you want it.

## Use it

- **Toolbar button**: click → menu pops with "New Text File" → click → file created and selected.
- **Right-click**: anywhere in a Finder window background → "New Text File".

The created file is named `New Text File.txt`. If that name exists, it becomes `New Text File 2.txt`, then `New Text File 3.txt`, and so on.

### iCloud Drive: use the toolbar button

On recent macOS versions, Finder doesn't show right-click items from third-party Finder extensions inside **iCloud Drive** folders — including Desktop and Documents when they sync to iCloud. Finder Sync extensions were designed around a folder each extension owns, and iCloud Drive manages these folders itself ([Apple Developer Forums](https://developer.apple.com/forums/thread/737283)). Other Finder Sync apps report the same behavior. We haven't identified a supported Finder Sync workaround that restores the right-click menu there. **The toolbar button works in iCloud Drive** — add it once (above) and use it there.

## Customize

Open **NewFile.app → ⌘,** (or click the toolbar dropdown → **Customize…**) to manage file types, templates, menu order, and submenu mode. Each type has an editable **menu label** (what Finder shows) and a **default filename**; leave the filename empty for dotfile-style names (`.env`, `.gitignore`). A **Rich Text (.rtf)** type ships with a minimal RTF header so the file opens in TextEdit; an empty `.rtf` isn't a valid RTF document. The **Add…/Edit…** button per row manages that type's starter template.

## Build from source

```sh
git clone https://github.com/mariusgm/newfile.git
cd newfile
brew install xcodegen
xcodegen generate
open NewFile.xcodeproj
```

In Xcode: select the **NewFile** scheme, ⌘R to build & run. See [`setup.md`](setup.md) for code signing and notarization notes if you want to distribute your own build.

### Project layout

```
newfile/
├── App/                 SwiftUI host app — onboarding window only
├── Extension/           FIFinderSync subclass — toolbar + context menu + file creation
├── project.yml          xcodegen project definition (regenerable)
├── README.md
└── setup.md             codesigning + notarization + release notes
```

The host app (`NewFile.app`) is intentionally minimal — its only job is to embed the Finder Sync extension and present onboarding. All the work happens in `Extension/FinderSync.swift`.

## Uninstall

Quitting NewFile doesn't stop the Finder extension — Finder keeps it running as its own process, which is why macOS can say the app is "in use" when you try to delete it.

**Homebrew:** `brew uninstall --cask newfile` (add `--zap` to also remove your saved file types).

**Manual (DMG install):**
1. Quit NewFile (⌘Q).
2. System Settings → General → Login Items & Extensions → Extensions → Finder extensions → uncheck **NewFile**.
3. Drag NewFile.app from Applications to the Trash.
4. Optional — remove saved settings: delete `~/Library/Group Containers/Q7VD7MTRL8.dev.newfile.NewFile`.

## How it works

NewFile is implemented as a [Finder Sync Extension](https://developer.apple.com/documentation/findersync/fifindersync) (`FIFinderSync`) — Apple's supported way to add toolbar buttons and context menus to Finder. It runs sandboxed under macOS's app extension model. No private APIs, no SIMBL, no Finder injection.

When you click the toolbar button or context menu item:
1. The extension reads the targeted folder via `FIFinderSyncController.targetedURL()`.
2. It picks a unique filename (`New Text File.txt`, then `New Text File 2.txt`, etc.).
3. It creates an empty file with `FileManager.createFile`.
4. It calls `NSWorkspace.activateFileViewerSelecting` to reveal and select the file.

## License

[MIT](LICENSE) — do whatever, no warranty.

## Related

- [MacNewFile](https://github.com/GarfieldFluffJr/MacNewFile) — older Objective-C implementation of the same idea
- [New File Menu](https://apps.apple.com/us/app/new-file-menu/id1064959555) — paid MAS alternative ($2.99)
- [iBoysoft MagicMenu](https://iboysoft.com/magic-menu/) — paid right-click utility ($19.99/yr) that bundles new-file
