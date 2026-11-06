import AppKit

/// NSScreen lookups plus conversion to and from Accessibility space.
@MainActor
enum Screens {
    /// Accessibility space is anchored to the top of the primary (menu bar) screen.
    static var primaryHeight: CGFloat {
        NSScreen.screens.first?.frame.height ?? 0
    }

    static func toAX(_ rect: CGRect) -> CGRect {
        ScreenGeometry.flip(rect, primaryHeight: primaryHeight)
    }

    static func fromAX(_ rect: CGRect) -> CGRect {
        ScreenGeometry.flip(rect, primaryHeight: primaryHeight)
    }

    static func toAX(_ point: CGPoint) -> CGPoint {
        ScreenGeometry.flip(point, primaryHeight: primaryHeight)
    }

    /// Stable identifier for a display: its UUID survives reboots and reconnects, unlike
    /// the CGDirectDisplayID or the screen's index in `NSScreen.screens`.
    static func id(of screen: NSScreen) -> String {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return screen.localizedName
        }
        let displayID = CGDirectDisplayID(number.uint32Value)
        guard let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue(),
              let string = CFUUIDCreateString(nil, uuid) else {
            return "display-\(displayID)"
        }
        return string as String
    }

    /// The screen holding most of the rect (Cocoa space).
    static func screen(containing rect: CGRect) -> NSScreen? {
        NSScreen.screens.max { area($0.frame.intersection(rect)) < area($1.frame.intersection(rect)) }
    }

    /// The screen under a point (Cocoa space). Includes the top/right edges, which `contains` excludes.
    static func screen(at point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }
}
