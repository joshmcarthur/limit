import XCTest
@testable import LimitCore

final class GeoJSONZoneParserTests: XCTestCase {
    private func collection(_ features: String, exceeded: Bool = false) -> Data {
        Data("""
        {"type":"FeatureCollection","properties":{"exceededTransferLimit":\(exceeded)},"features":[\(features)]}
        """.utf8)
    }

    private let square = "[[[174,-41],[175,-41],[175,-40],[174,-40],[174,-41]]]"

    func testParsesPolygonWithLimitAndName() throws {
        let data = collection("""
        {"type":"Feature","properties":{"speedLimit":50,"speedLimitZoneName":"MAIN NORTH ROAD"},
         "geometry":{"type":"Polygon","coordinates":\(square)}}
        """)
        let result = try GeoJSONZoneParser.parse(data)
        XCTAssertEqual(result.zones.count, 1)
        XCTAssertEqual(result.zones[0].limit, 50)
        XCTAssertEqual(result.zones[0].name, "MAIN NORTH ROAD")
        XCTAssertTrue(result.zones[0].contains(Coordinate(latitude: -40.5, longitude: 174.5)))
    }

    /// Shaped like a record from the live layer: the limit is a string, with the zone id alongside.
    func testReadsTheLiveLayersFields() throws {
        let data = collection("""
        {"type":"Feature","properties":{"speedLimitZoneId":"73490856-e594","speedLimitZoneName":"CUBA STREET","speedLimitZoneValue":"10"},
         "geometry":{"type":"Polygon","coordinates":\(square)}}
        """)
        let zone = try XCTUnwrap(GeoJSONZoneParser.parse(data).zones.first)
        XCTAssertEqual(zone.limit, 10)
        XCTAssertEqual(zone.id, "73490856-e594")
        XCTAssertEqual(zone.name, "CUBA STREET")
    }

    func testLimitKeyIsCaseAndPunctuationInsensitive() throws {
        for key in ["SPEED_LIMIT", "SpeedLimit", "speed-limit"] {
            let data = collection("""
            {"type":"Feature","properties":{"\(key)":"60 km/h"},"geometry":{"type":"Polygon","coordinates":\(square)}}
            """)
            XCTAssertEqual(try GeoJSONZoneParser.parse(data).zones.first?.limit, 60, key)
        }
    }

    func testMultiPolygonAndHoles() throws {
        let hole = "[[174.4,-40.6],[174.6,-40.6],[174.6,-40.4],[174.4,-40.4],[174.4,-40.6]]"
        let data = collection("""
        {"type":"Feature","properties":{"speedLimit":30},
         "geometry":{"type":"MultiPolygon","coordinates":[[\(String(square.dropFirst().dropLast())),\(hole)],[[[176,-41],[177,-41],[177,-40],[176,-40],[176,-41]]]]}}
        """)
        let zone = try XCTUnwrap(GeoJSONZoneParser.parse(data).zones.first)
        XCTAssertEqual(zone.polygons.count, 2)
        XCTAssertTrue(zone.contains(Coordinate(latitude: -40.9, longitude: 174.1)))
        XCTAssertFalse(zone.contains(Coordinate(latitude: -40.5, longitude: 174.5)))
        XCTAssertTrue(zone.contains(Coordinate(latitude: -40.5, longitude: 176.5)))
    }

    func testFeaturesWithoutALimitAreCountedNotInvented() throws {
        let data = collection("""
        {"type":"Feature","properties":{"speedLimitZoneName":"ACACIA BAY ROAD"},
         "geometry":{"type":"Polygon","coordinates":\(square)}}
        """, exceeded: true)
        let result = try GeoJSONZoneParser.parse(data)
        XCTAssertTrue(result.zones.isEmpty)
        XCTAssertEqual(result.featureCount, 1)
        XCTAssertEqual(result.skippedWithoutLimit, 1)
        XCTAssertTrue(result.exceededTransferLimit)
    }

    func testImplausibleLimitsAreRejected() throws {
        for value in ["0", "7", "150", "49.5", "\"fast\""] {
            let data = collection("""
            {"type":"Feature","properties":{"speedLimit":\(value)},"geometry":{"type":"Polygon","coordinates":\(square)}}
            """)
            XCTAssertEqual(try GeoJSONZoneParser.parse(data).skippedWithoutLimit, 1, value)
        }
    }

    func testBadGeometryIsCounted() throws {
        let data = collection("""
        {"type":"Feature","properties":{"speedLimit":50},"geometry":{"type":"Point","coordinates":[174,-41]}},
        {"type":"Feature","properties":{"speedLimit":50},"geometry":null}
        """)
        XCTAssertEqual(try GeoJSONZoneParser.parse(data).skippedBadGeometry, 2)
    }

    func testNotGeoJSONThrows() {
        XCTAssertThrowsError(try GeoJSONZoneParser.parse(Data("[]".utf8)))
        XCTAssertThrowsError(try GeoJSONZoneParser.parse(Data("nope".utf8)))
    }
}
