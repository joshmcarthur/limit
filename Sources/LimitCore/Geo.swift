/// A WGS84 position in degrees.
public struct Coordinate: Equatable, Hashable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}

public struct BoundingBox: Equatable, Sendable {
    public var minLatitude: Double
    public var maxLatitude: Double
    public var minLongitude: Double
    public var maxLongitude: Double

    public init(minLatitude: Double, maxLatitude: Double, minLongitude: Double, maxLongitude: Double) {
        self.minLatitude = minLatitude
        self.maxLatitude = maxLatitude
        self.minLongitude = minLongitude
        self.maxLongitude = maxLongitude
    }

    public func contains(_ point: Coordinate) -> Bool {
        point.latitude >= minLatitude && point.latitude <= maxLatitude
            && point.longitude >= minLongitude && point.longitude <= maxLongitude
    }

    /// Area in square degrees. Only used to rank overlapping zones, never as a real area.
    public var area: Double {
        (maxLatitude - minLatitude) * (maxLongitude - minLongitude)
    }
}

/// A closed ring of coordinates. The closing point may or may not repeat the first.
public struct Ring: Equatable, Sendable {
    public let points: [Coordinate]
    public let bounds: BoundingBox

    public init?(points: [Coordinate]) {
        guard points.count >= 3 else { return nil }
        self.points = points
        var minLat = Double.infinity, maxLat = -Double.infinity
        var minLon = Double.infinity, maxLon = -Double.infinity
        for p in points {
            minLat = min(minLat, p.latitude); maxLat = max(maxLat, p.latitude)
            minLon = min(minLon, p.longitude); maxLon = max(maxLon, p.longitude)
        }
        bounds = BoundingBox(minLatitude: minLat, maxLatitude: maxLat, minLongitude: minLon, maxLongitude: maxLon)
    }

    /// Even-odd ray casting. Points exactly on an edge may fall either way.
    public func contains(_ point: Coordinate) -> Bool {
        guard bounds.contains(point) else { return false }
        var inside = false
        var j = points.count - 1
        for i in 0..<points.count {
            let a = points[i], b = points[j]
            if (a.latitude > point.latitude) != (b.latitude > point.latitude) {
                let t = (point.latitude - a.latitude) / (b.latitude - a.latitude)
                let crossingLongitude = a.longitude + t * (b.longitude - a.longitude)
                if point.longitude < crossingLongitude { inside.toggle() }
            }
            j = i
        }
        return inside
    }
}

/// An outer ring with optional holes.
public struct Polygon: Equatable, Sendable {
    public let outer: Ring
    public let holes: [Ring]

    public init(outer: Ring, holes: [Ring] = []) {
        self.outer = outer
        self.holes = holes
    }

    public var bounds: BoundingBox { outer.bounds }

    public func contains(_ point: Coordinate) -> Bool {
        guard outer.contains(point) else { return false }
        return !holes.contains { $0.contains(point) }
    }
}
