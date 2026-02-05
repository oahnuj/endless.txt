import SwiftUI

struct ContentView: View {
    @ObservedObject private var fileService = FileService.shared
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var searchState = SearchState()
    @ObservedObject private var hashtagState = HashtagState.shared
    @State private var showShortcutsHelp = false

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Main content
                VStack(spacing: 0) {
                    // Drag handle area at top (for borderless window)
                    DragHandleView()
                        .frame(height: 20)

                    // Main editor area - 70% of remaining height
                    EditorView(content: $fileService.content, searchState: searchState, hashtagState: hashtagState)
                        .frame(height: (geometry.size.height - 21) * 0.7)

                    // Subtle separator - no extra spacing
                    Rectangle()
                        .fill(settings.theme.secondaryTextColor.opacity(0.2))
                        .frame(height: 1)

                    // Quick entry at bottom - 30% of remaining height
                    QuickEntryView()
                        .frame(height: (geometry.size.height - 21) * 0.3)
                }

                // Search bar overlay (top-right, translucent)
                if searchState.isVisible {
                    SearchBarView(searchState: searchState)
                        .padding(.top, 28)
                        .padding(.trailing, 12)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Shortcuts help overlay
                if showShortcutsHelp {
                    ShortcutsHelpView(isVisible: $showShortcutsHelp)
                        .transition(.opacity)
                }
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .background(settings.theme.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onReceive(NotificationCenter.default.publisher(for: .toggleSearch)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                searchState.isVisible.toggle()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSearch)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                searchState.isVisible = true
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissSearch)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                // Don't reset query - keep it cached
                searchState.isVisible = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showShortcutsHelp)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                showShortcutsHelp.toggle()
            }
        }
    }
}

struct DragHandleView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack {
            Spacer()
            // Subtle drag indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(settings.theme.secondaryTextColor.opacity(0.3))
                .frame(width: 36, height: 4)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(settings.theme.backgroundColor)
    }
}

struct EditorView: View {
    @Binding var content: String
    @ObservedObject var searchState: SearchState
    @ObservedObject var hashtagState: HashtagState
    @ObservedObject private var fileService = FileService.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        EditorTextView(text: $content, searchState: searchState, hashtagState: hashtagState)
            .onChange(of: content) { _ in
                fileService.save()
            }
            .padding(.horizontal, 4)
            .background(settings.theme.backgroundColor)
    }
}

// MARK: - Shortcuts Help View

struct ShortcutsHelpView: View {
    @Binding var isVisible: Bool
    @ObservedObject private var settings = AppSettings.shared

    private let leftColumn: [(String, [(String, String)])] = [
        ("General", [
            ("⌘↵", "Submit"),
            ("Esc", "Close"),
            ("⌘,", "Settings"),
            ("⌘?", "This help"),
        ]),
        ("Focus", [
            ("Tab", "Next field"),
            ("⇧Tab", "Previous field"),
        ]),
        ("Search", [
            ("⌘F", "Find"),
            ("⌘G", "Next match"),
            ("⇧⌘G", "Prev match"),
        ]),
    ]

    private let rightColumn: [(String, [(String, String)])] = [
        ("Navigation", [
            ("⌘↑", "Prev entry"),
            ("⌘↓", "Next entry"),
            ("⌃⌘↑", "Prev line end"),
            ("⌃⌘↓", "Next line end"),
            ("⌘J", "Jump to tag"),
        ]),
        ("Formatting", [
            ("⇧⌘X", "Strikethrough"),
            ("⇧⌘T", "Checkbox"),
            ("⌥⌘T", "Timestamps"),
        ]),
    ]

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isVisible = false
                    }
                }

            // Shortcuts panel
            VStack(spacing: 10) {
                // Header
                HStack {
                    Text("Shortcuts")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(settings.theme.textColor)
                    Spacer()
                    Text("⌘?")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(settings.theme.secondaryTextColor)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 2)
                        .background(settings.theme.inputBackgroundColor)
                        .cornerRadius(3)
                }

                // Two-column layout
                HStack(alignment: .top, spacing: 14) {
                    ShortcutsColumn(sections: leftColumn, theme: settings.theme)
                    ShortcutsColumn(sections: rightColumn, theme: settings.theme)
                }
            }
            .padding(12)
            .background(settings.theme.backgroundColor)
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.3), radius: 15, x: 0, y: 8)
            .fixedSize()
        }
    }
}

struct ShortcutsColumn: View {
    let sections: [(String, [(String, String)])]
    let theme: AppTheme

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(sections, id: \.0) { section in
                VStack(alignment: .leading, spacing: 2) {
                    Text(section.0)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(theme.accentColor)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    ForEach(section.1, id: \.0) { shortcut in
                        HStack(spacing: 5) {
                            Text(shortcut.0)
                                .font(.system(size: 10, design: .monospaced))
                                .frame(width: 38, alignment: .center)
                                .padding(.vertical, 2)
                                .background(theme.inputBackgroundColor)
                                .cornerRadius(3)
                                .foregroundColor(theme.textColor)

                            Text(shortcut.1)
                                .font(.system(size: 10))
                                .foregroundColor(theme.secondaryTextColor)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let scrollToBottom = Notification.Name("scrollToBottom")
    static let toggleSearch = Notification.Name("toggleSearch")
}

#Preview {
    ContentView()
        .frame(width: 450, height: 550)
}
