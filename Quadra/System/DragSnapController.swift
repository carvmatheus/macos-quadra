import AppKit

/// FancyZones-style snapping: while a window is being dragged, holding ⇧ shows the zones
/// configured for the screen under the cursor; releasing the mouse over a zone (⇧ still held) snaps the window into it.
/// Releasing near an edge shared by two zones (or a grid corner) spans them all.
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
    /// Drop target in Cocoa space, plus the visible frame of its screen for minimum-size fitting.
    private var activeTarget: (frame: CGRect, visible: CGRect)?
    /// Read once per drag: the Dock doesn't move mid-drag and the window list isn't free to query.
    private var dock: DockPlacement?

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
            dock = Screens.dockPlacement()
        }
        update(shiftHeld: event.modifierFlags.contains(.shift))
    }

    private func flagsChanged(_ event: NSEvent) {
        guard isWindowDrag else { return }
        update(shiftHeld: event.modifierFlags.contains(.shift))
    }

    private func mouseUp(_ event: NSEvent) {
        defer { reset() }
        guard isWindowDrag, let window = candidate, let target = activeTarget else { return }
        // Let the window server finish the drag first, otherwise its final move can land after ours.
        DispatchQueue.main.async {
            WindowMover.place(window, at: target.frame, within: target.visible)
        }
    }

    private func update(shiftHeld: Bool) {
        let mouse = NSEvent.mouseLocation
        guard shiftHeld, let screen = Screens.screen(at: mouse) else {
            activeTarget = nil
            overlay.hide()
            return
        }
        let config = settings.zones(for: screen)
        let usable = Screens.usableFrame(of: screen, dock: dock)
        let zones = config.layout.zones(in: usable, spacing: config.spacing)
        let selection = ZoneLayout.selection(at: mouse, in: zones, spacing: config.spacing)
        activeTarget = selection.map { ($0.frame, usable) }
        overlay.show(on: screen, zones: zones, spacing: config.spacing, selection: selection)
    }

    private func reset() {
        candidate = nil
        startFrame = nil
        dragEventsChecked = 0
        isWindowDrag = false
        dock = nil
        activeTarget = nil
        overlay.hide()
    }
}
