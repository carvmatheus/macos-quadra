import AppKit

/// Persists `ZonePreferences` in UserDefaults and resolves them for an NSScreen.
@MainActor
final class ZoneSettings {
    private static let key = "zonePreferences"
    /// Single global layout saved by v0.1, used as the fallback for every display.
    private static let legacyLayoutKey = "zoneLayout"

    private let defaults: UserDefaults
    private(set) var preferences: ZonePreferences

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: Self.key),
           let saved = try? JSONDecoder().decode(ZonePreferences.self, from: data) {
            preferences = saved
        } else {
            preferences = ZonePreferences()
            if let legacy = defaults.string(forKey: Self.legacyLayoutKey), ZoneLayout(id: legacy) != nil {
                preferences.fallback.layoutID = legacy
            }
        }
    }

    func zones(for screen: NSScreen) -> DisplayZones {
        preferences.zones(for: Screens.id(of: screen))
    }

    func setLayout(_ layout: ZoneLayout, for screen: NSScreen) {
        preferences.setLayout(layout, for: Screens.id(of: screen))
        save()
    }

    func setSpacing(_ spacing: CGFloat, for screen: NSScreen) {
        preferences.setSpacing(spacing, for: Screens.id(of: screen))
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(preferences) {
            defaults.set(data, forKey: Self.key)
        }
    }
}
