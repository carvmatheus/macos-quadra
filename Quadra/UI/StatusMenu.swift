import AppKit

/// Menu bar item: permission status, shortcut reference and, for every connected
/// screen, its own zone layout and spacing.
@MainActor
final class StatusMenu: NSObject, NSMenuDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private let settings: ZoneSettings
    private let preview = ZoneOverlay()
    var hotKeyErrors: [String] = []

    /// What a layout/spacing menu entry changes, and on which screen.
    private struct Choice {
        let screenID: String
        let layout: ZoneLayout?
        let spacing: CGFloat?
    }

    init(settings: ZoneSettings) {
        self.settings = settings
        super.init()
        item.button?.image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: "Quadra")
        menu.delegate = self
        item.menu = menu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()

        if Permissions.isTrusted {
            menu.addItem(disabled: "Acessibilidade: permitida")
        } else {
            menu.addItem(action("Conceder permissão de Acessibilidade…", #selector(grantPermission)))
        }
        for error in hotKeyErrors {
            menu.addItem(disabled: "⚠️ \(error)")
        }

        menu.addItem(.separator())
        menu.addItem(disabled: "⌃⌘←  Metade esquerda")
        menu.addItem(disabled: "⌃⌘→  Metade direita")
        menu.addItem(disabled: "⇧ ao arrastar  Encaixar em zona")

        menu.addItem(.separator())
        menu.addItem(disabled: "Zonas por monitor")
        for (index, screen) in NSScreen.screens.enumerated() {
            let entry = NSMenuItem(title: Self.title(for: screen, isPrimary: index == 0), action: nil, keyEquivalent: "")
            entry.submenu = zonesMenu(for: screen)
            menu.addItem(entry)
        }

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Sair do Quadra", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }

    private func zonesMenu(for screen: NSScreen) -> NSMenu {
        let screenID = Screens.id(of: screen)
        let current = settings.zones(for: screen)
        let submenu = NSMenu()

        submenu.addItem(disabled: "Layout")
        for layout in ZoneLayout.presets {
            let entry = action(layout.title, #selector(choose(_:)))
            entry.representedObject = Choice(screenID: screenID, layout: layout, spacing: nil)
            entry.state = layout == current.layout ? .on : .off
            entry.indentationLevel = 1
            submenu.addItem(entry)
        }

        submenu.addItem(.separator())
        submenu.addItem(disabled: "Espaço entre zonas")
        for spacing in ZonePreferences.spacingOptions {
            let title = spacing == 0 ? "Sem espaço" : "\(Int(spacing)) pt"
            let entry = action(title, #selector(choose(_:)))
            entry.representedObject = Choice(screenID: screenID, layout: nil, spacing: spacing)
            entry.state = spacing == current.spacing ? .on : .off
            entry.indentationLevel = 1
            submenu.addItem(entry)
        }

        submenu.addItem(.separator())
        let show = action("Mostrar zonas neste monitor", #selector(choose(_:)))
        show.representedObject = Choice(screenID: screenID, layout: nil, spacing: nil)
        submenu.addItem(show)
        return submenu
    }

    @objc private func grantPermission() {
        Permissions.request()
        Permissions.openSettings()
    }

    @objc private func choose(_ sender: NSMenuItem) {
        guard let choice = sender.representedObject as? Choice,
              let screen = NSScreen.screens.first(where: { Screens.id(of: $0) == choice.screenID }) else { return }
        if let layout = choice.layout { settings.setLayout(layout, for: screen) }
        if let spacing = choice.spacing { settings.setSpacing(spacing, for: screen) }

        // Flash the result on that screen so it is obvious which monitor was changed.
        let config = settings.zones(for: screen)
        preview.preview(on: screen, zones: config.layout.zones(in: screen.visibleFrame, spacing: config.spacing), spacing: config.spacing)
    }

    private static func title(for screen: NSScreen, isPrimary: Bool) -> String {
        let size = "\(Int(screen.frame.width))×\(Int(screen.frame.height))"
        return "\(screen.localizedName) — \(size)" + (isPrimary ? " (principal)" : "")
    }

    private func action(_ title: String, _ selector: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: selector, keyEquivalent: "")
        item.target = self
        return item
    }
}

private extension NSMenu {
    func addItem(disabled title: String) {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        addItem(item)
    }
}
