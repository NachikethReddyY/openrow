import AppKit
@preconcurrency import ApplicationServices
import ServiceManagement

struct PermissionStatus: Equatable {
    var accessibility: Bool
    var inputMonitoring: Bool
    var ready: Bool { accessibility && inputMonitoring }

    static func read() -> Self {
        Self(accessibility: AXIsProcessTrusted(), inputMonitoring: CGPreflightListenEventAccess())
    }
}

enum PermissionKind {
    case accessibility, inputMonitoring
    var title: String { self == .accessibility ? "Accessibility" : "Input Monitoring" }
    var symbol: String { self == .accessibility ? "accessibility" : "keyboard" }
    var explanation: String {
        self == .accessibility ? "Find visible controls and click the one you choose." : "Recognize OpenRow shortcuts in other apps."
    }

    @MainActor func request() {
        switch self {
        case .accessibility:
            let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
        case .inputMonitoring:
            _ = CGRequestListenEventAccess()
        }
    }

    @MainActor func openSettings() {
        let pane = self == .accessibility ? "Privacy_Accessibility" : "Privacy_ListenEvent"
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

@MainActor enum LoginItem {
    static var description: String {
        switch SMAppService.mainApp.status {
        case .enabled: "Enabled"
        case .requiresApproval: "Allow OpenRow in Login Items in System Settings."
        case .notRegistered: "Off"
        case .notFound: "Open the bundled OpenRow app to configure launch at login."
        @unknown default: "Status unavailable"
        }
    }

    static func setEnabled(_ enabled: Bool) throws {
        if enabled { try SMAppService.mainApp.register() }
        else { try SMAppService.mainApp.unregister() }
    }
}
