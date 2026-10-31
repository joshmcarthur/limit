import XCTest
@testable import LimitCore

final class GeoTests: XCTestCase {
    private func square(_ lat: Double, _ lon: Double, _ size: Double) -> Ring {
        Ring(points: [
            Coordinate(latitude: lat, longitude: lon),
            Coordinate(latitude: lat, longitude: lon + size),
            Coordinate(latitude: lat + size, longitude: lon + size),
            Coordinate(latitude: lat + size, longitude: lon),
        ])!
    }

    func testRingNeedsThreePoints() {
        XCTAssertNil(Ring(points: [Coordinate(latitude: 0, longitude: 0), Coordinate(latitude: 1, longitude: 1)]))
    }

    func testRingContainment() {
        let ring = square(-41, 174, 1)
        XCTAssertTrue(ring.contains(Coordinate(latitude: -40.5, longitude: 174.5)))
        XCTAssertFalse(ring.contains(Coordinate(latitude: -41.5, longitude: 174.5)))
        XCTAssertFalse(ring.contains(Coordinate(latitude: -40.5, longitude: 175.5)))
    }

    func testClosedRingWithRepeatedFirstPoint() {
        var points = square(-41, 174, 1).points
        points.append(points[0])
        let ring = Ring(points: points)!
        XCTAssertTrue(ring.contains(Coordinate(latitude: -40.5, longitude: 174.5)))
    }

    func testPolygonHoleIsExcluded() {
        let polygon = Polygon(outer: square(-41, 174, 1), holes: [square(-40.75, 174.25, 0.5)])
        XCTAssertTrue(polygon.contains(Coordinate(latitude: -40.9, longitude: 174.1)))
        XCTAssertFalse(polygon.contains(Coordinate(latitude: -40.5, longitude: 174.5)))
    }

    func testConcavePolygon() {
        // An L shape: the notch in the top right is outside.
        let l = Ring(points: [
            Coordinate(latitude: 0, longitude: 0), Coordinate(latitude: 0, longitude: 2),
            Coordinate(latitude: 1, longitude: 2), Coordinate(latitude: 1, longitude: 1),
            Coordinate(latitude: 2, longitude: 1), Coordinate(latitude: 2, longitude: 0),
        ])!
        XCTAssertTrue(l.contains(Coordinate(latitude: 1.5, longitude: 0.5)))
        XCTAssertFalse(l.contains(Coordinate(latitude: 1.5, longitude: 1.5)))
    }

    func testBoundsArea() {
        XCTAssertEqual(square(0, 0, 2).bounds.area, 4, accuracy: 1e-12)
    }
}
