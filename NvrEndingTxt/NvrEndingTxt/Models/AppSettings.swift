import Foundation
import SwiftUI

// MARK: - Theme Definition

enum AppTheme: String, CaseIterable, Identifiable {
    case light = "Light"
    case dark = "Dark"
    case solarizedDark = "Solarized Dark"
    case monokai = "Monokai"
    case nord = "Nord"

    var id: String { rawValue }

    var backgroundColor: Color {
        switch self {
        case .light: return Color(hex: "FFFFFF")
        case .dark: return Color(hex: "1E1E1E")
        case .solarizedDark: return Color(hex: "002B36")
        case .monokai: return Color(hex: "272822")
        case .nord: return Color(hex: "2E3440")
        }
    }

    var textColor: Color {
        switch self {
        case .light: return Color(hex: "1E1E1E")
        case .dark: return Color(hex: "D4D4D4")
        case .solarizedDark: return Color(hex: "839496")
        case .monokai: return Color(hex: "F8F8F2")
        case .nord: return Color(hex: "ECEFF4")
        }
    }

    var secondaryTextColor: Color {
        switch self {
        case .light: return Color(hex: "6E6E6E")
        case .dark: return Color(hex: "808080")
        case .solarizedDark: return Color(hex: "586E75")
        case .monokai: return Color(hex: "75715E")
        case .nord: return Color(hex: "4C566A")
        }
    }

    var accentColor: Color {
        switch self {
        case .light: return Color(hex: "007AFF")
        case .dark: return Color(hex: "569CD6")
        case .solarizedDark: return Color(hex: "268BD2")
        case .monokai: return Color(hex: "A6E22E")
        case .nord: return Color(hex: "88C0D0")
        }
    }

    var inputBackgroundColor: Color {
        switch self {
        case .light: return Color(hex: "F5F5F5")
        case .dark: return Color(hex: "252526")
        case .solarizedDark: return Color(hex: "073642")
        case .monokai: return Color(hex: "1E1F1C")
        case .nord: return Color(hex: "3B4252")
        }
    }

    var timestampColor: Color {
        switch self {
        case .light: return Color(hex: "999999")
        case .dark: return Color(hex: "666666")
        case .solarizedDark: return Color(hex: "657B83")
        case .monokai: return Color(hex: "75715E")
        case .nord: return Color(hex: "616E88")
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = ((int >> 24) & 0xFF, (int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Common Timezones

struct TimezoneOption: Identifiable, Hashable {
    let id: String
    let label: String
    let identifier: String

    static let common: [TimezoneOption] = [
        TimezoneOption(id: "system", label: "System Default", identifier: ""),
        TimezoneOption(id: "utc", label: "UTC", identifier: "UTC"),
        TimezoneOption(id: "pt", label: "Pacific Time (PT)", identifier: "America/Los_Angeles"),
        TimezoneOption(id: "mt", label: "Mountain Time (MT)", identifier: "America/Denver"),
        TimezoneOption(id: "ct", label: "Central Time (CT)", identifier: "America/Chicago"),
        TimezoneOption(id: "et", label: "Eastern Time (ET)", identifier: "America/New_York"),
        TimezoneOption(id: "gmt", label: "GMT (London)", identifier: "Europe/London"),
        TimezoneOption(id: "cet", label: "CET (Paris/Berlin)", identifier: "Europe/Paris"),
        TimezoneOption(id: "jst", label: "JST (Tokyo)", identifier: "Asia/Tokyo"),
        TimezoneOption(id: "sgt", label: "SGT (Singapore)", identifier: "Asia/Singapore"),
        TimezoneOption(id: "aest", label: "AEST (Sydney)", identifier: "Australia/Sydney"),
    ]
}

// MARK: - Shortcut Definition

struct ShortcutKey: Equatable {
    var keyCode: UInt32
    var modifiers: UInt32

    // Default: Cmd+Shift+Space
    // cmdKey = 0x0100, shiftKey = 0x0200, so Cmd+Shift = 0x0300
    static let defaultToggle = ShortcutKey(keyCode: 49, modifiers: 0x0300)

    var displayString: String {
        var parts: [String] = []
        if modifiers & 0x0100 != 0 { parts.append("⌃") } // Control
        if modifiers & 0x0800 != 0 { parts.append("⌥") } // Option
        if modifiers & 0x0200 != 0 { parts.append("⇧") } // Shift
        // Build modifier string based on Carbon constants
        // cmdKey = 0x0100, shiftKey = 0x0200, optionKey = 0x0800, controlKey = 0x1000
        parts = []
        if modifiers & 0x1000 != 0 { parts.append("⌃") } // Control
        if modifiers & 0x0800 != 0 { parts.append("⌥") } // Option
        if modifiers & 0x0200 != 0 { parts.append("⇧") } // Shift
        if modifiers & 0x0100 != 0 { parts.append("⌘") } // Command
        if modifiers == 0x0900 { parts = ["⌘", "⌥"] }
        if modifiers == 0x0D00 { parts = ["⌘", "⌥", "⇧"] }
        if modifiers == 0x0100 { parts = ["⌘"] }

        parts.append(keyCodeToString(keyCode))
        return parts.joined(separator: " ")
    }

    private func keyCodeToString(_ code: UInt32) -> String {
        let keyMap: [UInt32: String] = [
            49: "Space", 36: "↵", 53: "Esc", 51: "⌫",
            126: "↑", 125: "↓", 123: "←", 124: "→",
            0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
            8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
            16: "Y", 17: "T", 18: "1", 19: "2", 20: "3", 21: "4", 22: "6",
            23: "5", 24: "=", 25: "9", 26: "7", 27: "-", 28: "8", 29: "0",
            30: "]", 31: "O", 32: "U", 33: "[", 34: "I", 35: "P",
            37: "L", 38: "J", 39: "'", 40: "K", 41: ";", 42: "\\",
            43: ",", 44: "/", 45: "N", 46: "M", 47: ".",
        ]
        return keyMap[code] ?? "?"
    }
}

// MARK: - App Settings

final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @AppStorage("fontSize") var fontSize: Double = 13
    @AppStorage("fontName") var fontName: String = "SF Mono"
    @AppStorage("showTimestamps") var showTimestamps: Bool = true
    @AppStorage("timestampFormat") var timestampFormat: String = "yyyy-MM-dd HH:mm"
    @AppStorage("themeName") var themeName: String = "Light"
    @AppStorage("timezoneId") var timezoneId: String = "system"
    @AppStorage("fileLocation") var fileLocation: String = ""

    // Shortcut settings
    @AppStorage("hotkeyCode") var hotkeyCode: Int = 49 // Space
    @AppStorage("hotkeyModifiers") var hotkeyModifiers: Int = 0x0300 // Cmd+Shift (0x0100 | 0x0200)

    var toggleShortcut: ShortcutKey {
        get { ShortcutKey(keyCode: UInt32(hotkeyCode), modifiers: UInt32(hotkeyModifiers)) }
        set {
            hotkeyCode = Int(newValue.keyCode)
            hotkeyModifiers = Int(newValue.modifiers)
            // Post notification to update hotkey
            NotificationCenter.default.post(name: .hotkeyChanged, object: newValue)
        }
    }

    var theme: AppTheme {
        AppTheme(rawValue: themeName) ?? .light
    }

    var timezone: TimeZone {
        if timezoneId == "system" || timezoneId.isEmpty {
            return .current
        }
        if let option = TimezoneOption.common.first(where: { $0.id == timezoneId }) {
            return TimeZone(identifier: option.identifier) ?? .current
        }
        return .current
    }

    var documentURL: URL {
        if !fileLocation.isEmpty {
            return URL(fileURLWithPath: fileLocation)
        }
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsPath.appendingPathComponent("nvr-ending.txt")
    }

    private init() {}
}

extension Notification.Name {
    static let hotkeyChanged = Notification.Name("hotkeyChanged")
}
