import CoreGraphics

/// Keyboard snaps, triggered by ⌃⌘ + arrow.
enum SnapAction: Sendable {
    case leftHalf, rightHalf

    var direction: HorizontalDirection {
        switch self {
        case .leftHalf: .left
        case .rightHalf: .right
        }
    }

    var opposite: SnapAction {
        switch self {
        case .leftHalf: .rightHalf
        case .rightHalf: .leftHalf
        }
    }

    /// Target frame inside a screen's visible frame (Cocoa space). Odd widths give the extra point to the right half.
    func frame(in visible: CGRect) -> CGRect {
        let leftWidth = (visible.width / 2).rounded(.down)
        switch self {
        case .leftHalf:
            return CGRect(x: visible.minX, y: visible.minY, width: leftWidth, height: visible.height)
        case .rightHalf:
            return CGRect(x: visible.minX + leftWidth, y: visible.minY, width: visible.width - leftWidth, height: visible.height)
        }
    }
}
