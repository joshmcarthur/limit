import XCTest
@testable import LimitCore

final class LookupRulesTests: XCTestCase {
    private func nz(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ReducedLimit.timeZone
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }

    private func zone(_ limit: Int, _ name: String, size: Double, kind: ZoneKind = .permanent, structure: StructureType = .none,
                      period: ActivePeriod? = nil) -> SpeedZone {
        SpeedZone(name: name, limit: limit, kind: kind, structure: structure, period: period,
                  polygons: [Polygon(outer: Ring(points: [
                      Coordinate(latitude: -41, longitude: 174), Coordinate(latitude: -41, longitude: 174 + size),
                      Coordinate(latitude: -41 + size, longitude: 174 + size), Coordinate(latitude: -41 + size, longitude: 174)])!)])!
    }

    private let inside = Coordinate(latitude: -40.95, longitude: 174.05)
    private let now = Date(timeIntervalSince1970: 1_792_600_000)  // 22 October 2026

    // MARK: Ended and out-of-season records

    func testAnEndedRecordNeverWins() {
        let ended = ActivePeriod(start: nil, end: nz(2025, 6, 10))
        let register = SpeedLimitRegister(zones: [
            zone(100, "AREA", size: 1),
            zone(60, "ENDED, SMALLER", size: 0.2, period: ended),
        ])
        XCTAssertEqual(register.lookup(inside, at: now)?.limit, 100, "the ended record is more specific but over")
        XCTAssertEqual(register.lookup(inside, at: nz(2025, 1, 1))?.limit, 60, "while it was in force it won")
    }

    func testARecordThatHasntStartedYetIsIgnored() {
        let future = ActivePeriod(start: nz(2027, 1, 1), end: nil)
        let register = SpeedLimitRegister(zones: [zone(100, "AREA", size: 1), zone(60, "LATER", size: 0.2, period: future)])
        XCTAssertEqual(register.lookup(inside, at: now)?.limit, 100)
        XCTAssertEqual(register.lookup(inside, at: nz(2027, 2, 1))?.limit, 60)
    }

    func testNothingActiveMeansNoLimit() {
        let ended = ActivePeriod(start: nil, end: nz(2025, 6, 10))
        XCTAssertNil(SpeedLimitRegister(zones: [zone(60, "OVER", size: 1, period: ended)]).lookup(inside, at: now))
    }

    // MARK: Seasonal and emergency

    private var summer: ActivePeriod { ActivePeriod(start: nz(2021, 12, 1), end: nz(2022, 4, 30), repeatsYearly: true)! }

    func testASeasonalLimitBeatsALargerPermanentOneInSeason() {
        let register = SpeedLimitRegister(zones: [
            zone(100, "ROAD", size: 1),
            zone(30, "MOTOR CAMP", size: 0.2, kind: .seasonal, period: summer),
        ])
        let match = register.lookup(inside, at: nz(2026, 12, 20))
        XCTAssertEqual(match?.limit, 30)
        XCTAssertEqual(match?.kind, .seasonal)
    }

    func testASeasonalLimitBeatsASmallerPermanentOne() {
        // Seasonal overlaps permanent in the register; being in season, it is the one posted.
        let register = SpeedLimitRegister(zones: [
            zone(50, "SMALL PERMANENT", size: 0.1),
            zone(30, "BIG SEASONAL", size: 1, kind: .seasonal, period: summer),
        ])
        XCTAssertEqual(register.lookup(inside, at: nz(2026, 12, 20))?.limit, 30)
    }

    func testOutOfSeasonTheSeasonalLimitIsIgnored() {
        let register = SpeedLimitRegister(zones: [
            zone(100, "ROAD", size: 1),
            zone(30, "MOTOR CAMP", size: 0.2, kind: .seasonal, period: summer),
        ])
        let match = register.lookup(inside, at: nz(2026, 7, 1))
        XCTAssertEqual(match?.limit, 100)
        XCTAssertEqual(match?.kind, .permanent)
    }

    func testAnEmergencyLimitBeatsASeasonalOneWhileItLasts() {
        let emergency = ActivePeriod(start: nz(2026, 12, 15), end: nz(2027, 1, 15))
        let register = SpeedLimitRegister(zones: [
            zone(100, "ROAD", size: 1),
            zone(30, "SEASONAL", size: 0.3, kind: .seasonal, period: summer),
            zone(50, "DIVERSION", size: 0.6, kind: .emergency, period: emergency),
        ])
        XCTAssertEqual(register.lookup(inside, at: nz(2026, 12, 20))?.limit, 50, "emergency over seasonal")
        XCTAssertEqual(register.lookup(inside, at: nz(2026, 12, 1))?.limit, 30, "before the emergency, seasonal")
        XCTAssertEqual(register.lookup(inside, at: nz(2027, 1, 20))?.limit, 30, "after it, seasonal again")
        XCTAssertEqual(register.lookup(inside, at: nz(2027, 6, 1))?.limit, 100)
    }

    func testAnOverEmergencyLimitIsIgnored() {
        let over = ActivePeriod(start: nz(2023, 8, 18), end: nz(2024, 8, 17))
        let register = SpeedLimitRegister(zones: [zone(80, "ROAD", size: 1), zone(50, "DIVERSION", size: 0.2, kind: .emergency, period: over)])
        XCTAssertEqual(register.lookup(inside, at: now)?.limit, 80)
    }

    func testEqualKindsStillUseTheSmallestZone() {
        let register = SpeedLimitRegister(zones: [zone(50, "BIG", size: 1), zone(30, "SMALL", size: 0.2)])
        XCTAssertEqual(register.lookup(inside, at: now)?.zoneName, "SMALL")
    }

    // MARK: Overpass and underpass

    /// A bridge deck and the road under it cover the same ground.
    private func bridge(overpass: Int, underpass: Int) -> SpeedLimitRegister {
        SpeedLimitRegister(zones: [
            zone(100, "AREA", size: 1),
            zone(overpass, "BRIDGE", size: 0.1, structure: .overpass),
            zone(underpass, "ROAD UNDER", size: 0.12, structure: .underpass),
        ])
    }

    func testWithNoPreviousZoneAMismatchedBridgeTakesTheLowerLimit() {
        XCTAssertEqual(bridge(overpass: 80, underpass: 50).lookup(inside, at: now)?.limit, 50)
        XCTAssertEqual(bridge(overpass: 50, underpass: 80).lookup(inside, at: now)?.limit, 50)
    }

    func testYouStayOnTheLevelYouWereOn() throws {
        let register = bridge(overpass: 80, underpass: 50)
        let onBridge = try XCTUnwrap(register.lookup(inside, at: now, preferring: SpeedLimitMatch(limit: 80, zoneName: "BRIDGE", kind: .permanent, zoneID: 1)))
        XCTAssertEqual(onBridge.limit, 80)
        XCTAssertEqual(onBridge.zoneName, "BRIDGE")
        let underneath = try XCTUnwrap(register.lookup(inside, at: now, preferring: SpeedLimitMatch(limit: 50, zoneName: "ROAD UNDER", kind: .permanent, zoneID: 2)))
        XCTAssertEqual(underneath.limit, 50)
    }

    func testAPreviousZoneThatIsntInvolvedDoesNotDecide() {
        let register = bridge(overpass: 80, underpass: 50)
        let unrelated = SpeedLimitMatch(limit: 100, zoneName: "AREA", kind: .permanent, zoneID: 0)
        XCTAssertEqual(register.lookup(inside, at: now, preferring: unrelated)?.limit, 50, "falls back to the lower limit")
    }

    func testMatchingBridgeLimitsAreNotAmbiguous() {
        XCTAssertEqual(bridge(overpass: 50, underpass: 50).lookup(inside, at: now)?.limit, 50)
    }

    func testABridgeWithNoRoadUnderItJustUsesItsOwnLimit() {
        let register = SpeedLimitRegister(zones: [zone(100, "AREA", size: 1), zone(80, "BRIDGE", size: 0.1, structure: .overpass)])
        XCTAssertEqual(register.lookup(inside, at: now)?.limit, 80)
    }

    func testOffTheBridgeNothingSpecialHappens() {
        let away = Coordinate(latitude: -40.2, longitude: 174.8)
        XCTAssertEqual(bridge(overpass: 80, underpass: 50).lookup(away, at: now)?.limit, 100)
    }

    func testIntersectionsAreOrdinaryZones() {
        let register = SpeedLimitRegister(zones: [zone(80, "ROAD", size: 1), zone(50, "JUNCTION", size: 0.1, structure: .intersection)])
        XCTAssertEqual(register.lookup(inside, at: now)?.limit, 50)
    }

    func testMatchesCompareByWhatTheDriverSees() {
        XCTAssertEqual(SpeedLimitMatch(limit: 50, zoneName: "A", kind: .permanent, zoneID: 1),
                       SpeedLimitMatch(limit: 50, zoneName: "A", kind: .permanent, zoneID: 7))
        XCTAssertNotEqual(SpeedLimitMatch(limit: 50, zoneName: "A", kind: .permanent),
                          SpeedLimitMatch(limit: 50, zoneName: "A", kind: .seasonal))
    }

    // MARK: Engine

    private func sample(_ at: Coordinate, _ second: Double) -> (LocationSample, Date) {
        let t = now.addingTimeInterval(second)
        return (LocationSample(coordinate: at, speedMetresPerSecond: 10, horizontalAccuracy: 5, timestamp: t), t)
    }

    /// A road under a bridge, arriving from the road's side, then from the bridge's side.
    func testTheEngineStaysOnTheRoadItArrivedOn() {
        let register = SpeedLimitRegister(zones: [
            SpeedZone(name: "ROAD UNDER", limit: 50, structure: .underpass,
                      polygons: [Polygon(outer: Ring(points: [
                        Coordinate(latitude: -41, longitude: 174), Coordinate(latitude: -41, longitude: 174.3),
                        Coordinate(latitude: -40.9, longitude: 174.3), Coordinate(latitude: -40.9, longitude: 174)])!)])!,
            SpeedZone(name: "BRIDGE", limit: 80, structure: .overpass,
                      polygons: [Polygon(outer: Ring(points: [
                        Coordinate(latitude: -41.2, longitude: 174.1), Coordinate(latitude: -41.2, longitude: 174.2),
                        Coordinate(latitude: -40.7, longitude: 174.2), Coordinate(latitude: -40.7, longitude: 174.1)])!)])!,
        ])
        let roadOnly = Coordinate(latitude: -40.95, longitude: 174.02)
        let bridgeOnly = Coordinate(latitude: -40.75, longitude: 174.15)
        let crossing = Coordinate(latitude: -40.95, longitude: 174.15)
        func limit(from start: Coordinate) -> Int? {
            var engine = DriveEngine(register: register, registerCheckedAt: now)
            var out: Int?
            for (i, point) in [start, start, crossing, crossing, crossing].enumerated() {
                let (s, t) = sample(point, Double(i))
                out = engine.ingest(s, now: t).snapshot.limit
            }
            return out
        }
        XCTAssertEqual(limit(from: roadOnly), 50, "came along the road, stays on it")
        XCTAssertEqual(limit(from: bridgeOnly), 80, "came over the bridge, stays on it")
    }

    func testReplacingTheRegisterForgetsThePreviousZone() {
        var engine = DriveEngine(register: SpeedLimitRegister(zones: [zone(50, "A", size: 1)]), registerCheckedAt: now)
        let (s, t) = sample(inside, 0)
        XCTAssertEqual(engine.ingest(s, now: t).snapshot.limit, 50)
        engine.register = SpeedLimitRegister(zones: [zone(70, "B", size: 1)])
        let (s2, t2) = sample(inside, 1)
        XCTAssertEqual(engine.ingest(s2, now: t2).snapshot.limit, 70, "taken at once, not held for confirmation")
    }
}
