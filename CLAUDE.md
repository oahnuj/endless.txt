# NvrEndingTxt

A minimal Mac menu bar app for infinite thought capture, inspired by Jeff Huang's productivity text file system.

## Project Structure

```
NvrEndingTxt/
├── NvrEndingTxt/
│   ├── NvrEndingTxtApp.swift      # App entry point
│   ├── AppDelegate.swift          # Menu bar, hotkey, panel management
│   ├── Info.plist                 # LSUIElement = true (no dock icon)
│   ├── NvrEndingTxt.entitlements
│   ├── Models/
│   │   └── AppSettings.swift      # User preferences with @AppStorage
│   ├── Views/
│   │   ├── ContentView.swift      # Main editor container
│   │   ├── QuickEntryView.swift   # Bottom quick capture field
│   │   └── SettingsView.swift     # Preferences window
│   └── Services/
│       ├── FileService.swift      # Text file read/write with debounce
│       ├── HotkeyManager.swift    # Carbon API global hotkey
│       └── LaunchAtLoginManager.swift  # SMAppService wrapper
├── project.yml                    # XcodeGen configuration
└── setup.sh                       # Project setup script

## Key Patterns

- **Single file storage**: ~/Documents/nvr-ending.txt
- **Global hotkey**: ⌘+Shift+Space (Carbon API, no dependencies)
- **Menu bar only**: LSUIElement = true, NSApp.setActivationPolicy(.accessory)
- **Floating panel**: NSPanel with .nonactivatingPanel style
- **Auto-save**: 500ms debounce on text changes

## Building

1. Install XcodeGen: `brew install xcodegen`
2. Generate project: `cd NvrEndingTxt && xcodegen generate`
3. Open: `open NvrEndingTxt.xcodeproj`
4. Build & Run (⌘R)

## Architecture Notes

- Uses @NSApplicationDelegateAdaptor for AppKit integration in SwiftUI lifecycle
- FileService is a singleton for consistent state across views
- NotificationCenter used for cross-view communication (focusQuickEntry, scrollToBottom)
- Carbon framework used for global hotkeys (alternative to third-party libs)

## Git Commits

- Do not include "Co-Authored-By: Claude" or any Claude co-author mentions in commit messages
```
