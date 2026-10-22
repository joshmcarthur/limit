import Foundation

public struct SpeedLimitMatch: Equatable, Sendable {
    public let limit: Int
    public let zoneName: String?
}

/// An in-memory register with a uniform grid index, so a lookup only tests the few zones near the point.
public struct SpeedLimitRegister: Sendable {
    private struct Cell: Hashable { let row: Int; let column: Int }

    /// Zones whose bounds span more cells than this go in a short list checked on every lookup,
    /// rather than being inserted in thousands of cells.
    private static let maxCellsPerZone = 2_500

    public let zoneCount: Int
    private let cellSize: Double
    private let zones: [SpeedZone]
    private var grid: [Cell: [Int]] = [:]
    private var wide: [Int] = []

    public init(zones: [SpeedZone], cellSize: Double = 0.05) {
        self.zones = zones
        self.zoneCount = zones.count
        self.cellSize = cellSize
        for (index, zone) in zones.enumerated() {
            let b = zone.bounds
            let rows = cell(b.minLatitude)...cell(b.maxLatitude)
            let columns = cell(b.minLongitude)...cell(b.maxLongitude)
            if rows.count * columns.count > Self.maxCellsPerZone {
                wide.append(index)
                continue
            }
            for row in rows {
                for column in columns { grid[Cell(row: row, column: column), default: []].append(index) }
            }
        }
    }

    public static let empty = SpeedLimitRegister(zones: [])

    /// The limit at a point. Where zones overlap (road corridors meeting at a junction) the one with the
    /// smallest extent wins as the most specific, and the lower limit wins a tie.
    public func lookup(_ point: Coordinate) -> SpeedLimitMatch? {
        let key = Cell(row: cell(point.latitude), column: cell(point.longitude))
        var best: SpeedZone?
        for index in (grid[key] ?? []) + wide {
            let zone = zones[index]
            guard zone.contains(point) else { continue }
            guard let current = best else { best = zone; continue }
            let (a, b) = (zone.bounds.area, current.bounds.area)
            if a < b || (a == b && zone.limit < current.limit) { best = zone }
        }
        return best.map { SpeedLimitMatch(limit: $0.limit, zoneName: $0.name) }
    }

    private func cell(_ degrees: Double) -> Int { Int((degrees / cellSize).rounded(.down)) }
}
