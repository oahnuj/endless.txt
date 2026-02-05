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

// MARK: - Hashtag State

class HashtagState: ObservableObject {
    static let shared = HashtagState()

    @Published var usedHashtags: Set<String> = []
    @Published var hashtagCounts: [String: Int] = [:]
    @Published var recentlyUsed: [String] = [] // Most recent first
    @Published var filteredTag: String? = nil

    private let maxRecentTags = 20

    private init() {}

    func scanHashtags(in text: String) {
        guard let regex = try? NSRegularExpression(pattern: "#[\\w]+", options: []) else { return }
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        let matches = regex.matches(in: text, options: [], range: fullRange)

        var tags = Set<String>()
        var counts: [String: Int] = [:]

        for match in matches {
            let tag = (text as NSString).substring(with: match.range)
            tags.insert(tag)
            counts[tag, default: 0] += 1
        }

        usedHashtags = tags
        hashtagCounts = counts
    }

    func markAsRecentlyUsed(_ tag: String) {
        // Remove if already in list, then add to front
        recentlyUsed.removeAll { $0.lowercased() == tag.lowercased() }
        recentlyUsed.insert(tag, at: 0)

        // Keep list bounded
        if recentlyUsed.count > maxRecentTags {
            recentlyUsed = Array(recentlyUsed.prefix(maxRecentTags))
        }
    }

    func usageCount(for tag: String) -> Int {
        return hashtagCounts[tag] ?? 0
    }

    func matchingTags(for prefix: String) -> [String] {
        let candidates: [String]
        if prefix.count <= 1 {
            candidates = Array(usedHashtags)
        } else {
            let lowercasedPrefix = prefix.lowercased()
            candidates = usedHashtags.filter { $0.lowercased().hasPrefix(lowercasedPrefix) }
        }

        // Sort: recently used first, then by frequency, then alphabetically
        return candidates.sorted { tag1, tag2 in
            let recent1 = recentlyUsed.firstIndex(of: tag1) ?? Int.max
            let recent2 = recentlyUsed.firstIndex(of: tag2) ?? Int.max

            if recent1 != recent2 {
                return recent1 < recent2
            }

            let count1 = hashtagCounts[tag1] ?? 0
            let count2 = hashtagCounts[tag2] ?? 0

            if count1 != count2 {
                return count1 > count2
            }

            return tag1.lowercased() < tag2.lowercased()
        }
    }
}

// MARK: - EditorTextView

struct EditorTextView: NSViewRepresentable {
    @Binding var text: String
    @ObservedObject var searchState: SearchState
    @ObservedObject var hashtagState: HashtagState
    @ObservedObject private var settings = AppSettings.shared

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay // Scrollbar only shows when scrolling
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
        applyTimestampStyling(to: textView)
        applyMarkdownStyling(to: textView)

        // Scan for hashtags on initial load
        hashtagState.scanHashtags(in: text)

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

        // Apply text styling (timestamp first as it resets fonts, then markdown)
        applyTimestampStyling(to: textView)
        applyMarkdownStyling(to: textView)

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

    private func applyMarkdownStyling(to textView: NSTextView) {
        guard settings.enableMarkdown else { return }
        guard let textStorage = textView.textStorage else { return }

        let fullRange = NSRange(location: 0, length: textStorage.length)
        let theme = settings.theme

        // Create bold font using system bold monospace
        let boldFont = NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .bold)

        // Create italic font using oblique transform (monospace fonts rarely have true italic)
        let baseFont = NSFont(name: settings.fontName, size: settings.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)
        let italicTransform = AffineTransform(m11: 1, m12: 0, m21: 0.2, m22: 1, tX: 0, tY: 0)
        let italicDescriptor = baseFont.fontDescriptor
        let italicFont = NSFont(descriptor: italicDescriptor, textTransform: italicTransform)
            ?? baseFont

        // Remove existing markdown attributes first
        textStorage.removeAttribute(.strikethroughStyle, range: fullRange)
        textStorage.removeAttribute(.underlineStyle, range: fullRange)
        textStorage.removeAttribute(.obliqueness, range: fullRange)

        // **bold** - must check before *italic* since ** contains *
        if let boldRegex = try? NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: []) {
            let matches = boldRegex.matches(in: textView.string, options: [], range: fullRange)
            for match in matches {
                // Apply bold to content (excluding markers)
                if match.numberOfRanges > 1 {
                    let contentRange = match.range(at: 1)
                    textStorage.addAttribute(.font, value: boldFont, range: contentRange)
                }
                // Make markers dim
                if match.range.length >= 4 {
                    let startMarker = NSRange(location: match.range.location, length: 2)
                    let endMarker = NSRange(location: match.range.location + match.range.length - 2, length: 2)
                    textStorage.addAttribute(.foregroundColor, value: NSColor(theme.secondaryTextColor).withAlphaComponent(0.3), range: startMarker)
                    textStorage.addAttribute(.foregroundColor, value: NSColor(theme.secondaryTextColor).withAlphaComponent(0.3), range: endMarker)
                }
            }
        }

        // *italic* (single asterisk, but not inside **)
        if let italicRegex = try? NSRegularExpression(pattern: "(?<!\\*)\\*(?!\\*)(.+?)(?<!\\*)\\*(?!\\*)", options: []) {
            let matches = italicRegex.matches(in: textView.string, options: [], range: fullRange)
            for match in matches {
                if match.numberOfRanges > 1 {
                    let contentRange = match.range(at: 1)
                    // Use obliqueness attribute for italic effect
                    textStorage.addAttribute(.obliqueness, value: 0.2, range: contentRange)
                }
                // Make markers dim
                if match.range.length >= 2 {
                    let startMarker = NSRange(location: match.range.location, length: 1)
                    let endMarker = NSRange(location: match.range.location + match.range.length - 1, length: 1)
                    textStorage.addAttribute(.foregroundColor, value: NSColor(theme.secondaryTextColor).withAlphaComponent(0.3), range: startMarker)
                    textStorage.addAttribute(.foregroundColor, value: NSColor(theme.secondaryTextColor).withAlphaComponent(0.3), range: endMarker)
                }
            }
        }

        // ~~strikethrough~~
        if let strikeRegex = try? NSRegularExpression(pattern: "~~(.+?)~~", options: []) {
            let matches = strikeRegex.matches(in: textView.string, options: [], range: fullRange)
            let tinyFont = NSFont.systemFont(ofSize: 0.1)
            for match in matches {
                // Apply strikethrough only to content (excluding markers)
                if match.numberOfRanges > 1 {
                    let contentRange = match.range(at: 1)
                    textStorage.addAttribute(.strikethroughStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                }
                // Hide markers completely (tiny + invisible) for clean visual
                if match.range.length >= 4 {
                    let startMarker = NSRange(location: match.range.location, length: 2)
                    let endMarker = NSRange(location: match.range.location + match.range.length - 2, length: 2)
                    textStorage.addAttribute(.font, value: tinyFont, range: startMarker)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.clear, range: startMarker)
                    textStorage.addAttribute(.font, value: tinyFont, range: endMarker)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.clear, range: endMarker)
                }
            }
        }

        // __underline__
        if let underlineRegex = try? NSRegularExpression(pattern: "__(.+?)__", options: []) {
            let matches = underlineRegex.matches(in: textView.string, options: [], range: fullRange)
            for match in matches {
                if match.numberOfRanges > 1 {
                    let contentRange = match.range(at: 1)
                    textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: contentRange)
                }
                if match.range.length >= 4 {
                    let startMarker = NSRange(location: match.range.location, length: 2)
                    let endMarker = NSRange(location: match.range.location + match.range.length - 2, length: 2)
                    textStorage.addAttribute(.foregroundColor, value: NSColor(theme.secondaryTextColor).withAlphaComponent(0.3), range: startMarker)
                    textStorage.addAttribute(.foregroundColor, value: NSColor(theme.secondaryTextColor).withAlphaComponent(0.3), range: endMarker)
                }
            }
        }

        // URLs - detect http:// and https:// links
        if let urlRegex = try? NSRegularExpression(pattern: "https?://[^\\s]+", options: []) {
            let matches = urlRegex.matches(in: textView.string, options: [], range: fullRange)
            for match in matches {
                textStorage.addAttribute(.foregroundColor, value: NSColor(theme.accentColor), range: match.range)
                textStorage.addAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, range: match.range)
                // Make it a clickable link
                let urlString = (textView.string as NSString).substring(with: match.range)
                if let url = URL(string: urlString) {
                    textStorage.addAttribute(.link, value: url, range: match.range)
                }
            }
        }

        // #hashtags - color with accent color
        if let tagRegex = try? NSRegularExpression(pattern: "#[\\w]+", options: []) {
            let matches = tagRegex.matches(in: textView.string, options: [], range: fullRange)
            for match in matches {
                textStorage.addAttribute(.foregroundColor, value: NSColor(theme.accentColor), range: match.range)
            }
        }
    }

    private func applyTimestampStyling(to textView: NSTextView) {
        guard let textStorage = textView.textStorage else { return }

        let content = textView.string as NSString
        let fullRange = NSRange(location: 0, length: textStorage.length)
        let theme = settings.theme
        let normalFont = NSFont(name: settings.fontName, size: settings.fontSize)
            ?? NSFont.monospacedSystemFont(ofSize: settings.fontSize, weight: .regular)
        let smallFont = NSFont(name: settings.fontName, size: settings.fontSize - 2)
            ?? NSFont.monospacedSystemFont(ofSize: settings.fontSize - 2, weight: .regular)
        let tinyFont = NSFont.systemFont(ofSize: 0.1)

        // Reset font for full range first
        textStorage.addAttribute(.font, value: normalFont, range: fullRange)

        // Pattern for timestamp-only lines: line that contains only [timestamp] with optional whitespace
        let timestampOnlyLinePattern = "^[ \\t]*\\[\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}(:\\d{2})?\\][ \\t]*\\n?"
        // Pattern for inline timestamps
        let inlineTimestampPattern = "\\[\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}(:\\d{2})?\\]"

        // First, handle timestamp-only lines
        if let lineRegex = try? NSRegularExpression(pattern: timestampOnlyLinePattern, options: .anchorsMatchLines) {
            let lineMatches = lineRegex.matches(in: textView.string, options: [], range: fullRange)

            for match in lineMatches {
                if settings.displayTimestamps {
                    // Show with smaller font and subtle color
                    textStorage.addAttribute(.font, value: smallFont, range: match.range)
                    textStorage.addAttribute(.foregroundColor, value: NSColor(theme.timestampColor), range: match.range)
                } else {
                    // Hide entire line by making it tiny and invisible
                    textStorage.addAttribute(.font, value: tinyFont, range: match.range)
                    textStorage.addAttribute(.foregroundColor, value: NSColor.clear, range: match.range)
                }
            }
        }

        // Then handle any inline timestamps (timestamp followed by text on same line)
        if let inlineRegex = try? NSRegularExpression(pattern: inlineTimestampPattern, options: []) {
            let inlineMatches = inlineRegex.matches(in: textView.string, options: [], range: fullRange)

            for match in inlineMatches {
                // Check if this timestamp is NOT at the start of a line (inline)
                let lineRange = content.lineRange(for: match.range)
                let lineText = content.substring(with: lineRange).trimmingCharacters(in: .whitespacesAndNewlines)

                // If line has more content than just the timestamp, it's inline
                if lineText.count > match.range.length + 2 { // +2 for potential spaces
                    if settings.displayTimestamps {
                        textStorage.addAttribute(.foregroundColor, value: NSColor(theme.timestampColor), range: match.range)
                    } else {
                        textStorage.addAttribute(.foregroundColor, value: NSColor.clear, range: match.range)
                    }
                }
            }
        }
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: EditorTextView
        weak var textView: EditorNSTextView?

        private var isUpdatingText = false
        private var lastCheckboxToggle: Date = .distantPast

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

            // Hashtag features
            NotificationCenter.default.addObserver(self, selector: #selector(handleHashtagClicked(_:)), name: .hashtagClicked, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(clearHashtagFilter), name: .clearHashtagFilter, object: nil)
            NotificationCenter.default.addObserver(self, selector: #selector(tagJump), name: .tagJump, object: nil)
        }

        deinit {
            NotificationCenter.default.removeObserver(self)
        }

        // MARK: - NSTextViewDelegate

        func textDidChange(_ notification: Notification) {
            guard !isUpdatingText, let textView = notification.object as? NSTextView else { return }

            isUpdatingText = true
            parent.text = textView.string

            // Keep cursor visible (auto-scroll when typing at end)
            textView.scrollRangeToVisible(textView.selectedRange())

            // Re-apply markdown styling and scan hashtags after text change
            DispatchQueue.main.async { [weak self] in
                self?.parent.applyMarkdownStyling(to: textView)
                self?.parent.hashtagState.scanHashtags(in: textView.string)
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

        // MARK: - Hashtag Features

        @objc func handleHashtagClicked(_ notification: Notification) {
            guard let clickedTag = notification.object as? String,
                  let textView = textView,
                  let layoutManager = textView.layoutManager else { return }

            let hashtagState = parent.hashtagState

            // If clicking the same tag again, clear the filter
            if hashtagState.filteredTag == clickedTag {
                clearHashtagFilter()
                return
            }

            // Set the filtered tag
            hashtagState.filteredTag = clickedTag

            // Highlight all occurrences of this tag
            let content = textView.string
            let fullRange = NSRange(location: 0, length: (content as NSString).length)

            // Clear existing hashtag highlights
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)

            // Find and highlight all matches
            guard let regex = try? NSRegularExpression(pattern: NSRegularExpression.escapedPattern(for: clickedTag) + "(?![\\w])", options: []) else { return }
            let matches = regex.matches(in: content, options: [], range: fullRange)

            let theme = parent.settings.theme
            let highlightColor = NSColor(theme.accentColor).withAlphaComponent(0.3)

            for match in matches {
                layoutManager.addTemporaryAttribute(.backgroundColor, value: highlightColor, forCharacterRange: match.range)
            }

            // Scroll to first match if cursor is not on a match
            if let firstMatch = matches.first {
                textView.scrollRangeToVisible(firstMatch.range)
                textView.showFindIndicator(for: firstMatch.range)
            }
        }

        @objc func clearHashtagFilter() {
            guard let textView = textView,
                  let layoutManager = textView.layoutManager else { return }

            parent.hashtagState.filteredTag = nil

            // Clear all hashtag highlights
            let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
            layoutManager.removeTemporaryAttribute(.backgroundColor, forCharacterRange: fullRange)
        }

        @objc func tagJump() {
            guard let textView = textView,
                  textView.window?.firstResponder === textView else { return }

            let cursorPos = textView.selectedRange().location
            let content = textView.string as NSString

            // Find hashtag at or near cursor
            guard let regex = try? NSRegularExpression(pattern: "#[\\w]+", options: []) else { return }
            let fullRange = NSRange(location: 0, length: content.length)
            let allMatches = regex.matches(in: textView.string, options: [], range: fullRange)

            guard !allMatches.isEmpty else { return }

            // Find the hashtag at cursor position
            var currentTag: String?
            var currentTagIndex: Int?

            for (index, match) in allMatches.enumerated() {
                // Check if cursor is inside or immediately after this tag
                if cursorPos >= match.range.location && cursorPos <= match.range.location + match.range.length {
                    currentTag = content.substring(with: match.range)
                    currentTagIndex = index
                    break
                }
            }

            // If no tag at cursor, find the nearest one before cursor
            if currentTag == nil {
                for (index, match) in allMatches.enumerated().reversed() {
                    if match.range.location < cursorPos {
                        currentTag = content.substring(with: match.range)
                        currentTagIndex = index
                        break
                    }
                }
            }

            guard let tag = currentTag else { return }

            // Find all matches of this specific tag
            let escapedTag = NSRegularExpression.escapedPattern(for: tag)
            guard let tagRegex = try? NSRegularExpression(pattern: escapedTag + "(?![\\w])", options: []) else { return }
            let tagMatches = tagRegex.matches(in: textView.string, options: [], range: fullRange)

            guard tagMatches.count > 1 else { return } // Need at least 2 matches to jump

            // Find current position in tag matches
            var currentMatchIndex = 0
            for (index, match) in tagMatches.enumerated() {
                if cursorPos >= match.range.location && cursorPos <= match.range.location + match.range.length {
                    currentMatchIndex = index
                    break
                } else if match.range.location > cursorPos {
                    // Cursor is before this match, use the previous one
                    currentMatchIndex = max(0, index - 1)
                    break
                }
                currentMatchIndex = index
            }

            // Jump to next match (with wrap-around)
            let nextIndex = (currentMatchIndex + 1) % tagMatches.count
            let nextMatch = tagMatches[nextIndex]

            // Move cursor and scroll
            textView.setSelectedRange(NSRange(location: nextMatch.range.location, length: 0))
            textView.scrollRangeToVisible(nextMatch.range)
            textView.showFindIndicator(for: nextMatch.range)
        }

        // MARK: - Entry Navigation

        /// Find the end position of a note (just before the next timestamp or end of document)
        private func findNoteEndPosition(for timestampMatch: NSTextCheckingResult, allMatches: [NSTextCheckingResult], in content: NSString) -> Int {
            // Find the index of the current match
            guard let currentIndex = allMatches.firstIndex(where: { $0.range.location == timestampMatch.range.location }) else {
                return content.length
            }

            // If there's a next timestamp, the note ends just before it (minus newlines)
            if currentIndex + 1 < allMatches.count {
                let nextMatch = allMatches[currentIndex + 1]
                var endPos = nextMatch.range.location

                // Go back past any newlines/whitespace before the next timestamp
                while endPos > timestampMatch.range.location && endPos > 0 {
                    let prevChar = content.substring(with: NSRange(location: endPos - 1, length: 1))
                    if prevChar == "\n" || prevChar == " " || prevChar == "\t" || prevChar == "-" {
                        endPos -= 1
                    } else {
                        break
                    }
                }

                return endPos
            }

            // This is the last note, find end of actual content
            var endPos = content.length

            // Go back past any trailing newlines/whitespace
            while endPos > timestampMatch.range.location && endPos > 0 {
                let prevChar = content.substring(with: NSRange(location: endPos - 1, length: 1))
                if prevChar == "\n" || prevChar == " " || prevChar == "\t" {
                    endPos -= 1
                } else {
                    break
                }
            }

            return endPos
        }

        @objc func scrollToPreviousDay() {
            guard let textView = textView else { return }

            let content = textView.string as NSString
            let pattern = "\\[\\d{4}-\\d{2}-\\d{2}"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

            let fullRange = NSRange(location: 0, length: content.length)
            let matches = regex.matches(in: textView.string, options: [], range: fullRange)

            guard !matches.isEmpty else { return }

            // Find current cursor position
            let cursorPosition = textView.selectedRange().location

            // Find the previous entry (before cursor)
            var targetMatch: NSTextCheckingResult?
            for match in matches.reversed() {
                let noteEnd = findNoteEndPosition(for: match, allMatches: matches, in: content)
                if noteEnd < cursorPosition {
                    targetMatch = match
                    break
                }
            }

            // Wrap to last entry if at beginning
            if targetMatch == nil {
                targetMatch = matches.last
            }

            if let match = targetMatch {
                let noteEnd = findNoteEndPosition(for: match, allMatches: matches, in: content)
                let targetRange = NSRange(location: noteEnd, length: 0)
                textView.setSelectedRange(targetRange)
                textView.scrollRangeToVisible(targetRange)
            }
        }

        @objc func scrollToNextDay() {
            guard let textView = textView else { return }

            let content = textView.string as NSString
            let pattern = "\\[\\d{4}-\\d{2}-\\d{2}"
            guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return }

            let fullRange = NSRange(location: 0, length: content.length)
            let matches = regex.matches(in: textView.string, options: [], range: fullRange)

            guard !matches.isEmpty else { return }

            // Find current cursor position
            let cursorPosition = textView.selectedRange().location

            // Find the next entry (after cursor)
            var targetMatch: NSTextCheckingResult?
            for match in matches {
                let noteEnd = findNoteEndPosition(for: match, allMatches: matches, in: content)
                if noteEnd > cursorPosition {
                    targetMatch = match
                    break
                }
            }

            // Wrap to first entry if at end
            if targetMatch == nil {
                targetMatch = matches.first
            }

            if let match = targetMatch {
                let noteEnd = findNoteEndPosition(for: match, allMatches: matches, in: content)
                let targetRange = NSRange(location: noteEnd, length: 0)
                textView.setSelectedRange(targetRange)
                textView.scrollRangeToVisible(targetRange)
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
            guard let textView = textView else { return }

            // Force layout first
            textView.layoutManager?.ensureLayout(for: textView.textContainer!)

            // Delay scroll to let layout complete in the next run loop
            DispatchQueue.main.async { [weak textView] in
                guard let textView = textView,
                      let scrollView = textView.enclosingScrollView else { return }

                // Move cursor to end of document
                let endRange = NSRange(location: (textView.string as NSString).length, length: 0)
                textView.setSelectedRange(endRange)

                // Scroll to make the end visible
                textView.scrollRangeToVisible(endRange)

                // Additionally, scroll a bit more to ensure full visibility
                DispatchQueue.main.async {
                    guard let scrollView = textView.enclosingScrollView else { return }
                    let documentHeight = textView.frame.height
                    let clipViewHeight = scrollView.contentView.bounds.height
                    let scrollY = max(0, documentHeight - clipViewHeight)
                    scrollView.contentView.scroll(to: NSPoint(x: 0, y: scrollY))
                    scrollView.reflectScrolledClipView(scrollView.contentView)
                }
            }
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
            guard let textView = textView,
                  textView.window?.firstResponder === textView else { return }

            let selectedRange = textView.selectedRange()
            let content = textView.string as NSString

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
                cursorOffset = -2 // Account for removed ~~
            } else {
                // Add strikethrough markers
                newLineText = String(leadingSpaces) + "~~" + trimmedContent + "~~" + (hasNewline ? "\n" : "")
                cursorOffset = 2 // Account for added ~~
            }

            // Replace line
            if textView.shouldChangeText(in: lineRange, replacementString: newLineText) {
                textView.replaceCharacters(in: lineRange, with: newLineText)
                textView.didChangeText()

                // Adjust cursor position
                let newCursorPos = max(0, min(selectedRange.location + cursorOffset, (textView.string as NSString).length))
                textView.setSelectedRange(NSRange(location: newCursorPos, length: 0))
            }
        }

        // MARK: - Checkbox

        @objc func toggleCheckbox() {
            guard let textView = textView,
                  textView.window?.firstResponder === textView else { return }

            // Debounce to prevent double-firing
            let now = Date()
            guard now.timeIntervalSince(lastCheckboxToggle) > 0.1 else { return }
            lastCheckboxToggle = now

            let selectedRange = textView.selectedRange()
            let content = textView.string as NSString

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

    // Autocomplete state
    private var autocompleteWindow: NSWindow?
    private var autocompleteStackView: NSStackView?
    private var autocompletePrefix: String = ""
    private var autocompleteStartLocation: Int = 0
    private var windowObserver: NSObjectProtocol?
    private var lastTextLength: Int = 0

    // Note: Most keyboard shortcuts are now handled by KeyboardShortcuts library
    // Only special cases (Esc, Tab) are handled here

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        lastTextLength = string.count

        // Remove old observer
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
            windowObserver = nil
        }

        // Add observer for window losing focus
        if let window = window {
            windowObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                self?.dismissAutocomplete()
            }
        }
    }

    deinit {
        if let observer = windowObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func keyDown(with event: NSEvent) {
        // Escape key - dismiss autocomplete and search
        if event.keyCode == 53 {
            dismissAutocomplete()
            NotificationCenter.default.post(name: .dismissSearch, object: nil)
            NotificationCenter.default.post(name: .clearHashtagFilter, object: nil)
            onEscapePressed?()
            return
        }

        // Tab key (with or without shift)
        if event.keyCode == 48 {
            if event.modifierFlags.contains(.shift) {
                NotificationCenter.default.post(name: .focusQuickEntry, object: nil)
                return
            }
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

    // Intercept tab/backtab commands before they're processed
    override func doCommand(by selector: Selector) {
        if selector == #selector(insertBacktab(_:)) {
            NotificationCenter.default.post(name: .focusQuickEntry, object: nil)
            return
        }
        super.doCommand(by: selector)
    }


    // Shift+Tab always jumps to quick entry (backup method)
    override func insertBacktab(_ sender: Any?) {
        NotificationCenter.default.post(name: .focusQuickEntry, object: nil)
    }

    // MARK: - Mouse Handling for Hashtag Click

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)

        // Check if click is on a hashtag
        if let clickedTag = hashtagAtPoint(point) {
            // Post notification with the clicked tag
            NotificationCenter.default.post(name: .hashtagClicked, object: clickedTag)
            return
        }

        super.mouseDown(with: event)
    }

    private func hashtagAtPoint(_ point: NSPoint) -> String? {
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return nil }

        // Convert point to glyph index
        var fraction: CGFloat = 0
        let glyphIndex = layoutManager.glyphIndex(for: point, in: textContainer, fractionOfDistanceThroughGlyph: &fraction)

        guard glyphIndex < layoutManager.numberOfGlyphs else { return nil }

        let charIndex = layoutManager.characterIndexForGlyph(at: glyphIndex)
        let content = string as NSString

        // Find if we're inside a hashtag
        guard let regex = try? NSRegularExpression(pattern: "#[\\w]+", options: []) else { return nil }
        let fullRange = NSRange(location: 0, length: content.length)
        let matches = regex.matches(in: string, options: [], range: fullRange)

        for match in matches {
            if NSLocationInRange(charIndex, match.range) {
                return content.substring(with: match.range)
            }
        }

        return nil
    }

    // MARK: - Hashtag Autocomplete

    private func checkForHashtagAutocomplete() {
        let cursorPos = selectedRange().location
        guard cursorPos > 0 else {
            dismissAutocomplete()
            return
        }

        let content = string as NSString

        // Check if cursor is at the END of a word (not in the middle of an existing tag)
        if cursorPos < content.length {
            let nextChar = content.substring(with: NSRange(location: cursorPos, length: 1))
            if let char = nextChar.first, char.isLetter || char.isNumber || char == "_" {
                // Cursor is in the middle of a word, don't show autocomplete
                dismissAutocomplete()
                return
            }
        }

        // Find the start of the current word (looking back for #)
        var startPos = cursorPos - 1
        while startPos >= 0 {
            let char = content.substring(with: NSRange(location: startPos, length: 1))
            if char == "#" {
                // Found hashtag start
                let prefix = content.substring(with: NSRange(location: startPos, length: cursorPos - startPos))

                // Check that everything between # and cursor is word characters
                let wordPart = String(prefix.dropFirst())
                let isValidHashtagPrefix = wordPart.isEmpty || wordPart.allSatisfy { $0.isLetter || $0.isNumber || $0 == "_" }

                if isValidHashtagPrefix {
                    showAutocomplete(for: prefix, at: startPos)
                } else {
                    dismissAutocomplete()
                }
                return
            } else if !char.first!.isLetter && !char.first!.isNumber && char != "_" {
                // Hit a non-word character before finding #
                dismissAutocomplete()
                return
            }
            startPos -= 1
        }

        dismissAutocomplete()
    }

    private func showAutocomplete(for prefix: String, at location: Int) {
        let hashtagState = HashtagState.shared
        let theme = AppSettings.shared.theme

        autocompletePrefix = prefix
        autocompleteStartLocation = location

        // Get matching suggestions with counts
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

        // Position window below cursor
        guard let layoutManager = layoutManager,
              let textContainer = textContainer else { return }

        let glyphRange = layoutManager.glyphRange(forCharacterRange: NSRange(location: location, length: 1), actualCharacterRange: nil)
        let rect = layoutManager.boundingRect(forGlyphRange: glyphRange, in: textContainer)
        let lineBottom = rect.origin.y + rect.height + textContainerInset.height
        let xPosition = rect.origin.x + textContainerInset.width

        let bottomPoint = convert(NSPoint(x: xPosition, y: lineBottom), to: nil)
        guard let screenPoint = window?.convertPoint(toScreen: bottomPoint) else { return }

        // Size window
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
        let window = AutocompletePanel(
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

        // Simple stack of tag labels
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
class AutocompletePanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
