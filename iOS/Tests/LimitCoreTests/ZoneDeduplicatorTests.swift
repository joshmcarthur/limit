import XCTest
@testable import LimitCore

final class ZoneDeduplicatorTests: XCTestCase {
    private func zone(id: String?, limit: Int = 50, lat: Double = -41) -> SpeedZone {
        let ring = Ring(points: [
            Coordinate(latitude: lat, longitude: 174), Coordinate(latitude: lat, longitude: 174.1),
            Coordinate(latitude: lat + 0.1, longitude: 174.1), Coordinate(latitude: lat + 0.1, longitude: 174),
        ])!
        return SpeedZone(id: id, name: nil, limit: limit, polygons: [Polygon(outer: ring)])!
    }

    func testRepeatedRecordsCollapse() {
        let zones = [zone(id: "a"), zone(id: "a"), zone(id: "a"), zone(id: "b", lat: -42)]
        XCTAssertEqual(ZoneDeduplicator.unique(zones).map(\.id), ["a", "b"])
    }

    func testSameIdWithDifferentShapeIsKept() {
        let zones = [zone(id: "a", lat: -41), zone(id: "a", lat: -43)]
        XCTAssertEqual(ZoneDeduplicator.unique(zones).count, 2)
    }

    func testSameIdAndShapeWithDifferentLimitIsKept() {
        XCTAssertEqual(ZoneDeduplicator.unique([zone(id: "a", limit: 50), zone(id: "a", limit: 30)]).count, 2)
    }

    func testZonesWithoutAnIdAreNeverDropped() {
        XCTAssertEqual(ZoneDeduplicator.unique([zone(id: nil), zone(id: nil)]).count, 2)
    }

    func testOrderIsPreserved() {
        let zones = [zone(id: "b", lat: -42), zone(id: "a"), zone(id: "b", lat: -42)]
        XCTAssertEqual(ZoneDeduplicator.unique(zones).map(\.id), ["b", "a"])
    }
}
