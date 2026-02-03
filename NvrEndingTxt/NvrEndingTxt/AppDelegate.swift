import AppKit
import SwiftUI
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var overlayPanel: NSPanel?
    private var hotkeyManager: HotkeyManager?
    private let fileService = FileService.shared

    // UserDefaults keys for window frame
    private let windowFrameKey = "overlayWindowFrame"

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupOverlayPanel()
        setupHotkey()

        // Hide dock icon (backup - Info.plist should handle this)
        NSApp.setActivationPolicy(.accessory)
    }

    // MARK: - Status Item (Menu Bar)

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "text.alignleft", accessibilityDescription: "NvrEndingTxt")
            button.action = #selector(statusItemClicked)
            button.target = self
        }

        // Create menu for right-click
        let menu = NSMenu()
        let openItem = NSMenuItem(title: "Open  ⌘⇧Space", action: #selector(showOverlay), keyEquivalent: "")
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))

        statusItem?.menu = menu
    }

    @objc private func statusItemClicked(_ sender: NSStatusBarButton) {
        // Left click toggles overlay, right click shows menu
        if NSApp.currentEvent?.type == .leftMouseUp {
            statusItem?.menu = nil
            toggleOverlay()
            // Re-attach menu after a delay for right-click
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.setupStatusItemMenu()
            }
        }
    }

    private func setupStatusItemMenu() {
        let menu = NSMenu()
        let shortcut = AppSettings.shared.toggleShortcut.displayString
        let openItem = NSMenuItem(title: "Open  \(shortcut)", action: #selector(showOverlay), keyEquivalent: "")
        menu.addItem(openItem)
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem?.menu = menu
    }

    // MARK: - Overlay Panel

    private func setupOverlayPanel() {
        let contentView = ContentView()
        let hostingView = NSHostingView(rootView: contentView)

        // Load saved frame or use default
        let defaultFrame = NSRect(x: 0, y: 0, width: 450, height: 550)
        let initialFrame = loadSavedFrame() ?? defaultFrame

        let panel = FloatingPanel(
            contentRect: initialFrame,
            styleMask: [.borderless, .resizable],
            backing: .buffered,
            defer: false
        )

        panel.contentView = hostingView
        panel.isMovableByWindowBackground = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isReleasedWhenClosed = false
        panel.hasShadow = true
        panel.minSize = NSSize(width: 350, height: 400)
        panel.becomesKeyOnlyIfNeeded = false

        // Set delegate to track move/resize
        panel.delegate = self

        // Position: use saved position or center
        if loadSavedFrame() == nil {
            panel.center()
        }

        // Round corners - borderless window
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.contentView?.wantsLayer = true
        panel.contentView?.layer?.cornerRadius = 12
        panel.contentView?.layer?.masksToBounds = true

        // Handle Escape key via panel callback
        panel.onEscapePressed = { [weak self] in
            self?.hideOverlay()
        }

        // Also monitor for Escape globally when panel is key
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 && self?.overlayPanel?.isKeyWindow == true {
                self?.hideOverlay()
                return nil
            }
            return event
        }

        overlayPanel = panel
    }

    // MARK: - Window Frame Persistence

    private func saveWindowFrame() {
        guard let panel = overlayPanel else { return }
        let frame = panel.frame
        let frameDict: [String: CGFloat] = [
            "x": frame.origin.x,
            "y": frame.origin.y,
            "width": frame.size.width,
            "height": frame.size.height
        ]
        UserDefaults.standard.set(frameDict, forKey: windowFrameKey)
    }

    private func loadSavedFrame() -> NSRect? {
        guard let frameDict = UserDefaults.standard.dictionary(forKey: windowFrameKey) as? [String: CGFloat],
              let x = frameDict["x"],
              let y = frameDict["y"],
              let width = frameDict["width"],
              let height = frameDict["height"] else {
            return nil
        }

        let frame = NSRect(x: x, y: y, width: width, height: height)

        // Validate frame is still on a visible screen
        let isOnScreen = NSScreen.screens.contains { screen in
            screen.visibleFrame.intersects(frame)
        }

        return isOnScreen ? frame : nil
    }

    // MARK: - Hotkey

    private func setupHotkey() {
        hotkeyManager = HotkeyManager { [weak self] in
            self?.toggleOverlay()
        }
        hotkeyManager?.register()
    }

    // MARK: - Actions

    @objc func toggleOverlay() {
        if overlayPanel?.isVisible == true {
            hideOverlay()
        } else {
            showOverlay()
        }
    }

    @objc func showOverlay() {
        guard let panel = overlayPanel else { return }

        // Only center if no saved position
        if loadSavedFrame() == nil {
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let panelFrame = panel.frame
                let x = screenFrame.midX - panelFrame.width / 2
                let y = screenFrame.midY - panelFrame.height / 2
                panel.setFrameOrigin(NSPoint(x: x, y: y))
            }
        }

        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        // Post notification to focus text field
        NotificationCenter.default.post(name: .focusQuickEntry, object: nil)
    }

    @objc func hideOverlay() {
        saveWindowFrame()
        overlayPanel?.orderOut(nil)
    }

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quitApp() {
        saveWindowFrame()
        NSApp.terminate(nil)
    }
}

// MARK: - NSWindowDelegate

extension AppDelegate: NSWindowDelegate {
    func windowDidMove(_ notification: Notification) {
        saveWindowFrame()
    }

    func windowDidResize(_ notification: Notification) {
        saveWindowFrame()
    }

    func windowDidEndLiveResize(_ notification: Notification) {
        saveWindowFrame()
    }

    func windowDidResignKey(_ notification: Notification) {
        // When clicking outside, hide the overlay
        // This ensures the toggle works correctly on first press
        guard let panel = overlayPanel, panel.isVisible else { return }
        hideOverlay()
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let focusQuickEntry = Notification.Name("focusQuickEntry")
}
