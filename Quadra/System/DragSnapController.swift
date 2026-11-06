import AppKit

/// FancyZones-style snapping: while a window is being dragged, holding ⇧ shows the zones
/// configured for the screen under the cursor; releasing the mouse over a zone (⇧ still held) snaps the window into it.
///
/// Global NSEvent monitors only observe — the drag itself stays with the window server.
/// A drag counts as a window drag once the window under the initial click changes position.
@MainActor
final class DragSnapController {
    private let settings: ZoneSettings
    private let overlay = ZoneOverlay()
    private var monitors: [Any] = []

    private var candidate: AXWindow?
    private var startFrame: CGRect?
    private var dragEventsChecked = 0
    private var isWindowDrag = false
    private var activeZone: CGRect?

    /// Mouse drags that haven't moved the window by then are selections, scrollbar drags, etc.
    private let maxEventsBeforeGivingUp = 40

    init(settings: ZoneSettings) {
        self.settings = settings
    }

    func start() {
        let handlers: [(NSEvent.EventTypeMask, (DragSnapController) -> (NSEvent) -> Void)] = [
            (.leftMouseDown, { $0.mouseDown }),
            (.leftMouseDragged, { $0.mouseDragged }),
            (.leftMouseUp, { $0.mouseUp }),
            (.flagsChanged, { $0.flagsChanged }),
        ]
        for (mask, handler) in handlers {
            if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    handler(self)(event)
                }
            }) {
                monitors.append(monitor)
            }
        }
    }

    private func mouseDown(_ event: NSEvent) {
        reset()
        guard Permissions.isTrusted,
              let window = AXWindow.at(Screens.toAX(NSEvent.mouseLocation)),
              let frame = window.frame else { return }
        candidate = window
        startFrame = frame
    }

    private func mouseDragged(_ event: NSEvent) {
        if !isWindowDrag {
            guard let candidate, let startFrame, dragEventsChecked < maxEventsBeforeGivingUp else { return }
            dragEventsChecked += 1
            guard let frame = candidate.frame else { return }
            // Moved without resizing: it's a title-bar drag. A resize changes the size and is left alone.
            guard frame.origin != startFrame.origin, frame.size == startFrame.size else { return }
            isWindowDrag = true
        }
        update(shiftHeld: event.modifierFlags.contains(.shift))
    }

    private func flagsChanged(_ event: NSEvent) {
        guard isWindowDrag else { return }
        update(shiftHeld: event.modifierFlags.contains(.shift))
    }

    private func mouseUp(_ event: NSEvent) {
        defer { reset() }
        guard isWindowDrag, let window = candidate, let zone = activeZone else { return }
        let target = Screens.toAX(zone)
        // Let the window server finish the drag first, otherwise its final move can land after ours.
        DispatchQueue.main.async {
            window.setFrame(target)
        }
    }

    private func update(shiftHeld: Bool) {
        let mouse = NSEvent.mouseLocation
        guard shiftHeld, let screen = Screens.screen(at: mouse) else {
            activeZone = nil
            overlay.hide()
            return
        }
        let config = settings.zones(for: screen)
        let zones = config.layout.zones(in: screen.visibleFrame, spacing: config.spacing)
        let index = ZoneLayout.zoneIndex(at: mouse, in: zones, spacing: config.spacing)
        activeZone = index.map { zones[$0] }
        overlay.show(on: screen, zones: zones, spacing: config.spacing, highlighted: index)
    }

    private func reset() {
        candidate = nil
        startFrame = nil
        dragEventsChecked = 0
        isWindowDrag = false
        activeZone = nil
        overlay.hide()
    }
}
