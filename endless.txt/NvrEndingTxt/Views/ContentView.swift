import SwiftUI

struct ContentView: View {
    @ObservedObject private var fileService = FileService.shared
    @ObservedObject private var settings = AppSettings.shared
    @StateObject private var searchState = SearchState()

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topTrailing) {
                // Main content
                VStack(spacing: 0) {
                    // Drag handle area at top (for borderless window)
                    DragHandleView()
                        .frame(height: 20)

                    // Main editor area - 70% of remaining height
                    EditorView(content: $fileService.content, searchState: searchState)
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
    @ObservedObject private var fileService = FileService.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        EditorTextView(text: $content, searchState: searchState)
            .onChange(of: content) { _ in
                fileService.save()
            }
            .padding(.horizontal, 4)
            .background(settings.theme.backgroundColor)
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
