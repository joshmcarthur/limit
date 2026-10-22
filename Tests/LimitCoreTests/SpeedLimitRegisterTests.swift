import XCTest
@testable import LimitCore

final class SpeedLimitRegisterTests: XCTestCase {
    private func zone(_ limit: Int, name: String? = nil, lat: Double, lon: Double, size: Double) -> SpeedZone {
        let ring = Ring(points: [
            Coordinate(latitude: lat, longitude: lon),
            Coordinate(latitude: lat, longitude: lon + size),
            Coordinate(latitude: lat + size, longitude: lon + size),
            Coordinate(latitude: lat + size, longitude: lon),
        ])!
        return SpeedZone(name: name, limit: limit, polygons: [Polygon(outer: ring)])!
    }

    func testLookupFindsContainingZone() {
        let register = SpeedLimitRegister(zones: [
            zone(50, name: "A", lat: -41, lon: 174, size: 0.1),
            zone(100, name: "B", lat: -42, lon: 175, size: 0.1),
        ])
        XCTAssertEqual(register.lookup(Coordinate(latitude: -40.95, longitude: 174.05)),
                       SpeedLimitMatch(limit: 50, zoneName: "A"))
        XCTAssertEqual(register.lookup(Coordinate(latitude: -41.95, longitude: 175.05))?.limit, 100)
    }

    func testOffTheRegisterIsNil() {
        let register = SpeedLimitRegister(zones: [zone(50, lat: -41, lon: 174, size: 0.1)])
        XCTAssertNil(register.lookup(Coordinate(latitude: -35, longitude: 174)))
        XCTAssertNil(SpeedLimitRegister.empty.lookup(Coordinate(latitude: -41, longitude: 174)))
    }

    func testSmallestOverlappingZoneWins() {
        let register = SpeedLimitRegister(zones: [
            zone(100, lat: -41, lon: 174, size: 1),
            zone(50, lat: -40.6, lon: 174.4, size: 0.1),
        ])
        XCTAssertEqual(register.lookup(Coordinate(latitude: -40.55, longitude: 174.45))?.limit, 50)
        XCTAssertEqual(register.lookup(Coordinate(latitude: -40.9, longitude: 174.1))?.limit, 100)
    }

    func testEqualOverlapPrefersLowerLimit() {
        let register = SpeedLimitRegister(zones: [
            zone(80, lat: -41, lon: 174, size: 0.1),
            zone(60, lat: -41, lon: 174, size: 0.1),
        ])
        XCTAssertEqual(register.lookup(Coordinate(latitude: -40.95, longitude: 174.05))?.limit, 60)
    }

    func testVeryLargeZoneIsStillFound() {
        // Spans far more cells than the per-zone cap, so it lives in the wide list.
        let register = SpeedLimitRegister(zones: [zone(100, lat: -46, lon: 167, size: 11)])
        XCTAssertEqual(register.lookup(Coordinate(latitude: -40, longitude: 174))?.limit, 100)
    }

    func testZoneAcrossCellBoundary() {
        let register = SpeedLimitRegister(zones: [zone(30, lat: -41.01, lon: 174.01, size: 0.08)], cellSize: 0.05)
        XCTAssertEqual(register.lookup(Coordinate(latitude: -40.95, longitude: 174.09))?.limit, 30)
        XCTAssertEqual(register.zoneCount, 1)
    }
}
