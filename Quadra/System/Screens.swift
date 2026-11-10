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

    /// Where snapped windows go on `screen`: respects the Dock only while it is pinned on that
    /// screen (the Dock moves to whichever display the pointer last summoned it on).
    static func usableFrame(of screen: NSScreen, dock: DockPlacement? = dockPlacement()) -> CGRect {
        ScreenGeometry.usableFrame(frame: screen.frame, visible: screen.visibleFrame, dock: dock)
    }

    /// Where the Dock is right now, or nil if it auto-hides. The screen comes from the Dock's
    /// own window rather than visibleFrame, which can keep the Dock's old spot after it moves.
    static func dockPlacement() -> DockPlacement? {
        let prefs = UserDefaults(suiteName: "com.apple.dock")
        guard prefs?.bool(forKey: "autohide") != true, let screen = dockScreen() else { return nil }
        let edge = prefs?.string(forKey: "orientation").flatMap(DockEdge.init(rawValue:)) ?? .bottom
        let measured = ScreenGeometry.dockThickness(screens: NSScreen.screens.map { ($0.frame, $0.visibleFrame) })
        // Fallback when no screen reserves it: the reservation is the icon size plus ~20pt of padding.
        let tileSize = prefs?.double(forKey: "tilesize") ?? 0
        let thickness = measured ?? (tileSize > 0 ? tileSize + 20 : 70)
        return DockPlacement(screenFrame: screen.frame, edge: edge, thickness: thickness)
    }

    /// The Dock draws on a screen-sized window at the Dock level of the display it is on.
    /// Owner and bounds are readable without Screen Recording permission.
    private static func dockScreen() -> NSScreen? {
        guard let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        let dockLevel = Int(CGWindowLevelForKey(.dockWindow))
        for window in windows {
            guard window[kCGWindowOwnerName as String] as? String == "Dock",
                  window[kCGWindowLayer as String] as? Int == dockLevel,
                  let boundsDict = window[kCGWindowBounds as String] as? NSDictionary,
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary) else { continue }
            // Window-list bounds use the same top-left origin as Accessibility.
            return screen(containing: fromAX(bounds))
        }
        return nil
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
