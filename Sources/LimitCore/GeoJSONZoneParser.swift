import Foundation

public enum ZoneParseError: Error, Equatable {
    case notAFeatureCollection
}

public struct ZoneParseResult: Equatable, Sendable {
    public var zones: [SpeedZone] = []
    public var featureCount = 0
    /// Features with no usable numeric limit. If every feature lands here, the source has no limit field.
    public var skippedWithoutLimit = 0
    public var skippedBadGeometry = 0
    /// ArcGIS sets this when more pages exist.
    public var exceededTransferLimit = false
}

/// Reads speed limit zones from a GeoJSON FeatureCollection (the `pgeojson` output of the register's
/// ArcGIS feature service).
///
/// The limit is read from the first property whose name, ignoring case and punctuation, is one of
/// `limitKeys`. The register layer's field name has not been confirmed (the sample dump only carried
/// `speedLimitZoneName`), so this is deliberately tolerant.
public enum GeoJSONZoneParser {
    public static let limitKeys: Set<String> = [
        "speedlimitzonevalue", "speedlimit", "speedlimitvalue", "speedlimitkmh", "postedspeedlimit", "speed", "limit", "limitkmh",
    ]
    public static let nameKeys: Set<String> = ["speedlimitzonename", "zonename", "roadname", "name"]
    /// NZ limits run from 10 to 110 km/h in steps of 5 or 10.
    public static let validLimits = 10...110

    public static func parse(_ data: Data) throws -> ZoneParseResult {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let features = root["features"] as? [Any]
        else { throw ZoneParseError.notAFeatureCollection }

        var result = ZoneParseResult()
        if let props = root["properties"] as? [String: Any], let exceeded = props["exceededTransferLimit"] as? Bool {
            result.exceededTransferLimit = exceeded
        }

        for case let feature as [String: Any] in features {
            result.featureCount += 1
            let properties = feature["properties"] as? [String: Any] ?? [:]
            guard let limit = limit(in: properties) else {
                result.skippedWithoutLimit += 1
                continue
            }
            let polygons = polygons(from: feature["geometry"] as? [String: Any])
            guard let zone = SpeedZone(name: name(in: properties), limit: limit, polygons: polygons) else {
                result.skippedBadGeometry += 1
                continue
            }
            result.zones.append(zone)
        }
        return result
    }

    // MARK: Properties

    static func limit(in properties: [String: Any]) -> Int? {
        for (key, value) in properties where limitKeys.contains(normalise(key)) {
            if let limit = limitValue(value) { return limit }
        }
        return nil
    }

    static func name(in properties: [String: Any]) -> String? {
        for (key, value) in properties where nameKeys.contains(normalise(key)) {
            if let text = value as? String {
                let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private static func normalise(_ key: String) -> String {
        String(key.lowercased().filter { $0.isLetter || $0.isNumber })
    }

    private static func limitValue(_ value: Any) -> Int? {
        let number: Double?
        if let string = value as? String {
            let digits = string.trimmingCharacters(in: .whitespaces).prefix { $0.isNumber }
            number = Double(digits)
        } else {
            number = double(value)
        }
        guard let number, number == number.rounded(), validLimits.contains(Int(number)), Int(number) % 5 == 0 else { return nil }
        return Int(number)
    }

    // MARK: Geometry

    private static func polygons(from geometry: [String: Any]?) -> [Polygon] {
        guard let geometry, let type = geometry["type"] as? String, let coordinates = geometry["coordinates"] as? [Any]
        else { return [] }
        switch type {
        case "Polygon":
            return polygon(from: coordinates).map { [$0] } ?? []
        case "MultiPolygon":
            return coordinates.compactMap { ($0 as? [Any]).flatMap(polygon(from:)) }
        default:
            return []
        }
    }

    private static func polygon(from rings: [Any]) -> Polygon? {
        let parsed = rings.compactMap { ($0 as? [Any]).flatMap(ring(from:)) }
        guard let outer = parsed.first, parsed.count == rings.count else { return nil }
        return Polygon(outer: outer, holes: Array(parsed.dropFirst()))
    }

    private static func ring(from positions: [Any]) -> Ring? {
        var points: [Coordinate] = []
        points.reserveCapacity(positions.count)
        for case let position as [Any] in positions {
            guard position.count >= 2, let lon = double(position[0]), let lat = double(position[1]) else { return nil }
            points.append(Coordinate(latitude: lat, longitude: lon))
        }
        return Ring(points: points)
    }

    private static func double(_ value: Any?) -> Double? {
        switch value {
        case let d as Double: return d
        case let i as Int: return Double(i)
        case let n as NSNumber: return n.doubleValue
        default: return nil
        }
    }
}
