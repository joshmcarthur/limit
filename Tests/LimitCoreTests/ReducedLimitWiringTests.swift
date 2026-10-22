import XCTest
@testable import LimitCore

/// A school zone end to end: parsed from a feature, stored, and looked up by time of day.
final class ReducedLimitWiringTests: XCTestCase {
    private let square = "[[[174,-41],[175,-41],[175,-40],[174,-40],[174,-41]]]"
    private let inside = Coordinate(latitude: -40.5, longitude: 174.5)

    private func feature(value: String = "50", variable: String?, periods: String?) -> Data {
        let extra = [variable.map { "\"speedLimitZoneVariableSpeed\":\"\($0)\"" },
                     periods.map { "\"speedLimitZoneVarPrdDesc\":\"\($0)\"" }]
            .compactMap { $0 }.joined(separator: ",")
        return Data("""
        {"type":"FeatureCollection","features":[{"type":"Feature",
        "properties":{"speedLimitZoneValue":"\(value)"\(extra.isEmpty ? "" : "," + extra)},
        "geometry":{"type":"Polygon","coordinates":\(square)}}]}
        """.utf8)
    }

    private func zone(_ data: Data) throws -> SpeedZone {
        try XCTUnwrap(GeoJSONZoneParser.parse(data).zones.first)
    }

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    func testParsesASchoolZone() throws {
        let z = try zone(feature(variable: "40 km/h", periods: "8.30am to 9.15am and 2.45pm to 3.30pm"))
        XCTAssertEqual(z.limit, 50)
        XCTAssertEqual(z.reduced?.limit, 40)
        XCTAssertEqual(z.reduced?.windows.count, 2)
    }

    func testReducedLimitIsIgnoredWhenItCannotBeTrusted() throws {
        XCTAssertNil(try zone(feature(variable: "40 km/h", periods: "35 minutes before the start of school")).reduced, "no clock times")
        XCTAssertNil(try zone(feature(variable: "30 km/h, 40 km/h, 50 km/h", periods: "8.30am to 9.15am")).reduced, "a list of speeds")
        XCTAssertNil(try zone(feature(variable: "60 km/h", periods: "8.30am to 9.15am")).reduced, "not lower than the limit")
        XCTAssertNil(try zone(feature(variable: "", periods: "8.30am to 9.15am")).reduced, "no reduced speed")
        XCTAssertNil(try zone(feature(variable: "40 km/h", periods: nil)).reduced, "no periods")
        XCTAssertEqual(try zone(feature(variable: "40 km/h", periods: "nonsense")).limit, 50, "the permanent limit survives")
    }

    func testLookupFollowsTheClock() throws {
        let z = try zone(feature(variable: "40 km/h", periods: "8.30am to 9.15am and 2.45pm to 3.30pm"))
        let register = SpeedLimitRegister(zones: [z])
        XCTAssertEqual(register.lookup(inside, at: date("2026-10-22T08:45:00+13:00"))?.limit, 40)
        XCTAssertEqual(register.lookup(inside, at: date("2026-10-22T11:00:00+13:00"))?.limit, 50)
        XCTAssertEqual(register.lookup(inside, at: date("2026-10-24T08:45:00+13:00"))?.limit, 50, "Saturday")
    }

    func testSmallerSchoolZoneOverridesTheAreaAroundIt() throws {
        let school = try zone(feature(variable: "40 km/h", periods: "8.30am to 9.15am"))
        let area = SpeedZone(name: nil, limit: 100, polygons: [Polygon(outer: Ring(points: [
            Coordinate(latitude: -45, longitude: 170), Coordinate(latitude: -45, longitude: 178),
            Coordinate(latitude: -38, longitude: 178), Coordinate(latitude: -38, longitude: 170)])!)])!
        let register = SpeedLimitRegister(zones: [area, school])
        XCTAssertEqual(register.lookup(inside, at: date("2026-10-22T08:45:00+13:00"))?.limit, 40)
        XCTAssertEqual(register.lookup(inside, at: date("2026-10-22T12:00:00+13:00"))?.limit, 50)
    }

    func testStorageKeepsTheReducedLimit() throws {
        let z = try zone(feature(variable: "40 km/h", periods: "8.30am to 9.15am and 2.45pm to 3.30pm"))
        let decoded = try XCTUnwrap(ZoneCodec.decode(ZoneCodec.encode([z])).first)
        XCTAssertEqual(decoded.reduced, z.reduced)
        XCTAssertEqual(decoded.limit, 50)
    }

    func testAnOldFormatCopyIsRejectedSoItGetsDownloadedAgain() {
        var old = ZoneCodec.encode([])
        old[4] = 1
        XCTAssertThrowsError(try ZoneCodec.decode(old)) { XCTAssertEqual($0 as? ZoneCodecError, .unsupportedVersion(1)) }
    }

    func testBadWindowsInStorageAreInvalid() throws {
        let z = try zone(feature(variable: "40 km/h", periods: "8.30am to 9.15am"))
        var bytes = [UInt8](ZoneCodec.encode([z]))
        // header 4 + version 1 + count 4, then limit, reduced limit, window count, start u16, end u16.
        let end = 9 + 3 + 2
        bytes[end] = 0; bytes[end + 1] = 0   // end = 0 minutes, before the start
        XCTAssertThrowsError(try ZoneCodec.decode(Data(bytes))) { XCTAssertEqual($0 as? ZoneCodecError, .invalid) }
    }

    func testEngineUsesTheSampleTimeForTheLimit() throws {
        let z = try zone(feature(variable: "40 km/h", periods: "8.30am to 9.15am"))
        var engine = DriveEngine(register: SpeedLimitRegister(zones: [z]), registerCheckedAt: date("2026-10-22T07:00:00+13:00"))
        func limit(at iso: String) -> Int? {
            let now = date(iso)
            return engine.ingest(LocationSample(coordinate: inside, speedMetresPerSecond: 10, horizontalAccuracy: 5, timestamp: now), now: now)
                .snapshot.limit
        }
        XCTAssertEqual(limit(at: "2026-10-22T08:45:00+13:00"), 40)
        XCTAssertEqual(limit(at: "2026-10-22T09:30:00+13:00"), 50)
    }
}
