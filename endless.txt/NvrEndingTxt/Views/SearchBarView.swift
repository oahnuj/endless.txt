import SwiftUI
import AppKit

struct SearchBarView: View {
    @ObservedObject var searchState: SearchState
    @ObservedObject private var settings = AppSettings.shared
    @FocusState private var isSearchFieldFocused: Bool
    @State private var escMonitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            // Search icon
            Image(systemName: "magnifyingglass")
                .foregroundColor(settings.theme.secondaryTextColor)
                .font(.system(size: 11))

            // Search field
            TextField("Search...", text: $searchState.query)
                .textFieldStyle(.plain)
                .font(.custom(settings.fontName, size: settings.fontSize - 2))
                .foregroundColor(settings.theme.textColor)
                .focused($isSearchFieldFocused)
                .frame(minWidth: 80, maxWidth: 120)
                .onSubmit {
                    // Enter key goes to next match
                    NotificationCenter.default.post(name: .findNext, object: nil)
                }
                .onChange(of: searchState.query) { _ in
                    // Reset to first match when query changes
                    searchState.currentMatchIndex = 0
                }

            // Match count (compact)
            if !searchState.query.isEmpty {
                if searchState.totalMatches > 0 {
                    Text("\(searchState.currentMatchIndex + 1)/\(searchState.totalMatches)")
                        .font(.custom(settings.fontName, size: settings.fontSize - 3))
                        .foregroundColor(settings.theme.secondaryTextColor)
                        .monospacedDigit()
                } else {
                    Text("0")
                        .font(.custom(settings.fontName, size: settings.fontSize - 3))
                        .foregroundColor(settings.theme.secondaryTextColor.opacity(0.6))
                }
            }

            // Navigation buttons (compact)
            if searchState.totalMatches > 0 {
                HStack(spacing: 2) {
                    Button(action: {
                        NotificationCenter.default.post(name: .findPrevious, object: nil)
                    }) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(settings.theme.secondaryTextColor)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Previous (⇧⌘G)")

                    Button(action: {
                        NotificationCenter.default.post(name: .findNext, object: nil)
                    }) {
                        Image(systemName: "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(settings.theme.secondaryTextColor)
                            .frame(width: 18, height: 18)
                    }
                    .buttonStyle(.plain)
                    .help("Next (⌘G)")
                }
            }

            // Dismiss button
            Button(action: {
                dismissSearch()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundColor(settings.theme.secondaryTextColor.opacity(0.7))
                    .frame(width: 14, height: 14)
            }
            .buttonStyle(.plain)
            .help("Close (Esc)")
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(settings.theme.inputBackgroundColor.opacity(0.95))
                .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(settings.theme.secondaryTextColor.opacity(0.2), lineWidth: 1)
                )
        )
        .onAppear {
            // Delay focus slightly to ensure view is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isSearchFieldFocused = true
            }
            setupEscMonitor()
        }
        .onDisappear {
            removeEscMonitor()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSearch)) { _ in
            isSearchFieldFocused = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSearch)) { _ in
            isSearchFieldFocused = true
        }
    }

    private func setupEscMonitor() {
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 { // Esc
                DispatchQueue.main.async {
                    dismissSearch()
                }
                return nil // Consume the event
            }
            return event
        }
    }

    private func removeEscMonitor() {
        if let monitor = escMonitor {
            NSEvent.removeMonitor(monitor)
            escMonitor = nil
        }
    }

    private func dismissSearch() {
        // Don't reset query - keep it cached for next time
        searchState.isVisible = false
    }
}

#Preview {
    VStack {
        HStack {
            Spacer()
            SearchBarView(searchState: {
                let state = SearchState()
                state.query = "test"
                state.totalMatches = 5
                state.currentMatchIndex = 2
                return state
            }())
            .padding()
        }
    }
    .frame(width: 400, height: 100)
    .background(Color(hex: "1E1E1E"))
}
