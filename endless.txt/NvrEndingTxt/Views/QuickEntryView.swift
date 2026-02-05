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
        private var focusObserver: NSObjectProtocol?

        init(_ parent: QuickEntryTextEditor) {
            self.parent = parent
            super.init()

            // Listen for focus requests
            focusObserver = NotificationCenter.default.addObserver(
                forName: .focusQuickEntry,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                self?.focusTextView()
            }
        }

        deinit {
            if let observer = focusObserver {
                NotificationCenter.default.removeObserver(observer)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            isUpdating = true
            parent.text = textView.string
            isUpdating = false
        }

        func focusTextView() {
            DispatchQueue.main.async { [weak self] in
                self?.textView?.window?.makeFirstResponder(self?.textView)
            }
        }
    }
}

// MARK: - Custom NSTextView with Shift+Tab handling

class QuickEntryNSTextView: NSTextView {
    private var checkboxObserver: NSObjectProtocol?
    private var strikethroughObserver: NSObjectProtocol?
    private var lastCheckboxToggle: Date = .distantPast

    // Autocomplete state
    private var autocompleteWindow: NSWindow?
    private var autocompleteStackView: NSStackView?
    private var autocompletePrefix: String = ""
    private var autocompleteStartLocation: Int = 0

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

        // Listen for strikethrough toggle when this view has focus
        strikethroughObserver = NotificationCenter.default.addObserver(
            forName: .toggleStrikethrough,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self, self.window?.firstResponder === self else { return }
            self.toggleStrikethrough()
        }
    }

    deinit {
        if let observer = checkboxObserver {
            NotificationCenter.default.removeObserver(observer)
        }
        if let observer = strikethroughObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // Note: Most keyboard shortcuts are now handled by KeyboardShortcuts library
    // Only special cases (Shift+Tab, checkbox toggle) are handled here

    private func toggleCheckbox() {
        // Debounce to prevent double-firing
        let now = Date()
        guard now.timeIntervalSince(lastCheckboxToggle) > 0.1 else { return }
        lastCheckboxToggle = now

        let selectedRange = selectedRange()
        let content = string as NSString

        // Get line range
        let lineRange = content.lineRange(for: selectedRange)
        let lineText = content.substring(with: lineRange)

        var newLineText: String
        var cursorOffset = 0

        if lineText.contains("[x]") || lineText.contains("[X]") {
            // Toggle to unchecked
            newLineText = lineText.replacingOccurrences(of: "[x]", with: "[ ]")
                .replacingOccurrences(of: "[X]", with: "[ ]")
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

    private func toggleStrikethrough() {
        let selectedRange = selectedRange()
        let content = string as NSString

        // Get line range
        let lineRange = content.lineRange(for: selectedRange)
        let lineText = content.substring(with: lineRange)

        var newLineText: String
        var cursorOffset = 0

        // Check if line content (excluding leading whitespace) is wrapped in ~~
        let leadingSpaces = lineText.prefix(while: { $0.isWhitespace && $0 != "\n" })
        let hasNewline = lineText.hasSuffix("\n")
        let trimmedContent = lineText.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmedContent.hasPrefix("~~") && trimmedContent.hasSuffix("~~") && trimmedContent.count >= 4 {
            // Remove strikethrough markers
            let startIndex = trimmedContent.index(trimmedContent.startIndex, offsetBy: 2)
            let endIndex = trimmedContent.index(trimmedContent.endIndex, offsetBy: -2)
            let unwrapped = String(trimmedContent[startIndex..<endIndex])
            newLineText = String(leadingSpaces) + unwrapped + (hasNewline ? "\n" : "")
            cursorOffset = -2
        } else {
            // Add strikethrough markers
            newLineText = String(leadingSpaces) + "~~" + trimmedContent + "~~" + (hasNewline ? "\n" : "")
            cursorOffset = 2
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

        // Escape key - dismiss autocomplete
        if event.keyCode == 53 {
            dismissAutocomplete()
            return
        }

        // Shift+Tab - focus main editor
        if event.keyCode == 48 && flags == .shift {
            NotificationCenter.default.post(name: .focusEditor, object: nil)
            return
        }

        // Track text length before processing
        let previousLength = string.count

        super.keyDown(with: event)

        // Only check autocomplete if text actually changed
        let currentLength = string.count
        if currentLength != previousLength {
            DispatchQueue.main.async { [weak self] in
                self?.checkForHashtagAutocomplete()
            }
        } else {
            dismissAutocomplete()
        }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()

        // Dismiss autocomplete when window loses focus
        if let window = window {
            NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.dismissAutocomplete()
            }
        }
    }

    // MARK: - Hashtag Autocomplete

    private func checkForHashtagAutocomplete() {
        let cursorPos = selectedRange().location
        guard cursorPos > 0 else {
            dismissAutocomplete()
            return
        }

        let content = string as NSString

        // Check if cursor is at the END of a word
        if cursorPos < content.length {
            let nextChar = content.substring(with: NSRange(location: cursorPos, length: 1))
            if let char = nextChar.first, char.isLetter || char.isNumber || char == "_" {
                dismissAutocomplete()
                return
            }
        }

        // Find the start of the current word (looking back for #)
        var startPos = cursorPos - 1
        while startPos >= 0 {
            let char = content.substring(with: NSRange(location: startPos, length: 1))
            if char == "#" {
                let prefix = content.substring(with: NSRange(location: startPos, length: cursorPos - startPos))
                let wordPart = String(prefix.dropFirst())
                let isValidHashtagPrefix = wordPart.isEmpty || wordPart.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }

                if isValidHashtagPrefix {
                    showAutocomplete(for: prefix, at: startPos)
                } else {
                    dismissAutocomplete()
                }
                return
            } else if !char.first!.isLetter && !char.first!.isNumber && char != "_" {
                dismissAutocomplete()
                return
            }
            startPos -= 1
        }

        dismissAutocomplete()
    }

    private func showAutocomplete(for prefix: String, at location: Int) {
        let hashtagState = HashtagState.shared

        autocompletePrefix = prefix
        autocompleteStartLocation = location

        let matchingTags = hashtagState.matchingTags(for: prefix)
            .filter { $0.lowercased() != prefix.lowercased() }
            .prefix(5)

        let suggestions = matchingTags.map { tag in
            (tag: tag, count: hashtagState.usageCount(for: tag))
        }

        if suggestions.isEmpty {
            dismissAutocomplete()
            return
        }

        if autocompleteWindow == nil {
            createAutocompleteWindow()
        }

        // Populate stack view
        guard let stackView = autocompleteStackView else { return }
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }

        for suggestion in suggestions {
            let rowView = NSView()
            rowView.translatesAutoresizingMaskIntoConstraints = false

            let tagLabel = NSTextField(labelWithString: suggestion.tag)
            tagLabel.font = NSFont.systemFont(ofSize: 13, weight: .regular)
            tagLabel.textColor = NSColor.labelColor
            tagLabel.translatesAutoresizingMaskIntoConstraints = false

            let countLabel = NSTextField(labelWithString: "\(suggestion.count)")
            countLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
            countLabel.textColor = NSColor.tertiaryLabelColor
            countLabel.translatesAutoresizingMaskIntoConstraints = false

            rowView.addSubview(tagLabel)
            rowView.addSubview(countLabel)

            NSLayoutConstraint.activate([
                rowView.heightAnchor.constraint(equalToConstant: 24),
                tagLabel.leadingAnchor.constraint(equalTo: rowView.leadingAnchor),
                tagLabel.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
                countLabel.trailingAnchor.constraint(equalTo: rowView.trailingAnchor),
                countLabel.centerYAnchor.constraint(equalTo: rowView.centerYAnchor),
            ])

            stackView.addArrangedSubview(rowView)
            rowView.widthAnchor.constraint(equalTo: stackView.widthAnchor).isActive = true
        }

        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: location, length: 1), actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let lineBottom = rect.origin.y + rect.height + textContainerInset.height
        let xPosition = rect.origin.x + textContainerInset.width

        let bottomPoint = convert(NSPoint(x: xPosition, y: lineBottom), to: nil)
        guard let screenPoint = window?.convertPoint(toScreen: bottomPoint) else { return }

        let rowHeight: CGFloat = 24
        let verticalPadding: CGFloat = 12
        let windowHeight = CGFloat(suggestions.count) * rowHeight + verticalPadding
        let windowWidth: CGFloat = 150

        autocompleteWindow?.setFrame(
            NSRect(x: screenPoint.x - 6, y: screenPoint.y - windowHeight - 4, width: windowWidth, height: windowHeight),
            display: true
        )

        autocompleteWindow?.alphaValue = 0
        autocompleteWindow?.orderFront(nil)
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.12
            autocompleteWindow?.animator().alphaValue = 1
        }
    }

    private func createAutocompleteWindow() {
        let window = NonActivatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: 160, height: 100),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.hidesOnDeactivate = false

        // Use solid background to avoid white corner artifacts
        let containerView = NSView()
        containerView.wantsLayer = true
        containerView.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor
        containerView.layer?.cornerRadius = 6
        containerView.layer?.masksToBounds = true
        containerView.layer?.shadowColor = NSColor.black.cgColor
        containerView.layer?.shadowOpacity = 0.15
        containerView.layer?.shadowOffset = CGSize(width: 0, height: -2)
        containerView.layer?.shadowRadius = 8

        let stackView = NSStackView()
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false

        containerView.addSubview(stackView)
        window.contentView = containerView

        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: containerView.topAnchor, constant: 6),
            stackView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor, constant: 10),
            stackView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor, constant: -10),
            stackView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor, constant: -6),
        ])

        autocompleteWindow = window
        autocompleteStackView = stackView
    }

    private func dismissAutocomplete() {
        autocompleteWindow?.orderOut(nil)
    }
}

// MARK: - Non-Activating Panel for Autocomplete

/// A panel that never becomes key window, preventing focus stealing from text views
class NonActivatingPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

#Preview {
    QuickEntryView()
        .frame(width: 450, height: 150)
}
