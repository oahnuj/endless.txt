import AppKit

/// Custom NSPanel that can receive keyboard input even when borderless
final class FloatingPanel: NSPanel {
    var onEscapePressed: (() -> Void)?

    override var canBecomeKey: Bool {
        return true
    }

    override var canBecomeMain: Bool {
        return true
    }

    override func keyDown(with event: NSEvent) {
        // Handle Escape key (keyCode 53)
        if event.keyCode == 53 {
            onEscapePressed?()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        // This is called when Escape is pressed in some contexts
        onEscapePressed?()
    }
}
