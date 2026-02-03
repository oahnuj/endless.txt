import SwiftUI

struct ContentView: View {
    @ObservedObject private var fileService = FileService.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Drag handle area at top (for borderless window)
                DragHandleView()
                    .frame(height: 20)

                // Main editor area - 70% of remaining height
                EditorView(content: $fileService.content)
                    .frame(height: (geometry.size.height - 21) * 0.7)

                // Subtle separator - no extra spacing
                Rectangle()
                    .fill(settings.theme.secondaryTextColor.opacity(0.2))
                    .frame(height: 1)

                // Quick entry at bottom - 30% of remaining height
                QuickEntryView()
                    .frame(height: (geometry.size.height - 21) * 0.3)
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .background(settings.theme.backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
    @ObservedObject private var fileService = FileService.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                TextEditor(text: $content)
                    .font(.custom(settings.fontName, size: settings.fontSize))
                    .foregroundColor(settings.theme.textColor)
                    .scrollContentBackground(.hidden)
                    .scrollDisabled(true)
                    .frame(minHeight: 250)
                    .onChange(of: content) { _ in
                        fileService.save()
                    }

                // Anchor for scrolling to bottom
                Color.clear
                    .frame(height: 1)
                    .id("bottom")
            }
            .scrollIndicators(.hidden)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .scrollToBottom)) { _ in
                withAnimation {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
        .padding(.horizontal, 12)
        .background(settings.theme.backgroundColor)
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let scrollToBottom = Notification.Name("scrollToBottom")
}

#Preview {
    ContentView()
        .frame(width: 450, height: 550)
}
