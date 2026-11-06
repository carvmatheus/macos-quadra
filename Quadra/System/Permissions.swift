import AppKit
import ApplicationServices

/// Moving other apps' windows requires the Accessibility permission (System Settings ›
/// Privacy & Security › Accessibility). It is tied to the bundle id and signing identity.
@MainActor
enum Permissions {
    static var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system prompt that deep-links into Accessibility settings.
    static func request() {
        // String literal of kAXTrustedCheckOptionPrompt, which Swift 6 flags as a non-isolated global.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}
