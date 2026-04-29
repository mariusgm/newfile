# NewFile — build, sign, and ship

This guide covers what you need to do *beyond* `xcodegen generate && xcodebuild` to produce a distributable build of NewFile. The repo as scaffolded builds and runs locally with ad-hoc codesigning; for distribution you need a real signing identity, notarization, and a DMG.

## Prerequisites

- macOS 13.0+ (deployment target)
- Xcode 15+ (the repo was scaffolded against Xcode 26.4.1)
- [xcodegen](https://github.com/yonaskolb/XcodeGen) — `brew install xcodegen`
- An [Apple Developer account](https://developer.apple.com) ($99/yr) if you want to distribute outside the build machine

## First-time setup

```sh
git clone https://github.com/WheelUpLabs/newfile.git
cd newfile
xcodegen generate
open NewFile.xcodeproj
```

In Xcode:
1. Select the **NewFile** target → **Signing & Capabilities** tab.
2. Set your **Team** (your Apple Developer team) for both `NewFile` and `NewFileExtension` targets.
3. Bundle IDs are pre-set as `dev.newfile.NewFile` and `dev.newfile.NewFile.NewFileExtension` — change the prefix in `project.yml` if you want to ship under your own ID.

## Local build (no signing)

```sh
xcodebuild -project NewFile.xcodeproj \
  -scheme NewFile \
  -configuration Debug \
  -destination 'platform=macOS' build \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGNING_ALLOWED=NO
```

Output app: `~/Library/Developer/Xcode/DerivedData/NewFile-*/Build/Products/Debug/NewFile.app`

## Run locally

After building, copy the `.app` to `/Applications` and launch it once. macOS registers the embedded Finder Sync extension only after the host app is launched at least once from `/Applications`.

Then:
1. **System Settings → General → Login Items & Extensions** → enable "NewFile Extension"
2. **Finder → View → Customize Toolbar…** → drag the NewFile button into the toolbar

If the extension doesn't show up, run:

```sh
pluginkit -m -i dev.newfile.NewFile.NewFileExtension
```

If empty, the system hasn't registered the plug-in. Try `pluginkit -a /Applications/NewFile.app/Contents/PlugIns/NewFileExtension.appex` to add it manually.

## Distribution build (signed + notarized)

Distribution requires:
- A "Developer ID Application" certificate in your login keychain
- An app-specific password for `notarytool` ([generate here](https://support.apple.com/en-us/HT204397))

```sh
# 1. Archive
xcodebuild -project NewFile.xcodeproj \
  -scheme NewFile \
  -configuration Release \
  -archivePath build/NewFile.xcarchive \
  archive

# 2. Export with Developer ID signing
cat > build/exportOptions.plist <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>developer-id</string>
    <key>teamID</key>
    <string>YOUR_TEAM_ID</string>
</dict>
</plist>
EOF

xcodebuild -exportArchive \
  -archivePath build/NewFile.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist build/exportOptions.plist

# 3. Create DMG (requires create-dmg: brew install create-dmg)
create-dmg \
  --volname "NewFile" \
  --window-size 480 320 \
  --icon "NewFile.app" 120 160 \
  --app-drop-link 360 160 \
  build/NewFile.dmg \
  build/export/NewFile.app

# 4. Notarize
xcrun notarytool submit build/NewFile.dmg \
  --apple-id you@example.com \
  --team-id YOUR_TEAM_ID \
  --password APP_SPECIFIC_PASSWORD \
  --wait

# 5. Staple
xcrun stapler staple build/NewFile.dmg
```

Upload `build/NewFile.dmg` to a GitHub Release.

## Homebrew cask

After the first signed + notarized release is on GitHub:

1. Fork [homebrew/homebrew-cask](https://github.com/Homebrew/homebrew-cask)
2. Add `Casks/n/newfile.rb`:

   ```ruby
   cask "newfile" do
     version "0.1.0"
     sha256 "..."

     url "https://github.com/WheelUpLabs/newfile/releases/download/v#{version}/NewFile.dmg"
     name "NewFile"
     desc "New File button for the macOS Finder"
     homepage "https://github.com/WheelUpLabs/newfile"

     app "NewFile.app"

     zap trash: [
       "~/Library/Containers/dev.newfile.NewFile",
       "~/Library/Containers/dev.newfile.NewFile.NewFileExtension",
     ]
   end
   ```

3. Open a PR to `homebrew/homebrew-cask`. Maintainers will review.

## Troubleshooting

**Extension doesn't appear in System Settings → Login Items & Extensions**
- App must be in `/Applications` (not `~/Downloads` or DerivedData)
- Launch the host app at least once
- On macOS Sequoia 15.0–15.1 the Extensions UI was buggy; update to 15.2+

**Right-click menu doesn't show "New Text File"**
- Confirm the extension is enabled in System Settings
- Check `pluginkit -m -i dev.newfile.NewFile.NewFileExtension` shows the extension
- The extension is registered for `/` (the entire filesystem) — if you set `directoryURLs` to a narrower set in `Extension/FinderSync.swift`, it only appears in those folders

**Toolbar button doesn't appear in Customize Toolbar**
- Same checks as above; the toolbar item is only available if the extension is enabled
- Restart Finder: `killall Finder`
