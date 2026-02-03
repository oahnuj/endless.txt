import Foundation
import ServiceManagement

@available(macOS 13.0, *)
final class LaunchAtLoginManager: ObservableObject {
    static let shared = LaunchAtLoginManager()

    @Published var isEnabled: Bool {
        didSet {
            updateLoginItem()
        }
    }

    private init() {
        // Check current status
        isEnabled = SMAppService.mainApp.status == .enabled
    }

    private func updateLoginItem() {
        do {
            if isEnabled {
                try SMAppService.mainApp.register()
                print("Launch at login enabled")
            } else {
                try SMAppService.mainApp.unregister()
                print("Launch at login disabled")
            }
        } catch {
            print("Failed to update login item: \(error)")
            // Revert the published value on failure
            DispatchQueue.main.async { [weak self] in
                self?.isEnabled = SMAppService.mainApp.status == .enabled
            }
        }
    }

    func checkStatus() -> SMAppService.Status {
        return SMAppService.mainApp.status
    }
}
