import SwiftUI

struct QuickEntryView: View {
    @State private var quickText: String = ""
    @State private var currentTime: String = ""
    @FocusState private var isFocused: Bool
    @ObservedObject private var fileService = FileService.shared
    @ObservedObject private var settings = AppSettings.shared

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Live timestamp
            Text(currentTime)
                .font(.custom(settings.fontName, size: 11))
                .foregroundColor(settings.theme.timestampColor)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

            // Text editor for quick entry - no scroll indicators
            TextEditor(text: $quickText)
                .font(.custom(settings.fontName, size: settings.fontSize))
                .foregroundColor(settings.theme.textColor)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .focused($isFocused)
                .padding(.horizontal, 12)
                .padding(.bottom, 8)
        }
        .background(settings.theme.inputBackgroundColor)
        .onAppear {
            updateTime()
            // Auto-focus on appear
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                isFocused = true
            }
        }
        .onReceive(timer) { _ in
            updateTime()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusQuickEntry)) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isFocused = true
            }
        }
        // Handle Cmd+Enter to submit
        .background(
            Button("") {
                submitEntry()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .hidden()
        )
    }

    private func updateTime() {
        let formatter = DateFormatter()
        formatter.dateFormat = settings.timestampFormat
        formatter.timeZone = settings.timezone
        currentTime = formatter.string(from: Date())
    }

    private func submitEntry() {
        guard !quickText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        fileService.appendEntry(quickText)
        quickText = ""

        // Scroll to bottom after appending
        NotificationCenter.default.post(name: .scrollToBottom, object: nil)
    }
}

#Preview {
    QuickEntryView()
        .frame(width: 450, height: 150)
}
