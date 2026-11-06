import CoreGraphics

/// Zone templates modelled on PowerToys FancyZones: drag a window with ⇧ held,
/// the zones appear, and dropping snaps the window into the highlighted one.
enum ZoneLayout: Equatable, Sendable {
    case columns(Int)
    case rows(Int)
    case grid(columns: Int, rows: Int)
    /// FancyZones' "Priority Grid" for three zones: 25% | 50% | 25%.
    case priority

    static let presets: [ZoneLayout] = [
        .columns(2), .columns(3), .columns(4),
        .rows(2), .rows(3),
        .grid(columns: 2, rows: 2), .grid(columns: 3, rows: 2),
        .priority,
    ]

    static let `default`: ZoneLayout = .columns(3)

    var title: String {
        switch self {
        case .columns(let n): "\(n) colunas"
        case .rows(let n): "\(n) linhas"
        case .grid(let c, let r): "Grade \(c)×\(r)"
        case .priority: "Foco central (25 | 50 | 25)"
        }
    }

    var id: String {
        switch self {
        case .columns(let n): "columns-\(n)"
        case .rows(let n): "rows-\(n)"
        case .grid(let c, let r): "grid-\(c)x\(r)"
        case .priority: "priority"
        }
    }

    init?(id: String) {
        guard let match = ZoneLayout.presets.first(where: { $0.id == id }) else { return nil }
        self = match
    }

    /// Zones in Cocoa space, numbered left→right, top→bottom. `spacing` is the gap
    /// between zones and also between the outer zones and the screen edges.
    func zones(in area: CGRect, spacing: CGFloat) -> [CGRect] {
        let inner = area.insetBy(dx: spacing / 2, dy: spacing / 2)
        let columnFractions: [CGFloat]
        let rowCount: Int
        switch self {
        case .columns(let n):
            columnFractions = Self.equal(n)
            rowCount = 1
        case .rows(let n):
            columnFractions = [1]
            rowCount = n
        case .grid(let c, let r):
            columnFractions = Self.equal(c)
            rowCount = r
        case .priority:
            columnFractions = [0.25, 0.5, 0.25]
            rowCount = 1
        }

        let xs = Self.edges(from: inner.minX, length: inner.width, fractions: columnFractions)
        // Rows go top-down visually, which is descending y in Cocoa space.
        let ys = Self.edges(from: inner.minY, length: inner.height, fractions: Self.equal(rowCount)).reversed() as [CGFloat]

        var zones: [CGRect] = []
        for row in 0..<rowCount {
            for column in 0..<columnFractions.count {
                let cell = CGRect(x: xs[column], y: ys[row + 1], width: xs[column + 1] - xs[column], height: ys[row] - ys[row + 1])
                zones.append(cell.insetBy(dx: spacing / 2, dy: spacing / 2))
            }
        }
        return zones
    }

    /// The zone under `point`, counting half of the surrounding gap as part of each zone
    /// so the highlight doesn't flicker off while crossing between zones.
    static func zoneIndex(at point: CGPoint, in zones: [CGRect], spacing: CGFloat) -> Int? {
        zones.firstIndex { $0.insetBy(dx: -spacing / 2, dy: -spacing / 2).contains(point) }
    }

    private static func equal(_ n: Int) -> [CGFloat] {
        Array(repeating: 1 / CGFloat(max(n, 1)), count: max(n, 1))
    }

    /// Whole-point boundaries for consecutive segments; rounding the cumulative edge
    /// (instead of each width) keeps segments contiguous with no gaps or overlap.
    private static func edges(from origin: CGFloat, length: CGFloat, fractions: [CGFloat]) -> [CGFloat] {
        var result = [origin]
        var cumulative: CGFloat = 0
        for (i, fraction) in fractions.enumerated() {
            cumulative += fraction
            result.append(i == fractions.count - 1 ? origin + length : (origin + length * cumulative).rounded())
        }
        return result
    }
}
