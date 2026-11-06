import AppKit

@MainActor
enum WindowMover {
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
        guard let screen = Screens.screen(containing: current) else { return }
        var target = action.frame(in: screen.visibleFrame)

        // Generous tolerance: apps that resize in steps (Terminal's character grid) never land exactly on target.
        let screens = NSScreen.screens
        if ScreenGeometry.approximatelyEqual(current, target, tolerance: 20),
           let next = ScreenGeometry.neighbor(of: screen.frame, in: screens.map(\.frame), toward: action.direction) {
            target = action.opposite.frame(in: screens[next].visibleFrame)
        }

        window.setFrame(Screens.toAX(target))
    }
}
