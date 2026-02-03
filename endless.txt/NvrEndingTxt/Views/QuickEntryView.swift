import SwiftUI
import AppKit

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
            QuickEntryTextEditor(text: $quickText, isFocused: _isFocused)
                .font(.custom(settings.fontName, size: settings.fontSize))
                .foregroundColor(settings.theme.textColor)
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
        // Always show seconds in live display for a "live" feel
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
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

// MARK: - Custom Text Editor with Shift+Tab Support

struct QuickEntryTextEditor: NSViewRepresentable {
    @Binding var text: String
    @FocusState var isFocused: Bool

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = QuickEntryNSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 0)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false

        // Configure text container for word wrap
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true

        scrollView.documentView = textView
        context.coordinator.textView = textView

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        let settings = AppSettings.shared

        // Update text if changed externally
        if textView.string != text && !context.coordinator.isUpdating {
            textView.string = text
        }

        // Apply theme
        textView.font = NSFont(name: settings.fontName, size: settings.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)
        textView.textColor = NSColor(settings.theme.textColor)
        textView.insertionPointColor = NSColor(settings.theme.accentColor)
        textView.backgroundColor = .clear
        scrollView.backgroundColor = .clear

        // Handle focus
        if isFocused {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: QuickEntryTextEditor
        weak var textView: NSTextView?
        var isUpdating = false

        init(_ parent: QuickEntryTextEditor) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            parent.text = textView.string
            isUpdating = false
        }
    }
}

// MARK: - Custom NSTextView with Shift+Tab handling

class QuickEntryNSTextView: NSTextView {
    private var checkboxObserver: NSObjectProtocol?

    convenience init() {
        self.init(frame: .zero)
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupNotifications()
    }

    override init(frame frameRect: NSRect, textContainer container: NSTextContainer?) {
        super.init(frame: frameRect, textContainer: container)
        setupNotifications()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupNotifications()
    }

    private func setupNotifications() {
        // Listen for checkbox toggle when this view has focus
        checkboxObserver = NotificationCenter.default.addObserver(
            forName: .toggleCheckbox,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.window?.firstResponder === self else { return }
            self.toggleCheckbox()
        }
    }

    deinit {
        if let observer = checkboxObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // Note: Most keyboard shortcuts are now handled by KeyboardShortcuts library
    // Only special cases (Shift+Tab, checkbox toggle) are handled here

    private func toggleCheckbox() {
        let selectedRange = selectedRange()
        let content = string as NSString

        // Get line range
        let lineRange = content.lineRange(for: selectedRange)
        let lineText = content.substring(with: lineRange)

        var newLineText: String
        var cursorOffset = 0

        if lineText.contains("[x]") || lineText.contains("[X]") {
            // Remove checkbox
            newLineText = lineText.replacingOccurrences(of: "[x] ", with: "")
                .replacingOccurrences(of: "[X] ", with: "")
            cursorOffset = -4
        } else if lineText.contains("[ ]") {
            // Toggle to checked
            newLineText = lineText.replacingOccurrences(of: "[ ]", with: "[x]")
        } else {
            // Insert checkbox at line start (after any leading whitespace)
            let leadingSpaces = lineText.prefix(while: { $0.isWhitespace && $0 != "\n" })
            let hasNewline = lineText.hasSuffix("\n")
            let baseTrimmed = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
            newLineText = String(leadingSpaces) + "[ ] " + baseTrimmed + (hasNewline ? "\n" : "")
            cursorOffset = 4
        }

        // Replace line
        if shouldChangeText(in: lineRange, replacementString: newLineText) {
            replaceCharacters(in: lineRange, with: newLineText)
            didChangeText()

            // Adjust cursor position
            let newCursorPos = max(0, min(selectedRange.location + cursorOffset, (string as NSString).length))
            setSelectedRange(NSRange(location: newCursorPos, length: 0))
        }
    }

    override func keyDown(with event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Shift+Tab - focus main editor
        if event.keyCode == 48 && flags == .shift {
            NotificationCenter.default.post(name: .focusEditor, object: nil)
            return
        }

        super.keyDown(with: event)
    }
}

#Preview {
    QuickEntryView()
        .frame(width: 450, height: 150)
}
