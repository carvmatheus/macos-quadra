import AppKit
import Carbon.HIToolbox

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let hotKeys = HotKeyCenter()
    private let settings = ZoneSettings()
    private var dragSnap: DragSnapController!
    private var statusMenu: StatusMenu!

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        dragSnap = DragSnapController(settings: settings)
        dragSnap.start()
        statusMenu = StatusMenu(settings: settings)

        registerHotKeys()

        if !Permissions.isTrusted {
            Permissions.request()
        }
    }

    private func registerHotKeys() {
        let bindings: [(key: Int, label: String, action: SnapAction)] = [
            (kVK_LeftArrow, "⌃⌘←", .leftHalf),
            (kVK_RightArrow, "⌃⌘→", .rightHalf),
        ]
        for binding in bindings {
            do {
                try hotKeys.register(keyCode: binding.key, modifiers: cmdKey | controlKey) {
                    WindowMover.snapFocusedWindow(binding.action)
                }
            } catch {
                statusMenu.hotKeyErrors.append("\(binding.label) já está em uso por outro app (erro \(error.status))")
            }
        }
    }
}
