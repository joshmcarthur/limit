import Foundation

/// A region of the register with one posted limit.
public struct SpeedZone: Equatable, Sendable {
    /// The register's identifier for the zone. Only used to drop repeated records; not stored on disk.
    public let id: String?
    public let name: String?
    /// The permanent limit.
    public let limit: Int
    /// A lower limit that applies at set times (a school zone), if the register gives one we can read.
    public let reduced: ReducedLimit?
    public let polygons: [Polygon]
    public let bounds: BoundingBox

    public init?(id: String? = nil, name: String?, limit: Int, reduced: ReducedLimit? = nil, polygons: [Polygon]) {
        guard let first = polygons.first else { return nil }
        self.id = id
        self.name = name
        self.limit = limit
        self.reduced = reduced
        self.polygons = polygons
        var box = first.bounds
        for polygon in polygons.dropFirst() {
            let b = polygon.bounds
            box.minLatitude = min(box.minLatitude, b.minLatitude)
            box.maxLatitude = max(box.maxLatitude, b.maxLatitude)
            box.minLongitude = min(box.minLongitude, b.minLongitude)
            box.maxLongitude = max(box.maxLongitude, b.maxLongitude)
        }
        bounds = box
    }

    /// The limit in force at `date`: the reduced one inside its windows, otherwise the permanent one.
    public func effectiveLimit(at date: Date) -> Int {
        if let reduced, reduced.limit < limit, reduced.isActive(at: date) { return reduced.limit }
        return limit
    }

    public func contains(_ point: Coordinate) -> Bool {
        guard bounds.contains(point) else { return false }
        return polygons.contains { $0.contains(point) }
    }
}
