import SwiftUI
import ServiceManagement
import Carbon

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var launchAtLogin: Bool = false

    var body: some View {
        TabView {
            GeneralSettingsView(launchAtLogin: $launchAtLogin)
                .tabItem {
                    Label("General", systemImage: "gear")
                }

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
        }
        .frame(width: 440, height: 360)
        .onAppear {
            if #available(macOS 13.0, *) {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
    }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
    @Binding var launchAtLogin: Bool
    @ObservedObject private var settings = AppSettings.shared
    @State private var showFilePicker = false
    @State private var loginItemStatus: String = ""
    @State private var showLoginItemAlert = false

    var body: some View {
        ScrollView {
            Form {
                Section("Startup") {
                    Toggle("Launch at login", isOn: $launchAtLogin)
                        .onChange(of: launchAtLogin) { newValue in
                            updateLaunchAtLogin(enabled: newValue)
                        }

                    if !loginItemStatus.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: loginItemStatus == "enabled" ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                                .foregroundColor(loginItemStatus == "enabled" ? .green : .orange)
                                .font(.caption)
                            Text(loginItemStatusText)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if loginItemStatus == "requiresApproval" {
                        Button("Open System Settings") {
                            openLoginItemsSettings()
                        }
                        .font(.caption)
                    }
                }

                Section("Storage") {
                    HStack {
                        Text(settings.fileLocation.isEmpty
                             ? "~/Documents/nvr-ending.txt"
                             : settings.fileLocation)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)

                        Spacer()

                        Button("Change") {
                            showFilePicker = true
                        }
                        .font(.caption)

                        if !settings.fileLocation.isEmpty {
                            Button("Reset") {
                                settings.fileLocation = ""
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    }

                    Button("Reveal in Finder") {
                        revealFile()
                    }
                    .font(.caption)
                }

                Section("Timezone") {
                    Picker("Timezone", selection: $settings.timezoneId) {
                        ForEach(TimezoneOption.common) { option in
                            Text(option.label).tag(option.id)
                        }
                    }
                    .labelsHidden()

                    Text("Preview: \(currentTimePreview)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .scrollIndicators(.hidden)
        .onAppear {
            checkLoginItemStatus()
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.plainText],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                settings.fileLocation = url.path
            }
        }
        .alert("Login Item Requires Approval", isPresented: $showLoginItemAlert) {
            Button("Open System Settings") {
                openLoginItemsSettings()
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Enable NvrEndingTxt in System Settings > General > Login Items")
        }
    }

    private var loginItemStatusText: String {
        switch loginItemStatus {
        case "enabled": return "Will launch at login"
        case "requiresApproval": return "Requires approval"
        default: return ""
        }
    }

    private var currentTimePreview: String {
        let formatter = DateFormatter()
        formatter.dateFormat = settings.timestampFormat
        formatter.timeZone = settings.timezone
        return formatter.string(from: Date())
    }

    private func checkLoginItemStatus() {
        if #available(macOS 13.0, *) {
            switch SMAppService.mainApp.status {
            case .enabled:
                loginItemStatus = "enabled"
                launchAtLogin = true
            case .requiresApproval:
                loginItemStatus = "requiresApproval"
            case .notRegistered, .notFound:
                loginItemStatus = ""
                launchAtLogin = false
            @unknown default:
                loginItemStatus = ""
            }
        }
    }

    private func updateLaunchAtLogin(enabled: Bool) {
        if #available(macOS 13.0, *) {
            do {
                if enabled {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    checkLoginItemStatus()
                    if loginItemStatus == "requiresApproval" {
                        showLoginItemAlert = true
                    }
                }
            } catch {
                checkLoginItemStatus()
            }
        }
    }

    private func openLoginItemsSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
            NSWorkspace.shared.open(url)
        }
    }

    private func revealFile() {
        NSWorkspace.shared.selectFile(settings.documentURL.path, inFileViewerRootedAtPath: "")
    }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            Form {
                Section("Theme") {
                    Picker("Color Theme", selection: $settings.themeName) {
                        ForEach(AppTheme.allCases) { theme in
                            HStack(spacing: 8) {
                                HStack(spacing: 3) {
                                    Circle().fill(theme.backgroundColor).frame(width: 10, height: 10)
                                        .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
                                    Circle().fill(theme.textColor).frame(width: 10, height: 10)
                                    Circle().fill(theme.accentColor).frame(width: 10, height: 10)
                                }
                                Text(theme.rawValue)
                            }
                            .tag(theme.rawValue)
                        }
                    }
                    .pickerStyle(.radioGroup)
                }

                Section("Font") {
                    Picker("Family", selection: $settings.fontName) {
                        Text("SF Mono").tag("SF Mono")
                        Text("Menlo").tag("Menlo")
                        Text("Monaco").tag("Monaco")
                        Text("Courier New").tag("Courier New")
                    }

                    HStack {
                        Text("Size")
                        Slider(value: $settings.fontSize, in: 10...18, step: 1)
                        Text("\(Int(settings.fontSize))")
                            .monospacedDigit()
                            .frame(width: 24)
                    }
                }

                Section("Preview") {
                    ThemePreviewView()
                        .frame(height: 50)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                }
            }
            .formStyle(.grouped)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var isRecording = false
    @State private var recordedShortcut: ShortcutKey?

    var body: some View {
        ScrollView {
            Form {
                Section("Global Shortcut") {
                    HStack {
                        Text("Open/Close")
                        Spacer()
                        ShortcutRecorderView(
                            shortcut: settings.toggleShortcut,
                            isRecording: $isRecording
                        ) { newShortcut in
                            settings.toggleShortcut = newShortcut
                        }
                    }
                }

                Section("In-App Shortcuts") {
                    HStack {
                        Text("Submit Entry")
                        Spacer()
                        KeyboardShortcutBadge(shortcut: "⌘ ↵")
                    }

                    HStack {
                        Text("Dismiss")
                        Spacer()
                        KeyboardShortcutBadge(shortcut: "Esc")
                    }

                    HStack {
                        Text("Settings")
                        Spacer()
                        KeyboardShortcutBadge(shortcut: "⌘ ,")
                    }
                }

                Section {
                    Button("Reset to Default") {
                        settings.toggleShortcut = ShortcutKey.defaultToggle
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .formStyle(.grouped)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - Shortcut Recorder

struct ShortcutRecorderView: View {
    let shortcut: ShortcutKey
    @Binding var isRecording: Bool
    let onRecord: (ShortcutKey) -> Void

    @State private var eventMonitor: Any?

    var body: some View {
        Button(action: {
            isRecording.toggle()
            if isRecording {
                startRecording()
            } else {
                stopRecording()
            }
        }) {
            Text(isRecording ? "Press shortcut..." : shortcut.displayString)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 100)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(isRecording ? Color.accentColor.opacity(0.2) : Color(nsColor: .controlBackgroundColor))
                .cornerRadius(4)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isRecording ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func startRecording() {
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Get modifiers
            var modifiers: UInt32 = 0
            if event.modifierFlags.contains(.command) { modifiers |= UInt32(cmdKey) }
            if event.modifierFlags.contains(.shift) { modifiers |= UInt32(shiftKey) }
            if event.modifierFlags.contains(.option) { modifiers |= UInt32(optionKey) }
            if event.modifierFlags.contains(.control) { modifiers |= UInt32(controlKey) }

            // Require at least one modifier
            if modifiers != 0 && event.keyCode != 53 { // Not just Escape
                let newShortcut = ShortcutKey(keyCode: UInt32(event.keyCode), modifiers: modifiers)
                DispatchQueue.main.async {
                    onRecord(newShortcut)
                    isRecording = false
                    stopRecording()
                }
                return nil
            }

            // Escape cancels
            if event.keyCode == 53 {
                DispatchQueue.main.async {
                    isRecording = false
                    stopRecording()
                }
                return nil
            }

            return event
        }
    }

    private func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}

struct KeyboardShortcutBadge: View {
    let shortcut: String

    var body: some View {
        Text(shortcut)
            .font(.system(.caption, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(4)
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
    }
}

// MARK: - Theme Preview

struct ThemePreviewView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("[2024-02-03 14:30] Sample #idea")
                .font(.custom(settings.fontName, size: settings.fontSize - 1))
                .foregroundColor(settings.theme.textColor)
            Text("Quick thought...")
                .font(.custom(settings.fontName, size: settings.fontSize - 2))
                .foregroundColor(settings.theme.secondaryTextColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(settings.theme.backgroundColor)
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: 10) {
            Spacer()

            Image(systemName: "text.alignleft")
                .font(.system(size: 36))
                .foregroundColor(.accentColor)

            Text("nvr-ending.txt")
                .font(.title3.bold())

            Text("Infinite thought capture")
                .font(.caption)
                .foregroundColor(.secondary)

            Text("v1.0.0")
                .font(.caption2)
                .foregroundColor(.secondary)

            Spacer()

            VStack(spacing: 6) {
                HStack(spacing: 4) {
                    Text("Built by")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Link("@starigade", destination: URL(string: "https://github.com/oahnuj")!)
                        .font(.caption2)
                }

                HStack(spacing: 4) {
                    Text("Inspired by")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Link("Jeff Huang", destination: URL(string: "https://jeffhuang.com/productivity_text_file/")!)
                        .font(.caption2)
                }
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
}
