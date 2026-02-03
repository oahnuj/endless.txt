import Foundation
import Combine

final class FileService: ObservableObject {
    static let shared = FileService()

    @Published var content: String = ""

    private var saveTask: Task<Void, Never>?
    private let saveDebounceInterval: TimeInterval = 0.5

    private var fileURL: URL {
        AppSettings.shared.documentURL
    }

    private init() {
        loadContent()
    }

    // MARK: - Public Methods

    func loadContent() {
        do {
            if FileManager.default.fileExists(atPath: fileURL.path) {
                content = try String(contentsOf: fileURL, encoding: .utf8)
            } else {
                // Create file with welcome message
                let welcomeMessage = """
                Welcome to nvr-ending.txt
                Your infinite thought capture space.

                Tips:
                - Use #tags to categorize thoughts
                - Press ⌘+Shift+Space to open from anywhere
                - Press Esc to dismiss
                - Press ⌘+Enter to submit quick entry

                ---

                """
                content = welcomeMessage
                try content.write(to: fileURL, atomically: true, encoding: .utf8)
            }
        } catch {
            print("Error loading file: \(error)")
            content = ""
        }
    }

    func save() {
        // Cancel any pending save
        saveTask?.cancel()

        // Debounce saves
        saveTask = Task { [weak self] in
            guard let self = self else { return }

            try? await Task.sleep(nanoseconds: UInt64(self.saveDebounceInterval * 1_000_000_000))

            guard !Task.isCancelled else { return }

            do {
                try self.content.write(to: self.fileURL, atomically: true, encoding: .utf8)
            } catch {
                print("Error saving file: \(error)")
            }
        }
    }

    func appendEntry(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let timestamp = formatTimestamp(Date())
        let entry = "\n[\(timestamp)] \(trimmed)\n"

        content.append(entry)
        save()
    }

    // MARK: - Private Methods

    private func formatTimestamp(_ date: Date) -> String {
        let settings = AppSettings.shared
        let formatter = DateFormatter()
        formatter.dateFormat = settings.timestampFormat
        formatter.timeZone = settings.timezone
        return formatter.string(from: date)
    }

    // MARK: - Search

    func search(_ query: String) -> [SearchResult] {
        guard !query.isEmpty else { return [] }

        var results: [SearchResult] = []
        let lines = content.components(separatedBy: .newlines)

        for (index, line) in lines.enumerated() {
            if line.localizedCaseInsensitiveContains(query) {
                results.append(SearchResult(lineNumber: index + 1, content: line))
            }
        }

        return results
    }

    func findTags() -> [String] {
        let pattern = "#\\w+"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
        }

        let range = NSRange(content.startIndex..., in: content)
        let matches = regex.matches(in: content, options: [], range: range)

        var tags = Set<String>()
        for match in matches {
            if let range = Range(match.range, in: content) {
                tags.insert(String(content[range]))
            }
        }

        return Array(tags).sorted()
    }
}

struct SearchResult: Identifiable {
    let id = UUID()
    let lineNumber: Int
    let content: String
}
