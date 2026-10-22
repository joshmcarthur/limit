import XCTest
@testable import LimitCore

final class DriveEngineTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_800_000_000)
    private let inside = Coordinate(latitude: -41.0, longitude: 174.0)

    private func engine(limit: Int = 50, checkedAgo: TimeInterval = 3_600, tolerance: Int = 3) -> DriveEngine {
        let ring = Ring(points: [
            Coordinate(latitude: -41.1, longitude: 173.9), Coordinate(latitude: -41.1, longitude: 174.1),
            Coordinate(latitude: -40.9, longitude: 174.1), Coordinate(latitude: -40.9, longitude: 173.9),
        ])!
        let zone = SpeedZone(name: "GLOUCESTER STREET", limit: limit, polygons: [Polygon(outer: ring)])!
        return DriveEngine(register: SpeedLimitRegister(zones: [zone]),
                           registerCheckedAt: now.addingTimeInterval(-checkedAgo), tolerance: tolerance)
    }

    private func sample(kmh: Double, accuracy: Double = 5, at: Coordinate? = nil, age: TimeInterval = 0) -> LocationSample {
        LocationSample(coordinate: at ?? inside, speedMetresPerSecond: kmh / 3.6,
                       horizontalAccuracy: accuracy, timestamp: now.addingTimeInterval(-age))
    }

    func testNormalDriving() {
        var e = engine()
        let state = e.ingest(sample(kmh: 47), now: now)
        XCTAssertEqual(state.gps, .good)
        XCTAssertEqual(state.snapshot.limit, 50)
        XCTAssertEqual(state.snapshot.speed, 47)
        XCTAssertEqual(state.snapshot.roadName, "Gloucester Street")
        XCTAssertNil(state.snapshot.overBy)
        XCTAssertEqual(state.snapshot.sign, .limit(50, isStale: false))
    }

    func testOverTheLimit() {
        var e = engine(limit: 30)
        let state = e.ingest(sample(kmh: 38), now: now)
        XCTAssertEqual(state.snapshot.overBy, 8)
        XCTAssertEqual(state.snapshot.over, .over(by: 8))
    }

    func testOffTheRegisterShowsUnknownLimitButKeepsSpeed() {
        var e = engine()
        let state = e.ingest(sample(kmh: 60, at: Coordinate(latitude: -35, longitude: 174)), now: now)
        XCTAssertEqual(state.snapshot.sign, .unknown)
        XCTAssertNil(state.snapshot.roadName)
        XCTAssertEqual(state.snapshot.speed, 60)
        XCTAssertNil(state.snapshot.overBy)
    }

    func testStaleSampleIsLostNotFrozen() {
        var e = engine()
        _ = e.ingest(sample(kmh: 47), now: now)
        XCTAssertEqual(e.state(now: now.addingTimeInterval(6)), .searching)
    }

    func testPoorAccuracyIsTreatedAsNoFix() {
        var e = engine()
        XCTAssertEqual(e.ingest(sample(kmh: 47, accuracy: 500), now: now), .searching)
        XCTAssertEqual(e.ingest(sample(kmh: 47, accuracy: -1), now: now), .searching)
    }

    func testWeakButUsableAccuracy() {
        var e = engine()
        let state = e.ingest(sample(kmh: 47, accuracy: 60), now: now)
        XCTAssertEqual(state.gps, .weak)
        XCTAssertEqual(state.snapshot.limit, 50)
    }

    func testInvalidSpeedShowsDashButLimit() {
        var e = engine()
        let bad = LocationSample(coordinate: inside, speedMetresPerSecond: -1, horizontalAccuracy: 5, timestamp: now)
        let state = e.ingest(bad, now: now)
        XCTAssertNil(state.snapshot.speed)
        XCTAssertEqual(state.snapshot.limit, 50)
    }

    func testStaleRegisterBadgesAndOldRegisterHidesLimit() {
        var stale = engine(checkedAgo: 40 * 86_400)
        XCTAssertEqual(stale.ingest(sample(kmh: 47), now: now).snapshot.sign, .limit(50, isStale: true))
        var old = engine(checkedAgo: 400 * 86_400)
        XCTAssertEqual(old.ingest(sample(kmh: 47), now: now).snapshot.sign, .unknown)
    }

    func testNeverCheckedRegisterIsUnknown() {
        var e = engine()
        e.registerCheckedAt = nil
        XCTAssertEqual(e.ingest(sample(kmh: 47), now: now).snapshot.sign, .unknown)
    }

    func testOverStateClearsWhenFixIsLost() {
        var e = engine(limit: 30)
        XCTAssertTrue(e.ingest(sample(kmh: 40), now: now).snapshot.over.isOver)
        _ = e.state(now: now.addingTimeInterval(10))
        // 32 km/h is inside the tolerance band; it only stays "over" if the state wasn't reset.
        XCTAssertFalse(e.ingest(sample(kmh: 32, age: -10), now: now.addingTimeInterval(10)).snapshot.over.isOver)
    }
}

final class ZoneChangeConfirmationTests: XCTestCase {
    private func box(_ limit: Int, lon: Double) -> SpeedZone {
        let ring = Ring(points: [
            Coordinate(latitude: -41, longitude: lon), Coordinate(latitude: -41, longitude: lon + 1),
            Coordinate(latitude: -40, longitude: lon + 1), Coordinate(latitude: -40, longitude: lon),
        ])!
        return SpeedZone(name: "Z\(limit)", limit: limit, polygons: [Polygon(outer: ring)])!
    }

    private let west = Coordinate(latitude: -40.5, longitude: 174.5)
    private let east = Coordinate(latitude: -40.5, longitude: 175.5)
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func engine() -> DriveEngine {
        DriveEngine(register: SpeedLimitRegister(zones: [box(50, lon: 174), box(100, lon: 175)]), registerCheckedAt: now)
    }

    private func limit(_ e: inout DriveEngine, _ at: Coordinate, second: Double, accuracy: Double = 5) -> Int? {
        let t = now.addingTimeInterval(second)
        return e.ingest(LocationSample(coordinate: at, speedMetresPerSecond: 10, horizontalAccuracy: accuracy, timestamp: t), now: t).snapshot.limit
    }

    func testAZoneIsShownAtOnceWhenNothingWasShownBefore() {
        var e = engine()
        XCTAssertEqual(limit(&e, west, second: 0), 50)
    }

    func testOneStrayFixDoesNotChangeTheLimit() {
        var e = engine()
        _ = limit(&e, west, second: 0)
        XCTAssertEqual(limit(&e, east, second: 1), 50, "a single fix in the next zone")
        XCTAssertEqual(limit(&e, west, second: 2), 50)
        XCTAssertEqual(limit(&e, east, second: 3), 50, "the count restarted")
    }

    func testTwoFixesInARowChangeIt() {
        var e = engine()
        _ = limit(&e, west, second: 0)
        _ = limit(&e, east, second: 1)
        XCTAssertEqual(limit(&e, east, second: 2), 100)
    }

    func testTheConfirmationCountCanBeChanged() {
        var e = engine()
        e.zoneChangeConfirmations = 1
        _ = limit(&e, west, second: 0)
        XCTAssertEqual(limit(&e, east, second: 1), 100)
    }

    func testALostFixForgetsTheZone() {
        var e = engine()
        _ = limit(&e, west, second: 0)
        XCTAssertNil(limit(&e, west, second: 1, accuracy: 500), "position too poor")
        XCTAssertEqual(limit(&e, east, second: 2), 100, "taken at once after a gap")
    }
}
