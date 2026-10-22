import Foundation

public struct SpeedLimitMatch: Sendable {
    public let limit: Int
    public let zoneName: String?
    /// Seasonal and emergency limits end, so the driver is told which one they're looking at.
    public let kind: ZoneKind
    /// Which zone in the register matched, so the next lookup can prefer staying in it.
    let zoneID: Int

    public init(limit: Int, zoneName: String?, kind: ZoneKind = .permanent) {
        self.init(limit: limit, zoneName: zoneName, kind: kind, zoneID: -1)
    }

    init(limit: Int, zoneName: String?, kind: ZoneKind, zoneID: Int) {
        self.limit = limit
        self.zoneName = zoneName
        self.kind = kind
        self.zoneID = zoneID
    }
}

/// Two matches are the same when the driver would see the same thing; which record they came from doesn't matter.
extension SpeedLimitMatch: Equatable {
    public static func == (a: SpeedLimitMatch, b: SpeedLimitMatch) -> Bool {
        a.limit == b.limit && a.zoneName == b.zoneName && a.kind == b.kind
    }
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

    /// The limit at a point and time. Only records that apply at `date` count: an ended record, an
    /// emergency limit that's over, or a seasonal one out of season is ignored, and a school zone's
    /// reduced limit applies inside its windows. Of those, an emergency limit beats a seasonal one, which
    /// beats a permanent or variable one. Among equals the zone with the smallest extent wins as the most
    /// specific, and the lower limit wins a tie.
    ///
    /// Where a bridge and the road under it overlap with different limits, a position can't say which level
    /// you're on. Then the zone in `previous` wins if it's one of the two (you stay on the road you were on),
    /// otherwise the lower limit does.
    public func lookup(_ point: Coordinate, at date: Date = Date(), preferring previous: SpeedLimitMatch? = nil) -> SpeedLimitMatch? {
        let key = Cell(row: cell(point.latitude), column: cell(point.longitude))
        var candidates: [Int] = []
        for index in (grid[key] ?? []) + wide {
            let zone = zones[index]
            if zone.contains(point), zone.isActive(at: date) { candidates.append(index) }
        }
        guard var best = candidates.first else { return nil }
        for index in candidates.dropFirst() where outranks(index, best, at: date) { best = index }

        if zones[best].structure.isGradeSeparated {
            let opposite: StructureType = zones[best].structure == .overpass ? .underpass : .overpass
            let rivals = candidates.filter { zones[$0].structure == opposite && zones[$0].kind.priority == zones[best].kind.priority }
            if var other = rivals.first {
                for index in rivals.dropFirst() where outranks(index, other, at: date) { other = index }
                if zones[other].effectiveLimit(at: date) != zones[best].effectiveLimit(at: date) {
                    if let previous, previous.zoneID == best || previous.zoneID == other {
                        best = previous.zoneID
                    } else if zones[other].effectiveLimit(at: date) < zones[best].effectiveLimit(at: date) {
                        best = other
                    }
                }
            }
        }
        let zone = zones[best]
        return SpeedLimitMatch(limit: zone.effectiveLimit(at: date), zoneName: zone.name, kind: zone.kind, zoneID: best)
    }

    /// Whether zone `a` should be shown in preference to zone `b`.
    private func outranks(_ a: Int, _ b: Int, at date: Date) -> Bool {
        let (za, zb) = (zones[a], zones[b])
        if za.kind.priority != zb.kind.priority { return za.kind.priority > zb.kind.priority }
        let (areaA, areaB) = (za.bounds.area, zb.bounds.area)
        if areaA != areaB { return areaA < areaB }
        return za.effectiveLimit(at: date) < zb.effectiveLimit(at: date)
    }

    private func cell(_ degrees: Double) -> Int { Int((degrees / cellSize).rounded(.down)) }
}
