import AppKit
import ApplicationServices

/// A window of another app, driven through the Accessibility API. Frames are in Accessibility space.
struct AXWindow {
    let element: AXUIElement
    let pid: pid_t

    /// The focused window of the frontmost app.
    @MainActor
    static func focused() -> AXWindow? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        for attribute in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            if let window = appElement.element(attribute) {
                return AXWindow(element: window, pid: app.processIdentifier)
            }
        }
        return nil
    }

    /// The window under a point in Accessibility space, ignoring this app's own windows.
    static func at(_ point: CGPoint) -> AXWindow? {
        var hit: AXUIElement?
        guard AXUIElementCopyElementAtPosition(AXUIElementCreateSystemWide(), Float(point.x), Float(point.y), &hit) == .success,
              var current = hit else { return nil }

        var pid: pid_t = 0
        AXUIElementGetPid(current, &pid)
        guard pid != ProcessInfo.processInfo.processIdentifier else { return nil }

        for _ in 0..<32 {
            if current.string(kAXRoleAttribute) == kAXWindowRole {
                return AXWindow(element: current, pid: pid)
            }
            if let window = current.element(kAXWindowAttribute) {
                return AXWindow(element: window, pid: pid)
            }
            guard let parent = current.element(kAXParentAttribute) else { return nil }
            current = parent
        }
        return nil
    }

    var frame: CGRect? {
        guard let position = element.axValue(kAXPositionAttribute),
              let size = element.axValue(kAXSizeAttribute) else { return nil }
        var origin = CGPoint.zero
        var dimensions = CGSize.zero
        AXValueGetValue(position, .cgPoint, &origin)
        AXValueGetValue(size, .cgSize, &dimensions)
        return CGRect(origin: origin, size: dimensions)
    }

    func setFrame(_ frame: CGRect) {
        // Apps with AXEnhancedUserInterface on (set by VoiceOver and some tools) animate
        // every AX resize and drop the second half of a move+resize, so switch it off meanwhile.
        let app = AXUIElementCreateApplication(pid)
        let enhanced = app.bool("AXEnhancedUserInterface") == true
        if enhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse) }
        defer {
            if enhanced { AXUIElementSetAttributeValue(app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue) }
        }

        // Size → position → size: the first resize keeps a window crossing to a smaller display
        // from being clamped at its old size, the last one applies once it sits on the target screen.
        set(size: frame.size)
        set(origin: frame.origin)
        set(size: frame.size)
    }

    private func set(origin: CGPoint) {
        var value = origin
        guard let axValue = AXValueCreate(.cgPoint, &value) else { return }
        AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, axValue)
    }

    private func set(size: CGSize) {
        var value = size
        guard let axValue = AXValueCreate(.cgSize, &value) else { return }
        AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, axValue)
    }
}

private extension AXUIElement {
    func raw(_ attribute: String) -> CFTypeRef? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(self, attribute as CFString, &value) == .success else { return nil }
        return value
    }

    func element(_ attribute: String) -> AXUIElement? {
        guard let value = raw(attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXUIElement.self)
    }

    func axValue(_ attribute: String) -> AXValue? {
        guard let value = raw(attribute), CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return unsafeDowncast(value, to: AXValue.self)
    }

    func string(_ attribute: String) -> String? {
        raw(attribute) as? String
    }

    func bool(_ attribute: String) -> Bool? {
        raw(attribute) as? Bool
    }
}
