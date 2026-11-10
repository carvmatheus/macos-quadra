import AppKit

@MainActor
enum WindowMover {
    /// The last keyboard snap, so a repeated press is recognised even when the app refused
    /// the exact target size (the window then never matches the target frame).
    private static var lastSnap: (window: AXUIElement, action: SnapAction, frame: CGRect)?

    /// Snaps the focused window like Windows' Win+←/→: first press takes that half of the
    /// current screen; pressing again while already there moves it to the opposite half
    /// of the neighbouring screen in that direction.
    static func snapFocusedWindow(_ action: SnapAction) {
        guard Permissions.isTrusted else {
            Permissions.request()
            return
        }
        guard let window = AXWindow.focused(), let axFrame = window.frame else {
            NSSound.beep()
            return
        }

        let current = Screens.fromAX(axFrame)
        guard var screen = Screens.screen(containing: current) else { return }
        let dock = Screens.dockPlacement()
        var target = action.frame(in: Screens.usableFrame(of: screen, dock: dock))

        let screens = NSScreen.screens
        if isAlreadySnapped(window, action: action, current: current, target: target),
           let next = ScreenGeometry.neighbor(of: screen.frame, in: screens.map(\.frame), toward: action.direction) {
            screen = screens[next]
            target = action.opposite.frame(in: Screens.usableFrame(of: screen, dock: dock))
        }

        let placed = place(window, at: target, within: Screens.usableFrame(of: screen, dock: dock))
        lastSnap = (window.element, action, placed)
    }

    /// Moves `window` to `target` (Cocoa space). If the app enforces a minimum size larger than
    /// the target, the window is slid back so it stays inside `visible` instead of hanging off-screen.
    /// Returns the frame the window ended up with.
    @discardableResult
    static func place(_ window: AXWindow, at target: CGRect, within visible: CGRect) -> CGRect {
        window.setFrame(Screens.toAX(target))
        guard let actualAX = window.frame else { return target }
        let actual = Screens.fromAX(actualAX)
        guard actual.width > target.width + 1 || actual.height > target.height + 1 else { return actual }

        let fitted = ScreenGeometry.fit(actual.size, into: target, within: visible)
        window.setFrame(Screens.toAX(fitted))
        return window.frame.map(Screens.fromAX) ?? fitted
    }

    private static func isAlreadySnapped(_ window: AXWindow, action: SnapAction, current: CGRect, target: CGRect) -> Bool {
        // Generous tolerance: apps that resize in steps (Terminal's character grid) never land exactly on target.
        if ScreenGeometry.approximatelyEqual(current, target, tolerance: 20) { return true }
        guard let lastSnap, lastSnap.action == action, CFEqual(lastSnap.window, window.element) else { return false }
        return ScreenGeometry.approximatelyEqual(current, lastSnap.frame, tolerance: 2)
    }
}
