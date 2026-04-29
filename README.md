# NewFile — New File button for macOS Finder

**Free, open-source, native.** Adds a "New Text File" button to the macOS Finder toolbar and right-click menu. Click it in any Finder window to instantly create `New Text File.txt` in that folder, with auto-incrementing names. Reveals and selects the new file.

> macOS Finder lets you create a New Folder but not a New File. NewFile fixes that — the way it should have shipped.

## Why

For 15+ years macOS users have asked for a built-in "right-click → New File" or "New Text File" toolbar button in Finder. Windows and most Linux file managers have it; macOS doesn't. NewFile is a small, native [Finder Sync Extension](https://developer.apple.com/documentation/findersync/fifindersync) that adds the missing button — no Automator, no shell scripts, no setup beyond enabling the extension once.

Useful when you're:
- setting up LLM / dev infrastructure and constantly creating tiny config / prompt / scratch files
- coming from Windows or Linux and missing the right-click → New File workflow
- annoyed at having to open TextEdit just to make an empty `.txt`

## Install

### Homebrew (recommended, when available)

```sh
brew install --cask newfile
```

### Manual

1. Download the latest `NewFile.dmg` from [Releases](https://github.com/WheelUpLabs/newfile/releases).
2. Drag `NewFile.app` to `/Applications`.
3. Launch it once. Follow the in-app instructions to enable the Finder extension.

## Enable the Finder extension (one time)

System Settings → **General → Login Items & Extensions** → scroll to **Added Extensions** → toggle **NewFile Extension**.

> On macOS Sequoia 15.0 and 15.1 the Extensions UI was buggy — update to 15.2 or later if NewFile Extension doesn't appear in the toggle list.

## Add the toolbar button

In any Finder window: **View → Customize Toolbar…** → drag the NewFile icon into the toolbar where you want it.

## Use it

- **Toolbar button**: click → menu pops with "New Text File" → click → file created and selected.
- **Right-click**: anywhere in a Finder window background → "New Text File".

The created file is named `New Text File.txt`. If that name exists, it becomes `New Text File 2.txt`, then `New Text File 3.txt`, and so on.

## Build from source

```sh
git clone https://github.com/WheelUpLabs/newfile.git
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

## How it works

NewFile is implemented as a [Finder Sync Extension](https://developer.apple.com/documentation/findersync/fifindersync) (`FIFinderSync`) — Apple's supported way to add toolbar buttons and context menus to Finder. It runs sandboxed under macOS's app extension model. No private APIs, no SIMBL, no Finder injection.

When you click the toolbar button or context menu item:
1. The extension reads the targeted folder via `FIFinderSyncController.targetedURL()`.
2. It picks a unique filename (`New Text File.txt`, then `New Text File 2.txt`, etc.).
3. It creates an empty file with `FileManager.createFile`.
4. It calls `NSWorkspace.activateFileViewerSelecting` to reveal and select the file.

## Roadmap

- [x] Toolbar button
- [x] Right-click context menu
- [x] Auto-incrementing filename
- [x] Reveal + select after creation
- [ ] Custom filename templates (.md, .py, .json, .swift, etc.)
- [ ] Configurable default extension
- [ ] Customizable base name

## License

[MIT](LICENSE) — do whatever, no warranty.

## Related

- [MacNewFile](https://github.com/GarfieldFluffJr/MacNewFile) — older Objective-C implementation of the same idea
- [New File Menu](https://apps.apple.com/us/app/new-file-menu/id1064959555) — paid MAS alternative ($2.99)
- [iBoysoft MagicMenu](https://iboysoft.com/magic-menu/) — paid right-click utility ($19.99/yr) that bundles new-file
