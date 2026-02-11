import SwiftUI
import ServiceManagement
import Carbon
import KeyboardShortcuts

// MARK: - Hide Scrollbar Modifier

struct HideScrollbar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                DispatchQueue.main.async {
                    hideScrollbars()
                }
            }
    }

    private func hideScrollbars() {
        for window in NSApplication.shared.windows {
            hideScrollbarsIn(view: window.contentView)
        }
    }

    private func hideScrollbarsIn(view: NSView?) {
        guard let view = view else { return }

        if let scrollView = view as? NSScrollView {
            scrollView.hasVerticalScroller = false
            scrollView.hasHorizontalScroller = false
        }

        for subview in view.subviews {
            hideScrollbarsIn(view: subview)
        }
    }
}

extension View {
    func hideScrollbar() -> some View {
        modifier(HideScrollbar())
    }
}

enum SettingsTab: Int, CaseIterable {
    case general = 0
    case appearance = 1
    case shortcuts = 2
    case about = 3
}

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var launchAtLogin: Bool = false
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: $selectedTab) {
            GeneralSettingsView(launchAtLogin: $launchAtLogin)
                .tabItem {
                    Label("General", systemImage: "gear")
                }
                .tag(SettingsTab.general)

            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }
                .tag(SettingsTab.appearance)

            ShortcutsSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }
                .tag(SettingsTab.shortcuts)

            AboutView()
                .tabItem {
                    Label("About", systemImage: "info.circle")
                }
                .tag(SettingsTab.about)
        }
        .frame(width: 460, height: 480)
        .hideScrollbar()
        .onAppear {
            if #available(macOS 13.0, *) {
                launchAtLogin = SMAppService.mainApp.status == .enabled
            }
        }
        .background(TabKeyHandler(selectedTab: $selectedTab))
    }
}

// MARK: - Tab Key Handler

struct TabKeyHandler: NSViewRepresentable {
    @Binding var selectedTab: SettingsTab

    func makeNSView(context: Context) -> NSView {
        let view = TabKeyView()
        view.onTab = { [self] shift in
            cycleTab(shift: shift)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private func cycleTab(shift: Bool) {
        let allTabs = SettingsTab.allCases
        guard let currentIndex = allTabs.firstIndex(of: selectedTab) else { return }

        let nextIndex: Int
        if shift {
            nextIndex = currentIndex == 0 ? allTabs.count - 1 : currentIndex - 1
        } else {
            nextIndex = (currentIndex + 1) % allTabs.count
        }

        selectedTab = allTabs[nextIndex]
    }
}

class TabKeyView: NSView {
    var onTab: ((Bool) -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 { // Tab
            let shift = event.modifierFlags.contains(.shift)
            onTab?(shift)
        } else {
            super.keyDown(with: event)
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
    @State private var loginItemError: String = ""
    @State private var currentTimePreview: String = ""

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
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

                    if !loginItemError.isEmpty {
                        Text(loginItemError)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    if loginItemStatus == "requiresApproval" {
                        Button("Open System Settings") {
                            openLoginItemsSettings()
                        }
                        .font(.caption)
                    }
                }

                Section("Storage") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(settings.fileLocation.isEmpty
                             ? "~/Documents/endless.txt"
                             : settings.fileLocation)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .cornerRadius(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 0.5)
                            )
                            .lineLimit(1)
                            .truncationMode(.middle)

                        HStack(spacing: 10) {
                            Button("Change…") {
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

                            Spacer()

                            Button("Reveal in Finder") {
                                revealFile()
                            }
                            .font(.caption)

                            Button("Reload") {
                                FileService.shared.loadContent()
                            }
                            .font(.caption)
                        }
                    }
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
                        .monospacedDigit()
                }

                Section("Timestamps") {
                    Toggle("Display timestamps", isOn: $settings.displayTimestamps)
                        .help("Toggle with ⌥⌘T")

                    Toggle("Add timestamps to new entries", isOn: $settings.addTimestampsToEntries)

                    if settings.addTimestampsToEntries {
                        Picker("Position", selection: $settings.timestampPosition) {
                            Text("Inline").tag("left")
                            Text("Above").tag("top")
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Entries") {
                    Toggle("Auto-insert day separator", isOn: $settings.autoInsertDaySeparator)
                        .help("Adds \"---\" between entries from different days")

                    Toggle("Compact view", isOn: $settings.compactEntries)
                        .help("Remove extra line breaks between entries")
                }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.never)
        .onAppear {
            checkLoginItemStatus()
            updateTimePreview()
        }
        .onReceive(timer) { _ in
            updateTimePreview()
        }
        .onChange(of: settings.timezoneId) { _ in
            updateTimePreview()
        }
        .onChange(of: settings.timestampFormat) { _ in
            updateTimePreview()
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
            Text("Enable endless.txt in System Settings > General > Login Items")
        }
    }

    private var loginItemStatusText: String {
        switch loginItemStatus {
        case "enabled": return "Will launch at login"
        case "requiresApproval": return "Requires approval"
        default: return ""
        }
    }

    private func updateTimePreview() {
        let formatter = DateFormatter()
        // Always show seconds in preview for a "live" feel
        formatter.dateFormat = settings.timestampFormat.contains("ss")
            ? settings.timestampFormat
            : settings.timestampFormat + ":ss"
        formatter.timeZone = settings.timezone
        currentTimePreview = formatter.string(from: Date())
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
            loginItemError = ""
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
                // Show the error to the user
                loginItemError = "Failed: \(error.localizedDescription)"
                print("Login item error: \(error)")

                // Revert toggle to actual state
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    checkLoginItemStatus()
                }
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
        Form {
            Section("Preview") {
                ThemePreviewView()
                    .frame(height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                    )
            }

            Section("Theme") {
                Picker("Color Theme", selection: $settings.themeName) {
                    ForEach(AppTheme.allCases) { theme in
                        HStack(spacing: 8) {
                            HStack(spacing: 4) {
                                Circle().fill(theme.backgroundColor).frame(width: 12, height: 12)
                                    .overlay(Circle().stroke(Color.gray.opacity(0.3), lineWidth: 0.5))
                                Circle().fill(theme.textColor).frame(width: 12, height: 12)
                                Circle().fill(theme.accentColor).frame(width: 12, height: 12)
                            }
                            Text(theme.rawValue)
                        }
                        .tag(theme.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                .onChange(of: settings.themeName) { _ in
                    // Reset custom text color on theme change so the new theme's
                    // text color takes effect immediately
                    settings.useCustomTextColor = false
                    settings.customTextColorHex = ""
                }
            }

            Section("Text Color") {
                Toggle("Use custom text color", isOn: $settings.useCustomTextColor)
                    .onChange(of: settings.useCustomTextColor) { enabled in
                        if enabled && settings.customTextColorHex.isEmpty {
                            // Initialize to current theme's text color hex
                            settings.customTextColorHex = settings.theme.textColorHex
                        }
                    }

                if settings.useCustomTextColor {
                    ColorPicker("Color", selection: Binding(
                        get: {
                            if settings.customTextColorHex.isEmpty {
                                return settings.theme.textColor
                            }
                            return Color(hex: settings.customTextColorHex)
                        },
                        set: { newColor in
                            if let cgColor = newColor.cgColor,
                               let components = cgColor.components, components.count >= 3 {
                                let r = Int(components[0] * 255)
                                let g = Int(components[1] * 255)
                                let b = Int(components[2] * 255)
                                settings.customTextColorHex = String(format: "%02X%02X%02X", r, g, b)
                            }
                        }
                    ), supportsOpacity: false)
                }
            }

            Section("Window") {
                HStack {
                    Text("Opacity")
                    Slider(value: $settings.windowOpacity, in: 0.3...1.0)
                        .onChange(of: settings.windowOpacity) { _ in
                            NotificationCenter.default.post(name: .windowOpacityChanged, object: nil)
                        }
                    Text("\(Int(round(settings.windowOpacity * 100)))%")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 45, alignment: .trailing)
                }
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
                    Text("\(Int(settings.fontSize))pt")
                        .font(.system(.caption, design: .monospaced))
                        .frame(width: 32, alignment: .trailing)
                }
            }

            Section("Formatting") {
                Toggle("Enable markdown", isOn: $settings.enableMarkdown)
                    .help("**bold**, *italic*, ~~strike~~, __underline__, URLs")
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.never)
    }
}

// MARK: - Shortcuts Settings

struct ShortcutsSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var isRecording = false

    var body: some View {
        Form {
            Section("Global Shortcut") {
                HStack {
                    Text("Open/Close App")
                    Spacer()
                    ShortcutRecorderView(
                        shortcut: settings.toggleShortcut,
                        isRecording: $isRecording
                    ) { newShortcut in
                        settings.toggleShortcut = newShortcut
                    }
                }
            }

            Section("General") {
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

                HStack {
                    Text("Cycle Focus")
                    Spacer()
                    KeyboardShortcutBadge(shortcut: "Tab / ⇧Tab")
                }

                KeyboardShortcuts.Recorder("Toggle Timestamps", name: .toggleTimestamps)
            }

            Section("Search") {
                KeyboardShortcuts.Recorder("Find", name: .toggleSearch)
                KeyboardShortcuts.Recorder("Find Next", name: .findNext)
                KeyboardShortcuts.Recorder("Find Previous", name: .findPrevious)
            }

            Section("Navigation") {
                KeyboardShortcuts.Recorder("Previous Day", name: .previousDay)
                KeyboardShortcuts.Recorder("Next Day", name: .nextDay)
                KeyboardShortcuts.Recorder("Previous Line End", name: .previousLineEnd)
                KeyboardShortcuts.Recorder("Next Line End", name: .nextLineEnd)
                KeyboardShortcuts.Recorder("Jump to Tag", name: .tagJump)
            }

            Section("Formatting") {
                KeyboardShortcuts.Recorder("Toggle Strikethrough", name: .toggleStrikethrough)
                KeyboardShortcuts.Recorder("Toggle Checkbox", name: .toggleCheckbox)
            }

            Section {
                Button("Reset All to Defaults") {
                    KeyboardShortcuts.reset(.toggleSearch, .findNext, .findPrevious,
                                           .previousDay, .nextDay, .previousLineEnd, .nextLineEnd,
                                           .toggleStrikethrough, .toggleCheckbox, .toggleTimestamps,
                                           .tagJump)
                    settings.toggleShortcut = ShortcutKey.defaultToggle
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.never)
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
            .font(.system(size: 13))
            .foregroundColor(.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(nsColor: .windowBackgroundColor))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
            )
    }
}

// MARK: - Theme Preview

struct ThemePreviewView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if settings.timestampPosition == "top" {
                // Top format: timestamp on its own line
                Text("[2024-02-03 14:30]")
                    .font(.custom(settings.fontName, size: settings.fontSize - 2))
                    .foregroundColor(settings.theme.timestampColor)
                Text("Sample thought with #idea tag")
                    .font(.custom(settings.fontName, size: settings.fontSize))
                    .foregroundColor(settings.effectiveTextColor)
            } else {
                // Left format: inline timestamp
                Text("[2024-02-03 14:30] Sample thought with #idea tag")
                    .font(.custom(settings.fontName, size: settings.fontSize))
                    .foregroundColor(settings.effectiveTextColor)
            }
            Text("Another line of text...")
                .font(.custom(settings.fontName, size: settings.fontSize))
                .foregroundColor(settings.theme.secondaryTextColor)
            Text("https://example.com")
                .font(.custom(settings.fontName, size: settings.fontSize - 1))
                .foregroundColor(settings.theme.accentColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(12)
        .background(settings.theme.backgroundColor)
    }
}

// MARK: - About

struct AboutView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()

            Image("AppLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 64, height: 64)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text("endless.txt")
                .font(.title2.bold())

            Text("Infinite thought capture")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary.opacity(0.7))
                .padding(.top, 2)

            Button("Check for Updates...") {
                NotificationCenter.default.post(name: .checkForUpdates, object: nil)
            }
            .buttonStyle(.link)
            .padding(.top, 4)

            Spacer()

            VStack(spacing: 8) {
                HStack(spacing: 4) {
                    Text("Built by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("@starigade", destination: URL(string: "https://github.com/starigade")!)
                        .font(.caption)
                }

                HStack(spacing: 4) {
                    Text("Inspired by")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Link("Jeff Huang", destination: URL(string: "https://jeffhuang.com/productivity_text_file/")!)
                        .font(.caption)
                }
            }
            .padding(.bottom, 8)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    SettingsView()
}
