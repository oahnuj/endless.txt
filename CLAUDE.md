# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

```bash
# Generate Xcode project (required before first build)
cd endless.txt && xcodegen generate

# Open in Xcode
open endless.txt/NvrEndingTxt.xcodeproj

# Build from command line
xcodebuild -project endless.txt/NvrEndingTxt.xcodeproj -scheme NvrEndingTxt -configuration Debug build
```

**Prerequisites:** `brew install xcodegen`

## Architecture

This is a macOS menu bar app (no dock icon) for quick thought capture to a single text file.

### Key Components

- **AppDelegate** (`AppDelegate.swift`) - Central coordinator managing menu bar status item, floating panel lifecycle, and global hotkey registration. Implements `NSWindowDelegate` for window frame persistence.

- **FloatingPanel** (`Views/FloatingPanel.swift`) - Custom `NSPanel` subclass that enables keyboard input on a borderless window. Required because standard `NSWindow` doesn't receive key events when borderless.

- **HotkeyManager** (`Services/HotkeyManager.swift`) - Carbon API wrapper for system-wide keyboard shortcuts. Uses `RegisterEventHotKey` because there's no native Swift API for global hotkeys.

- **FileService** (`Services/FileService.swift`) - Singleton handling text file I/O with 500ms debounced auto-save. Uses Combine's `@Published` for reactive UI updates.

- **AppSettings** (`Models/AppSettings.swift`) - Singleton using `@AppStorage` for UserDefaults-backed preferences. Contains theme definitions (`AppTheme` enum) and shortcut key configuration.

- **HashtagState** (`Views/EditorTextView.swift`) - Singleton tracking used hashtags across the document. Maintains counts, recent usage order, and provides matching suggestions for autocomplete.

- **KeyboardShortcutsManager** (`Services/KeyboardShortcutsManager.swift`) - Manages in-app keyboard shortcuts using the KeyboardShortcuts library. Handles search, navigation, formatting, and tag jump shortcuts.

### Communication Patterns

Cross-component communication uses `NotificationCenter`:
- `.focusQuickEntry` - Focus the quick entry text field when panel opens
- `.hotkeyChanged` - Re-register global hotkey when user changes shortcut
- `.tagJump` - Jump to next occurrence of hashtag at cursor
- `.hashtagClicked` - Highlight all occurrences of clicked hashtag
- `.clearHashtagFilter` - Clear hashtag highlight filter

### Window Behavior

The app uses `NSApp.setActivationPolicy(.accessory)` combined with `LSUIElement = true` in Info.plist to hide from dock. The panel uses `.nonactivatingPanel` collection behavior to appear over other apps without stealing focus aggressively.

## Project Structure

```
endless.txt/
├── project.yml              # XcodeGen configuration
└── NvrEndingTxt/
    ├── Info.plist           # LSUIElement = true
    ├── Services/            # FileService, HotkeyManager, LaunchAtLoginManager
    ├── Models/              # AppSettings, themes
    └── Views/               # ContentView, QuickEntryView, SettingsView, FloatingPanel
```

## Distribution

When packaging the app for release:
- The app must be named **endless.txt** (not NvrEndingTxt)
- The distributed `.app` bundle should be `endless.txt.app`
- The DMG for distribution should be `endless.txt.dmg`

### Build and Package

```bash
cd endless.txt

# Clean previous builds to avoid stale file errors
rm -rf ~/Library/Developer/Xcode/DerivedData/NvrEndingTxt-*
rm -rf dist build

# Build release
xcodebuild -project NvrEndingTxt.xcodeproj -scheme NvrEndingTxt -configuration Release build

# Copy to dist folder
BUILD_DIR=$(xcodebuild -project NvrEndingTxt.xcodeproj -scheme NvrEndingTxt -configuration Release -showBuildSettings 2>/dev/null | grep ' BUILT_PRODUCTS_DIR' | awk '{print $3}')
mkdir -p dist
cp -R "$BUILD_DIR/NvrEndingTxt.app" dist/

# CRITICAL: Re-sign the app with consistent code signature
# The Sparkle framework comes pre-signed, which can cause Team ID mismatch errors.
# This step ensures all nested frameworks use the same ad-hoc signature.
cd dist
xattr -cr NvrEndingTxt.app
codesign --force --deep --sign - NvrEndingTxt.app
codesign --verify --deep --strict NvrEndingTxt.app

# Rename and create DMG
cp -R NvrEndingTxt.app "endless.txt.app"
mkdir -p dmg_contents
cp -R "endless.txt.app" dmg_contents/
ln -sf /Applications dmg_contents/Applications
hdiutil create -volname "endless.txt" -srcfolder dmg_contents -ov -format UDZO endless.txt.dmg
rm -rf dmg_contents
```

### Code Signing Notes

**Important:** The app bundles the Sparkle framework for auto-updates. Sparkle comes with its own code signature from the Sparkle developers. When distributing without an Apple Developer ID:

1. The main app is signed ad-hoc (no Team ID)
2. Sparkle has a different signature origin
3. macOS will refuse to load the framework due to "different Team IDs" error

**Solution:** Always run `codesign --force --deep --sign -` on the final `.app` bundle before distribution. This re-signs all nested frameworks with a consistent ad-hoc signature.

### Create GitHub Release

```bash
gh release create v1.x.x --title "endless.txt v1.x.x" --notes "Release notes here" endless.txt.dmg
```

Note: The internal Xcode project uses `NvrEndingTxt` as the target name, but the user-facing app name is `endless.txt` (set via `CFBundleDisplayName` in Info.plist). The `.app` bundle must be renamed after building.

## Git Commits

Do not include "Co-Authored-By: Claude" or any Claude co-author mentions in commit messages.
