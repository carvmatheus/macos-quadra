import CoreGraphics

/// Zone layout and spacing chosen for one display.
struct DisplayZones: Codable, Equatable, Sendable {
    var layoutID: String
    var spacing: CGFloat

    var layout: ZoneLayout {
        ZoneLayout(id: layoutID) ?? .default
    }
}

/// Per-display zone settings, keyed by the display's UUID so they survive reboots and
/// reconnecting monitors. Displays never configured fall back to `fallback`.
struct ZonePreferences: Codable, Equatable, Sendable {
    static let spacingOptions: [CGFloat] = [0, 4, 8, 16, 24]

    var fallback = DisplayZones(layoutID: ZoneLayout.default.id, spacing: 0)
    var displays: [String: DisplayZones] = [:]

    func zones(for displayID: String) -> DisplayZones {
        displays[displayID] ?? fallback
    }

    mutating func setLayout(_ layout: ZoneLayout, for displayID: String) {
        displays[displayID, default: fallback].layoutID = layout.id
    }

    mutating func setSpacing(_ spacing: CGFloat, for displayID: String) {
        displays[displayID, default: fallback].spacing = spacing
    }
}
