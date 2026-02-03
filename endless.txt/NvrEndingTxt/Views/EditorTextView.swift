import SwiftUI
import AppKit

// MARK: - Search State

class SearchState: ObservableObject {
    @Published var query: String = ""
    @Published var isVisible: Bool = false
    @Published var currentMatchIndex: Int = 0
    @Published var totalMatches: Int = 0

    // Internal state - doesn't need to trigger view updates
    var matchRanges: [NSRange] = []
    var lastProcessedQuery: String = ""

    func reset() {
        query = ""
        currentMatchIndex = 0
        totalMatches = 0
        matchRanges = []
        lastProcessedQuery = ""
    }
}

// MARK: - EditorTextView

struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var searchState: SearchState
    @ObservedObject private var settings = AppSettings.shared

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        let textView = EditorNSTextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isSelectable = true
        textView.allowsUndo = true
        textView.isRichText = false
        textView.usesFindBar = false // We use our own search
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // Enable undo
        textView.allowsUndo = true

        // Configure text container for word wrap
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.minSize = NSSize(width: 0, height: 0)

        // Store coordinator reference for key handling
        textView.coordinator = context.coordinator

        scrollView.documentView = textView

        // Apply initial theme
        applyTheme(to: textView)

        // Set initial text
        textView.string = text
        applyStrikethroughStyling(to: textView)

        // Store reference to text view in coordinator
        context.coordinator.textView = textView

        // Scroll to bottom initially
        DispatchQueue.main.async {
            textView.scrollToEndOfDocument(nil)
        }

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? EditorNSTextView else { return }

        // Only update text if it actually changed (avoid update loops)
        if textView.string != text {
            let selectedRanges = textView.selectedRanges
            textView.string = text

            // Restore selection if valid
            if let range = selectedRanges.first as? NSRange,
               range.location + range.length <= (text as NSString).length {
                textView.setSelectedRange(range)
            }
        }

        // Apply theme changes
        applyTheme(to: textView)

        // Apply strikethrough styling
        applyStrikethroughStyling(to: textView)

        // Update search highlights if search is active and query changed
        if searchState.isVisible && !searchState.query.isEmpty {
            // Only update if query actually changed to prevent infinite loop
            if searchState.query != searchState.lastProcessedQuery {
                searchState.lastProcessedQuery = searchState.query
                context.coordinator.updateSearchHighlights()
            }
        } else if searchState.lastProcessedQuery != "" {
            searchState.lastProcessedQuery = ""
            context.coordinator.clearSearchHighlights()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    private func applyTheme(to textView: NSTextView) {
        let theme = settings.theme

        // Background
        textView.backgroundColor = NSColor(theme.backgroundColor)
        textView.enclosingScrollView?.backgroundColor = NSColor(theme.backgroundColor)

        // Text color and font
        textView.textColor = NSColor(theme.textColor)
        textView.font = NSFont(name: settings.fontName, size: settings.fontSize) ?? NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)

        // Insertion point (cursor) color
        textView.insertionPointColor = NSColor(theme.accentColor)

        // Selection color
        textView.selectedTextAttributes = [
            .backgroundColor: NSColor(theme.accentColor).withAlphaComponent(0.3),
            .foregroundColor: NSColor(theme.textColor)
        ]
    }

    private func applyStrikethroughStyling(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)

        // Remove existing strikethrough
        textStorage.removeAttribute(.strikethroughStyle, range: fullRange)

        // Find ~~text~~ patterns and apply strikethrough
        let pattern = "~~(.+?)~~"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

        let matches = regex.matches(in: textView.string, options: [], range: fullRange)

        for match in matches {
            // Apply strikethrough to the entire match (including ~~)
            textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)

            // Make the ~~ markers slightly transparent
            let theme = settings.theme
            if match.range.length >= 4 {
                let startMarkerRange = NSRange(location: match.range.location, length: 2)
                let endMarkerRange = NSRange(location: match.range.location + match.range.length - 2, length: 2)
                textStorage.addAttribute(.foregroundColor, value: NSColor(theme.secondaryTextColor).withAlphaComponent(0.5), range: startMarkerRange)
                textStorage.addAttribute(.foregroundColor, value: NSColor(theme.secondaryTextColor).withAlphaComponent(0.5), range: endMarkerRange)
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorTextView
        weak var textView: EditorNSTextView?

        private var isUpdatingText = false

        init(_ parent: EditorTextView) {
            self.parent = parent
            super.init()

            // Subscribe to notifications
            NotificationCenter.default.addObserver(self, selector: #selector(findNext), name: .findNext, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(findPrevious), name: .findPrevious, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(scrollToPreviousDay), name: .scrollToPreviousDay, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(scrollToNextDay), name: .scrollToNextDay, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(toggleStrikethrough), name: .toggleStrikethrough, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(toggleCheckbox), name: .toggleCheckbox, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(scrollToBottom), name: .scrollToBottom, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(focusEditor), name: .focusEditor, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(moveToPreviousLineEnd), name: .moveToPreviousLineEnd, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(moveToNextLineEnd), name: .moveToNextLineEnd, object: nil)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingText, let textView = notification.object as? NSTextView else { return }

            isUpdatingText = true
            parent.text = textView.string

            // Re-apply strikethrough styling after text change
            DispatchQueue.main.async { [weak self] in
                self?.parent.applyStrikethroughStyling(to: textView)
                self?.isUpdatingText = false
            }
        }

        // MARK: - Search

        func updateSearchHighlights() {
            guard let textView = textView,
                  let layoutManager = textView.layoutManager,
                  !parent.searchState.query.isEmpty else {
                return
            }

            let query = parent.searchState.query
            let content = textView.string

            // Clear existing highlights
            let fullRange = NSRange(location: 0, length: (content as NSString).length)
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)

            // Find all matches
            var matchRanges: [NSRange] = []
            var searchRange = content.startIndex..<content.endIndex

            while let range = content.range(of: query, options: .caseInsensitive, range: searchRange) {
                let nsRange = NSRange(range, in: content)
                matchRanges.append(nsRange)
                searchRange = range.upperBound..<content.endIndex
            }

            parent.searchState.matchRanges = matchRanges
            parent.searchState.totalMatches = matchRanges.count

            // Validate current match index
            if parent.searchState.currentMatchIndex >= matchRanges.count {
                parent.searchState.currentMatchIndex = matchRanges.isEmpty ? 0 : matchRanges.count - 1
            }

            // Highlight all matches
            let theme = parent.settings.theme
            let highlightColor = NSColor(theme.accentColor).withAlphaComponent(0.3)
            let currentHighlightColor = NSColor(theme.accentColor).withAlphaComponent(0.6)

            for (index, range) in matchRanges.enumerated() {
                let color = index == parent.searchState.currentMatchIndex ? currentHighlightColor : highlightColor
                layoutManager.addTemporaryAttribute(.backgroundColor, value: color, forCharacterRange: range)
            }

            // Scroll to current match
            if !matchRanges.isEmpty && parent.searchState.currentMatchIndex < matchRanges.count {
                let currentRange = matchRanges[parent.searchState.currentMatchIndex]
                textView.scrollRangeToVisible(currentRange)
                textView.showFindIndicator(for: currentRange)
            }
        }

        func clearSearchHighlights() {
            guard let textView = textView,
                  let layoutManager = textView.layoutManager else { return }

            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
        }

        @objc func findNext() {
            guard parent.searchState.totalMatches > 0 else { return }
            parent.searchState.currentMatchIndex = (parent.searchState.currentMatchIndex + 1) % parent.searchState.totalMatches
            updateSearchHighlights()
        }

        @objc func findPrevious() {
            guard parent.searchState.totalMatches > 0 else { return }
            parent.searchState.currentMatchIndex = (parent.searchState.currentMatchIndex - 1 + parent.searchState.totalMatches) % parent.searchState.totalMatches
            updateSearchHighlights()
        }

        // MARK: - Day Navigation

        @objc func scrollToPreviousDay() {
            guard let textView = textView else { return }

            let content = textView.string
            let pattern = "\\[\\d{4}-\\d{2}-\\d{2}"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

            let fullRange = NSRange(location: 0, length: (content as NSString).length)
            let matches = regex.matches(in: content, options: [], range: fullRange)

            guard !matches.isEmpty else { return }

            // Find current cursor position
            let cursorPosition = textView.selectedRange().location

            // Find the previous day entry (before cursor)
            var targetMatch: NSTextCheckingResult?
            for match in matches.reversed() {
                if match.range.location < cursorPosition {
                    targetMatch = match
                    break
                }
            }

            // Wrap to last entry if at beginning
            if targetMatch == nil {
                targetMatch = matches.last
            }

            if let match = targetMatch {
                scrollToAndHighlight(range: match.range)
            }
        }

        @objc func scrollToNextDay() {
            guard let textView = textView else { return }

            let content = textView.string
            let pattern = "\\[\\d{4}-\\d{2}-\\d{2}"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

            let fullRange = NSRange(location: 0, length: (content as NSString).length)
            let matches = regex.matches(in: content, options: [], range: fullRange)

            guard !matches.isEmpty else { return }

            // Find current cursor position
            let cursorPosition = textView.selectedRange().location

            // Find the next day entry (after cursor)
            var targetMatch: NSTextCheckingResult?
            for match in matches {
                if match.range.location > cursorPosition {
                    targetMatch = match
                    break
                }
            }

            // Wrap to first entry if at end
            if targetMatch == nil {
                targetMatch = matches.first
            }

            if let match = targetMatch {
                scrollToAndHighlight(range: match.range)
            }
        }

        private func scrollToAndHighlight(range: NSRange) {
            guard let textView = textView,
                  let layoutManager = textView.layoutManager else { return }

            // Move cursor to the match
            textView.setSelectedRange(NSRange(location: range.location, length: 0))
            textView.scrollRangeToVisible(range)

            // Brief highlight
            let theme = parent.settings.theme
            let highlightColor = NSColor(theme.accentColor).withAlphaComponent(0.4)

            // Find end of line for highlight
            let content = textView.string as NSString
            let lineRange = content.lineRange(for: range)

            layoutManager.addTemporaryAttribute(.backgroundColor, value: highlightColor, forCharacterRange: lineRange)

            // Remove highlight after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak layoutManager] in
                layoutManager?.removeTemporaryAttribute(.backgroundColor, forCharacterRange: lineRange)
            }
        }

        @objc func scrollToBottom() {
            textView?.scrollToEndOfDocument(nil)
        }

        @objc func focusEditor() {
            textView?.window?.makeFirstResponder(textView)
        }

        // MARK: - Line Navigation

        @objc func moveToPreviousLineEnd() {
            guard let textView = textView else { return }

            let content = textView.string as NSString
            let currentPos = textView.selectedRange().location

            // Find previous newline
            var searchPos = currentPos - 1
            if searchPos < 0 { searchPos = 0 }

            // Skip current newline if we're at one
            while searchPos > 0 && content.character(at: searchPos) == 10 {
                searchPos -= 1
            }

            // Find the previous newline
            while searchPos > 0 && content.character(at: searchPos - 1) != 10 {
                searchPos -= 1
            }

            // Now find end of that line (before the newline)
            if searchPos > 0 {
                searchPos -= 1
                // Skip any trailing newlines
                while searchPos > 0 && content.character(at: searchPos) == 10 {
                    searchPos -= 1
                }
                // Position after the last character (at end of line)
                searchPos += 1
            }

            textView.setSelectedRange(NSRange(location: searchPos, length: 0))
            textView.scrollRangeToVisible(NSRange(location: searchPos, length: 0))
        }

        @objc func moveToNextLineEnd() {
            guard let textView = textView else { return }

            let content = textView.string as NSString
            let length = content.length
            let currentPos = textView.selectedRange().location

            // Find next newline from current position
            var searchPos = currentPos

            // Move to end of current line first
            while searchPos < length && content.character(at: searchPos) != 10 {
                searchPos += 1
            }

            // Skip the newline
            if searchPos < length {
                searchPos += 1
            }

            // Move to end of next line
            while searchPos < length && content.character(at: searchPos) != 10 {
                searchPos += 1
            }

            textView.setSelectedRange(NSRange(location: searchPos, length: 0))
            textView.scrollRangeToVisible(NSRange(location: searchPos, length: 0))
        }

        // MARK: - Strikethrough

        @objc func toggleStrikethrough() {
            guard let textView = textView else { return }

            let selectedRange = textView.selectedRange()
            guard selectedRange.length > 0 else { return }

            let content = textView.string as NSString
            let selectedText = content.substring(with: selectedRange)

            var newText: String
            var newSelectedRange: NSRange

            // Check if already has strikethrough markers
            if selectedText.hasPrefix("~~") && selectedText.hasSuffix("~~") && selectedText.count >= 4 {
                // Remove markers
                let startIndex = selectedText.index(selectedText.startIndex, offsetBy: 2)
                let endIndex = selectedText.index(selectedText.endIndex, offsetBy: -2)
                newText = String(selectedText[startIndex..<endIndex])
                newSelectedRange = NSRange(location: selectedRange.location, length: newText.count)
            } else {
                // Add markers
                newText = "~~\(selectedText)~~"
                newSelectedRange = NSRange(location: selectedRange.location, length: newText.count)
            }

            // Replace text
            if textView.shouldChangeText(in: selectedRange, replacementString: newText) {
                textView.replaceCharacters(in: selectedRange, with: newText)
                textView.didChangeText()
                textView.setSelectedRange(newSelectedRange)
            }
        }

        // MARK: - Checkbox

        @objc func toggleCheckbox() {
            guard let textView = textView else { return }

            let selectedRange = textView.selectedRange()
            let content = textView.string as NSString

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
                let trimmed = lineText.trimmingCharacters(in: .whitespaces)
                let leadingSpaces = lineText.prefix(while: { $0.isWhitespace })
                newLineText = String(leadingSpaces) + "[ ] " + trimmed
                if newLineText.hasSuffix("\n") == false && lineText.hasSuffix("\n") {
                    // Preserve newline if original had it
                } else if !lineText.hasSuffix("\n") && !newLineText.hasSuffix("\n") {
                    // OK
                }
                // Recalculate - preserve original line ending
                let hasNewline = lineText.hasSuffix("\n")
                let baseTrimmed = lineText.trimmingCharacters(in: .whitespacesAndNewlines)
                newLineText = String(leadingSpaces) + "[ ] " + baseTrimmed + (hasNewline ? "\n" : "")
                cursorOffset = 4
            }

            // Replace line
            if textView.shouldChangeText(in: lineRange, replacementString: newLineText) {
                textView.replaceCharacters(in: lineRange, with: newLineText)
                textView.didChangeText()

                // Adjust cursor position
                let newCursorPos = max(0, min(selectedRange.location + cursorOffset, textView.string.count))
                textView.setSelectedRange(NSRange(location: newCursorPos, length: 0))
            }
        }
    }
}

// MARK: - Custom NSTextView subclass for key handling

class EditorNSTextView: NSTextView {
    weak var coordinator: EditorTextView.Coordinator?
    var onEscapePressed: (() -> Void)?

    // Note: Most keyboard shortcuts are now handled by KeyboardShortcuts library
    // Only special cases (Esc, Tab) are handled here

    override func keyDown(with event: NSEvent) {
        // Escape key
        if event.keyCode == 53 {
            NotificationCenter.default.post(name: .dismissSearch, object: nil)
            onEscapePressed?()
            return
        }

        super.keyDown(with: event)
    }

    // Tab key is handled here, not in keyDown
    override func insertTab(_ sender: Any?) {
        let cursorPos = selectedRange().location
        let length = (string as NSString).length

        // If cursor is at end or document is empty, go to quick entry
        if length == 0 || cursorPos >= length {
            NotificationCenter.default.post(name: .focusQuickEntry, object: nil)
            return
        }

        // Otherwise insert tab as normal
        super.insertTab(sender)
    }
}
