import XCTest
@testable import LimitCore

/// Records shaped like the live layer's seasonal, emergency, structure and ended records.
final class ZoneAttributesTests: XCTestCase {
    private let square = "[[[174,-41],[175,-41],[175,-40],[174,-40],[174,-41]]]"

    private func zone(_ properties: String) throws -> SpeedZone {
        let data = Data("""
        {"type":"FeatureCollection","features":[{"type":"Feature","properties":{\(properties)},
        "geometry":{"type":"Polygon","coordinates":\(square)}}]}
        """.utf8)
        return try XCTUnwrap(GeoJSONZoneParser.parse(data).zones.first)
    }

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    func testASeasonalRecurringRecord() throws {
        // Lake Brunner Motor Camp: 1 December 2021 to 30 April 2022, recurring.
        let z = try zone("""
        "speedLimitZoneValue":"30","speedCategoryName":"Seasonal","speedLimitZoneSeasonalRecur":1,
        "speedLimitZoneStartDate":1638320400000,"speedLimitZoneEndDate":1651276800000
        """)
        XCTAssertEqual(z.kind, .seasonal)
        XCTAssertEqual(z.period?.repeatsYearly, true)
        XCTAssertTrue(z.isActive(at: date("2026-12-20T00:00:00+13:00")), "in season, years later")
        XCTAssertFalse(z.isActive(at: date("2026-07-01T00:00:00+12:00")), "out of season")
    }

    func testAnEmergencyRecordThatHasEnded() throws {
        // Tararu Road diversion limit: 18 August 2023 to 17 August 2024. The register calls it "Temporary".
        let z = try zone("""
        "speedLimitZoneValue":"50","speedCategoryName":"Temporary",
        "speedLimitZoneStartDate":1692316800000,"speedLimitZoneEndDate":1723852800000
        """)
        XCTAssertEqual(z.kind, .emergency)
        XCTAssertEqual(z.period?.repeatsYearly, false)
        XCTAssertTrue(z.isActive(at: date("2024-01-10T12:00:00+13:00")))
        XCTAssertFalse(z.isActive(at: date("2026-10-22T12:00:00+13:00")), "long over, but still in the register")
    }

    func testAnEndedPermanentRecordIsNotActive() throws {
        // Default speed limit 100, "ended" 10 June 2025 but never marked ineffective; start is the 1899 placeholder.
        let z = try zone("""
        "speedLimitZoneValue":"100","speedCategoryName":"Permanent",
        "speedLimitZoneStartDate":-2209161600000,"speedLimitZoneEndDate":1749513600000
        """)
        XCTAssertEqual(z.kind, .permanent)
        XCTAssertNil(z.period?.start, "placeholder start dropped")
        XCTAssertTrue(z.isActive(at: date("2025-01-01T12:00:00+13:00")))
        XCTAssertFalse(z.isActive(at: date("2026-10-22T12:00:00+13:00")))
    }

    func testAPermanentRecordWithOnlyAPlaceholderStartHasNoPeriod() throws {
        let z = try zone("""
        "speedLimitZoneValue":"50","speedCategoryName":"Permanent","speedLimitZoneStartDate":-2208985200000,
        "speedLimitZoneStructureTypeName":"Overpass"
        """)
        XCTAssertNil(z.period)
        XCTAssertEqual(z.structure, .overpass)
        XCTAssertTrue(z.isActive(at: Date()))
    }

    func testRecurOnANonSeasonalRecordDoesNotRepeat() throws {
        let z = try zone("""
        "speedLimitZoneValue":"50","speedCategoryName":"Permanent","speedLimitZoneSeasonalRecur":1,
        "speedLimitZoneStartDate":1638320400000,"speedLimitZoneEndDate":1651276800000
        """)
        XCTAssertEqual(z.period?.repeatsYearly, false)
    }

    func testRecordsWithNoCategoryOrDatesAreAlwaysActivePermanentZones() throws {
        let z = try zone("\"speedLimitZoneValue\":\"60\"")
        XCTAssertEqual(z.kind, .permanent)
        XCTAssertEqual(z.structure, StructureType.none)
        XCTAssertNil(z.period)
    }

    func testDatesThatAreNotNumbersAreIgnored() throws {
        let z = try zone("\"speedLimitZoneValue\":\"60\",\"speedLimitZoneEndDate\":\"soon\",\"speedLimitZoneStartDate\":null")
        XCTAssertNil(z.period)
    }

    // MARK: Storage

    private func ring() -> Ring {
        Ring(points: [
            Coordinate(latitude: -41, longitude: 174), Coordinate(latitude: -41, longitude: 175),
            Coordinate(latitude: -40, longitude: 175), Coordinate(latitude: -40, longitude: 174),
        ])!
    }

    func testTheStoreKeepsKindStructureAndPeriod() throws {
        let nz = ReducedLimit.timeZone
        var calendar = Calendar(identifier: .gregorian); calendar.timeZone = nz
        let start = calendar.date(from: DateComponents(year: 2021, month: 12, day: 1, hour: 14))!
        let end = calendar.date(from: DateComponents(year: 2022, month: 4, day: 30, hour: 12))!
        let zones = [
            SpeedZone(name: "SEASONAL", limit: 30, kind: .seasonal,
                      period: ActivePeriod(start: start, end: end, repeatsYearly: true), polygons: [Polygon(outer: ring())])!,
            SpeedZone(name: "EMERGENCY", limit: 50, kind: .emergency,
                      period: ActivePeriod(start: start, end: end), polygons: [Polygon(outer: ring())])!,
            SpeedZone(name: "OPEN END", limit: 50, structure: .underpass,
                      period: ActivePeriod(start: start, end: nil), polygons: [Polygon(outer: ring())])!,
            SpeedZone(name: "NO END", limit: 50, structure: .intersection,
                      period: ActivePeriod(start: nil, end: end), polygons: [Polygon(outer: ring())])!,
            SpeedZone(name: "PLAIN", limit: 100, polygons: [Polygon(outer: ring())])!,
        ]
        let decoded = try ZoneCodec.decode(ZoneCodec.encode(zones))
        XCTAssertEqual(decoded.map(\.kind), zones.map(\.kind))
        XCTAssertEqual(decoded.map(\.structure), zones.map(\.structure))
        XCTAssertEqual(decoded.map(\.period), zones.map(\.period))
    }

    func testAnOldFormatCopyIsRejected() {
        var old = ZoneCodec.encode([])
        old[4] = 2
        XCTAssertThrowsError(try ZoneCodec.decode(old)) { XCTAssertEqual($0 as? ZoneCodecError, .unsupportedVersion(2)) }
    }

    func testAnImpossibleKindOrFlagIsInvalid() throws {
        let z = SpeedZone(name: nil, limit: 50, polygons: [Polygon(outer: ring())])!
        let bytes = [UInt8](ZoneCodec.encode([z]))
        // header 4 + version 1 + count 4; then limit, reduced, kind, structure, flags.
        var badKind = bytes; badKind[9 + 2] = 9
        XCTAssertThrowsError(try ZoneCodec.decode(Data(badKind))) { XCTAssertEqual($0 as? ZoneCodecError, .invalid) }
        var badFlags = bytes; badFlags[9 + 4] = 0x80
        XCTAssertThrowsError(try ZoneCodec.decode(Data(badFlags))) { XCTAssertEqual($0 as? ZoneCodecError, .invalid) }
    }

    func testAPackedDayThatIsNotADateIsInvalid() throws {
        let start = Date(timeIntervalSince1970: 1_700_000_000)
        let z = SpeedZone(name: nil, limit: 50, period: ActivePeriod(start: start, end: nil), polygons: [Polygon(outer: ring())])!
        var bytes = [UInt8](ZoneCodec.encode([z]))
        // flags at 9+4, packed start follows: make it 20231399 (month 13).
        let bad = Int32(20_231_399)
        withUnsafeBytes(of: bad.littleEndian) { for (i, b) in $0.enumerated() { bytes[9 + 5 + i] = b } }
        XCTAssertThrowsError(try ZoneCodec.decode(Data(bytes))) { XCTAssertEqual($0 as? ZoneCodecError, .invalid) }
    }

    // MARK: De-duplication

    func testRecordsThatDifferOnlyInDatesAreNotRepeats() throws {
        func record(_ end: Int) throws -> SpeedZone {
            try zone("\"speedLimitZoneId\":\"a\",\"speedLimitZoneValue\":\"70\",\"speedCategoryName\":\"Seasonal\",\"speedLimitZoneSeasonalRecur\":1,\"speedLimitZoneStartDate\":1638320400000,\"speedLimitZoneEndDate\":\(end)")
        }
        let a = try record(1651276800000), b = try record(1651276800000), c = try record(1682812800000)
        XCTAssertEqual(ZoneDeduplicator.unique([a, b, c]).count, 2, "the same record repeated is dropped, a different date is kept")
    }
}
