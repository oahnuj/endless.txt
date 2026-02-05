import Foundation
import KeyboardShortcuts
import AppKit

// MARK: - Shortcut Definitions

extension KeyboardShortcuts.Name {
    // Global shortcut (handled separately by HotkeyManager for now)
    // static let toggleApp = Self("toggleApp", default: .init(.space, modifiers: [.command, .shift]))

    // Search
    static let toggleSearch = Self("toggleSearch", default: .init(.f, modifiers: .command))
    static let findNext = Self("findNext", default: .init(.g, modifiers: .command))
    static let findPrevious = Self("findPrevious", default: .init(.g, modifiers: [.command, .shift]))

    // Navigation
    static let previousDay = Self("previousDay", default: .init(.upArrow, modifiers: .command))
    static let nextDay = Self("nextDay", default: .init(.downArrow, modifiers: .command))
    static let previousLineEnd = Self("previousLineEnd", default: .init(.upArrow, modifiers: [.command, .control]))
    static let nextLineEnd = Self("nextLineEnd", default: .init(.downArrow, modifiers: [.command, .control]))

    // Focus (handled by Tab/Shift+Tab, no shortcuts needed)

    // Formatting
    static let toggleStrikethrough = Self("toggleStrikethrough", default: .init(.x, modifiers: [.command, .shift]))
    static let toggleCheckbox = Self("toggleCheckbox", default: .init(.t, modifiers: [.command, .shift]))

    // Display
    static let toggleTimestamps = Self("toggleTimestamps", default: .init(.t, modifiers: [.command, .option]))

    // Help
    static let showShortcutsHelp = Self("showShortcutsHelp", default: .init(.slash, modifiers: [.command, .shift]))

    // Hashtag features
    static let tagJump = Self("tagJump", default: .init(.j, modifiers: .command))
}

// MARK: - Shortcuts Manager

final class KeyboardShortcutsManager {
    static let shared = KeyboardShortcutsManager()

    private init() {}

    func setupShortcuts() {
        // Clean up stale shortcuts from previous versions
        cleanupLegacyShortcuts()

        // Search
        KeyboardShortcuts.onKeyDown(for: .toggleSearch) {
            NotificationCenter.default.post(name: .toggleSearch, object: nil)
        }

        KeyboardShortcuts.onKeyDown(for: .findNext) {
            NotificationCenter.default.post(name: .findNext, object: nil)
        }

        KeyboardShortcuts.onKeyDown(for: .findPrevious) {
            NotificationCenter.default.post(name: .findPrevious, object: nil)
        }

        // Navigation
        KeyboardShortcuts.onKeyDown(for: .previousDay) {
            NotificationCenter.default.post(name: .scrollToPreviousDay, object: nil)
        }

        KeyboardShortcuts.onKeyDown(for: .nextDay) {
            NotificationCenter.default.post(name: .scrollToNextDay, object: nil)
        }

        KeyboardShortcuts.onKeyDown(for: .previousLineEnd) {
            NotificationCenter.default.post(name: .moveToPreviousLineEnd, object: nil)
        }

        KeyboardShortcuts.onKeyDown(for: .nextLineEnd) {
            NotificationCenter.default.post(name: .moveToNextLineEnd, object: nil)
        }

        // Formatting
        KeyboardShortcuts.onKeyDown(for: .toggleStrikethrough) {
            NotificationCenter.default.post(name: .toggleStrikethrough, object: nil)
        }

        KeyboardShortcuts.onKeyDown(for: .toggleCheckbox) {
            NotificationCenter.default.post(name: .toggleCheckbox, object: nil)
        }

        // Display
        KeyboardShortcuts.onKeyDown(for: .toggleTimestamps) {
            AppSettings.shared.displayTimestamps.toggle()
        }

        // Help
        KeyboardShortcuts.onKeyDown(for: .showShortcutsHelp) {
            NotificationCenter.default.post(name: .showShortcutsHelp, object: nil)
        }

        // Hashtag features
        KeyboardShortcuts.onKeyDown(for: .tagJump) {
            NotificationCenter.default.post(name: .tagJump, object: nil)
        }
    }

    /// Remove shortcuts from previous versions that are no longer used
    private func cleanupLegacyShortcuts() {
        let legacyKeys = [
            "KeyboardShortcuts_focusQuickNote"
        ]
        for key in legacyKeys {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    func disableShortcuts() {
        KeyboardShortcuts.disable(.toggleSearch)
        KeyboardShortcuts.disable(.findNext)
        KeyboardShortcuts.disable(.findPrevious)
        KeyboardShortcuts.disable(.previousDay)
        KeyboardShortcuts.disable(.nextDay)
        KeyboardShortcuts.disable(.previousLineEnd)
        KeyboardShortcuts.disable(.nextLineEnd)
        KeyboardShortcuts.disable(.toggleStrikethrough)
        KeyboardShortcuts.disable(.toggleCheckbox)
        KeyboardShortcuts.disable(.toggleTimestamps)
        KeyboardShortcuts.disable(.showShortcutsHelp)
        KeyboardShortcuts.disable(.tagJump)
    }
}
