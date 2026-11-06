import CoreGraphics

enum HorizontalDirection: Sendable {
    case left, right
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

    static func approximatelyEqual(_ a: CGRect, _ b: CGRect, tolerance: CGFloat) -> Bool {
        abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
            && abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
    }
}
