import CoreGraphics

enum HorizontalDirection: Sendable {
    case left, right
}

/// Values of `orientation` in com.apple.dock.
enum DockEdge: String, Sendable {
    case bottom, left, right
}

/// A Dock that stays on screen (not auto-hiding), and the screen it currently sits on.
struct DockPlacement: Equatable, Sendable {
    var screenFrame: CGRect
    var edge: DockEdge
    var thickness: CGFloat
}

/// Pure coordinate math. Cocoa (NSScreen, NSWindow, NSEvent) uses a bottom-left origin;
/// the Accessibility API uses a top-left origin anchored to the primary screen.
enum ScreenGeometry {
    /// Converts a rect between Cocoa and Accessibility space. The conversion is its own inverse.
    static func flip(_ rect: CGRect, primaryHeight: CGFloat) -> CGRect {
        CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }

    static func flip(_ point: CGPoint, primaryHeight: CGFloat) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    /// Index of the closest screen beside `current` in the given direction that shares
    /// some vertical span with it — the screen Windows moves a window to on a second Win+→.
    static func neighbor(of current: CGRect, in frames: [CGRect], toward direction: HorizontalDirection) -> Int? {
        let overlapping = frames.indices.filter { i in
            let f = frames[i]
            return f != current && f.minY < current.maxY && f.maxY > current.minY
        }
        switch direction {
        case .right:
            return overlapping
                .filter { frames[$0].minX >= current.midX }
                .min { frames[$0].minX < frames[$1].minX }
        case .left:
            return overlapping
                .filter { frames[$0].maxX <= current.midX }
                .max { frames[$0].maxX < frames[$1].maxX }
        }
    }

    /// The area windows may fill: everything below the menu bar, minus the Dock's edge only
    /// on the screen the Dock is on. `visible` (NSScreen.visibleFrame) is trusted for the menu
    /// bar but not for the Dock: after the Dock moves to another display macOS can keep
    /// reserving its old spot. `dock` is nil when the Dock auto-hides.
    static func usableFrame(frame: CGRect, visible: CGRect, dock: DockPlacement?) -> CGRect {
        var usable = CGRect(x: frame.minX, y: frame.minY, width: frame.width, height: visible.maxY - frame.minY)
        guard let dock, dock.screenFrame == frame else { return usable }
        switch dock.edge {
        case .bottom:
            usable.origin.y += dock.thickness
            usable.size.height -= dock.thickness
        case .left:
            usable.origin.x += dock.thickness
            usable.size.width -= dock.thickness
        case .right:
            usable.size.width -= dock.thickness
        }
        return usable
    }

    /// The Dock's reserved thickness, read off whichever screen's visible frame still leaves room for it.
    static func dockThickness(screens: [(frame: CGRect, visible: CGRect)]) -> CGFloat? {
        let insets = screens.map { screen in
            max(screen.visible.minY - screen.frame.minY,
                screen.visible.minX - screen.frame.minX,
                screen.frame.maxX - screen.visible.maxX)
        }
        return insets.max().flatMap { $0 > 0 ? $0 : nil }
    }

    /// Where a window should sit when the app refused the target size (Outlook won't go
    /// narrower than ~810pt, for example). Edges of `target` touching the screen edge stay
    /// pinned there so the window grows inward instead of hanging off-screen; otherwise it
    /// grows around the target's center. All rects in Cocoa space.
    static func fit(_ size: CGSize, into target: CGRect, within visible: CGRect) -> CGRect {
        let tolerance: CGFloat = 1
        var x = target.minX
        if size.width > target.width {
            if target.minX <= visible.minX + tolerance {
                x = target.minX
            } else if target.maxX >= visible.maxX - tolerance {
                x = target.maxX - size.width
            } else {
                x = target.midX - size.width / 2
            }
        }
        var y = target.minY
        if size.height > target.height {
            if target.maxY >= visible.maxY - tolerance {
                y = target.maxY - size.height
            } else if target.minY <= visible.minY + tolerance {
                y = target.minY
            } else {
                y = target.midY - size.height / 2
            }
        }
        x = max(visible.minX, min(x, visible.maxX - size.width))
        y = max(visible.minY, min(y, visible.maxY - size.height))
        return CGRect(origin: CGPoint(x: x, y: y), size: size)
    }

    static func approximatelyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }
}
