/// A region of the register with one posted limit.
public struct SpeedZone: Equatable, Sendable {
    public let name: String?
    public let limit: Int
    public let polygons: [Polygon]
    public let bounds: BoundingBox

    public init?(name: String?, limit: Int, polygons: [Polygon]) {
        guard let first = polygons.first else { return nil }
        self.name = name
        self.limit = limit
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

    public func contains(_ point: Coordinate) -> Bool {
        guard bounds.contains(point) else { return false }
        return polygons.contains { $0.contains(point) }
    }
}
