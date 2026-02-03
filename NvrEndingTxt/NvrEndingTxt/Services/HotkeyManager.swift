import Carbon
import Foundation

final class HotkeyManager {
    private var hotkeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private let handler: () -> Void
    private let settings = AppSettings.shared

    init(handler: @escaping () -> Void) {
        self.handler = handler

        // Listen for shortcut changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsChanged),
            name: .hotkeyChanged,
            object: nil
        )
    }

    deinit {
        unregister()
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func hotkeySettingsChanged(_ notification: Notification) {
        unregister()
        register()
    }

    func register() {
        let keyCode = UInt32(settings.hotkeyCode)
        let modifiers = UInt32(settings.hotkeyModifiers)

        // Create hotkey ID
        var hotkeyID = EventHotKeyID()
        hotkeyID.signature = OSType("NVRT".fourCharCode)
        hotkeyID.id = 1

        // Register the hotkey
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkeyRef
        )

        if status != noErr {
            print("Failed to register hotkey: \(status)")
            return
        }

        // Install event handler
        var eventSpec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))

        let handlerRef = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(
            GetApplicationEventTarget(),
            { (_, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()

                // Verify it's our hotkey
                var hotkeyID = EventHotKeyID()
                GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotkeyID
                )

                if hotkeyID.signature == OSType("NVRT".fourCharCode) && hotkeyID.id == 1 {
                    DispatchQueue.main.async {
                        manager.handler()
                    }
                }

                return noErr
            },
            1,
            &eventSpec,
            handlerRef,
            &eventHandler
        )

        print("Global hotkey registered: \(settings.toggleShortcut.displayString)")
    }

    func unregister() {
        if let ref = hotkeyRef {
            UnregisterEventHotKey(ref)
            hotkeyRef = nil
        }
        if let handler = eventHandler {
            RemoveEventHandler(handler)
            eventHandler = nil
        }
    }
}

// MARK: - String Extension for FourCharCode

private extension String {
    var fourCharCode: FourCharCode {
        var result: FourCharCode = 0
        for char in self.utf8.prefix(4) {
            result = (result << 8) + FourCharCode(char)
        }
        return result
    }
}
