import XCTest
@testable import LimitCore

final class CoverageTests: XCTestCase {
    private func nz(_ lat: Double, _ lon: Double) -> Bool { Coverage.isNewZealand(Coordinate(latitude: lat, longitude: lon)) }

    func testPlacesInNewZealandAreCovered() {
        XCTAssertTrue(nz(-41.2865, 174.7762), "Wellington")
        XCTAssertTrue(nz(-36.8485, 174.7633), "Auckland")
        XCTAssertTrue(nz(-43.5314, 172.6358), "Christchurch")
        XCTAssertTrue(nz(-45.0312, 168.6626), "Queenstown")
        XCTAssertTrue(nz(-46.9, 168.1), "Stewart Island")
        XCTAssertTrue(nz(-34.4, 172.7), "Cape Reinga")
        XCTAssertTrue(nz(-43.95, -176.55), "Chatham Islands, across the date line")
    }

    func testPlacesElsewhereAreNot() {
        XCTAssertFalse(nz(37.3349, -122.0090), "Cupertino")
        XCTAssertFalse(nz(-33.8688, 151.2093), "Sydney")
        XCTAssertFalse(nz(51.5074, -0.1278), "London")
        XCTAssertFalse(nz(-17.7134, 178.065), "Fiji")
        XCTAssertFalse(nz(0, 0), "a bad fix at null island")
    }
}
