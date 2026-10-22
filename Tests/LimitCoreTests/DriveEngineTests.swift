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
