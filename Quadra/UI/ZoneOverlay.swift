import AppKit

/// Click-through panel covering one screen that draws the zones while a window is dragged with ⇧.
@MainActor
final class ZoneOverlay {
    private let panel: NSPanel
    private let zoneView = ZoneView()
    private var hideTask: Task<Void, Never>?

    init() {
        panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
        panel.contentView = zoneView
    }

    /// `zones` are in Cocoa screen coordinates.
    func show(on screen: NSScreen, zones: [CGRect], spacing: CGFloat, highlighted: Int?) {
        hideTask?.cancel()
        if panel.frame != screen.frame {
            panel.setFrame(screen.frame, display: false)
        }
        let origin = screen.frame.origin
        zoneView.zones = zones.map { $0.offsetBy(dx: -origin.x, dy: -origin.y) }
        zoneView.highlighted = highlighted
        // Rounded corners would leave notches where zones touch, so they shrink with the gap.
        zoneView.cornerRadius = min(10, spacing)
        if !panel.isVisible {
            panel.orderFrontRegardless()
        }
    }

    /// Shows the zones briefly, e.g. after a layout is picked, so the user sees the result and which screen it applies to.
    func preview(on screen: NSScreen, zones: [CGRect], spacing: CGFloat) {
        show(on: screen, zones: zones, spacing: spacing, highlighted: nil)
        hideTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.2))
            guard !Task.isCancelled else { return }
            self?.panel.orderOut(nil)
        }
    }

    func hide() {
        hideTask?.cancel()
        panel.orderOut(nil)
    }
}

private final class ZoneView: NSView {
    var zones: [CGRect] = [] {
        didSet { if zones != oldValue { needsDisplay = true } }
    }
    var highlighted: Int? {
        didSet { if highlighted != oldValue { needsDisplay = true } }
    }
    var cornerRadius: CGFloat = 10 {
        didSet { if cornerRadius != oldValue { needsDisplay = true } }
    }

    override func draw(_ dirtyRect: NSRect) {
        let accent = NSColor.controlAccentColor
        for (index, zone) in zones.enumerated() {
            let isActive = index == highlighted
            let path = NSBezierPath(roundedRect: zone, xRadius: cornerRadius, yRadius: cornerRadius)
            accent.withAlphaComponent(isActive ? 0.45 : 0.12).setFill()
            path.fill()
            accent.withAlphaComponent(isActive ? 1 : 0.6).setStroke()
            path.lineWidth = isActive ? 3 : 1.5
            path.stroke()
            drawNumber(index + 1, in: zone, active: isActive)
        }
    }

    private func drawNumber(_ number: Int, in zone: CGRect, active: Bool) {
        let label = NSAttributedString(string: "\(number)", attributes: [
            .font: NSFont.systemFont(ofSize: min(zone.width, zone.height) * 0.25, weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(active ? 0.95 : 0.6),
        ])
        let size = label.size()
        label.draw(at: CGPoint(x: zone.midX - size.width / 2, y: zone.midY - size.height / 2))
    }
}
