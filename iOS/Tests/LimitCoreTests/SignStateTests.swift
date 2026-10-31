import XCTest
@testable import LimitCore

final class SignStateTests: XCTestCase {
    private let day: TimeInterval = 86_400

    func testFreshLimit() {
        XCTAssertEqual(SignState.make(limit: 50, dataAge: day), .limit(50, isStale: false))
    }

    func testStaleLimitStillShows() {
        XCTAssertEqual(SignState.make(limit: 50, dataAge: 31 * day), .limit(50, isStale: true))
    }

    func testTooOldIsUnknown() {
        XCTAssertEqual(SignState.make(limit: 50, dataAge: 200 * day), .unknown)
    }

    func testNoLimitOrNoDataIsUnknown() {
        XCTAssertEqual(SignState.make(limit: nil, dataAge: day), .unknown)
        XCTAssertEqual(SignState.make(limit: 50, dataAge: nil), .unknown)
    }

    func testDefaultAreaIsOpenRoadNotAHundred() {
        XCTAssertEqual(SignState.make(limit: 100, dataAge: day, isDefaultArea: true), .openRoad(isStale: false))
        XCTAssertEqual(SignState.make(limit: 100, dataAge: 31 * day, isDefaultArea: true), .openRoad(isStale: true))
        XCTAssertEqual(SignState.make(limit: 100, dataAge: 200 * day, isDefaultArea: true), .unknown, "too old to trust either way")
        XCTAssertEqual(SignState.make(limit: 100, dataAge: day), .limit(100, isStale: false), "a real 100 zone still shows 100")
        XCTAssertNil(SignState.openRoad(isStale: false).limit)
    }

    func testBoundaries() {
        let p = FreshnessPolicy(staleAfter: 10, unknownAfter: 20)
        XCTAssertEqual(p.level(forAge: 9.9), .fresh)
        XCTAssertEqual(p.level(forAge: 10), .stale)
        XCTAssertEqual(p.level(forAge: 20), .tooOld)
    }

    func testMetricsMatchGuidelines() {
        XCTAssertEqual(SignMetrics.ringWidth(diameter: 220), 24.2, accuracy: 1e-9)
        XCTAssertEqual(SignMetrics.numeralSize(diameter: 200, limit: 50), 84, accuracy: 1e-9)
        XCTAssertEqual(SignMetrics.numeralSize(diameter: 200, limit: 100), 72, accuracy: 1e-9)
        XCTAssertTrue(SignMetrics.showsStaleBadge(diameter: 72))
        XCTAssertFalse(SignMetrics.showsStaleBadge(diameter: 24))
    }
}

final class DefaultAreaNameTests: XCTestCase {
    /// The register's catch-all records, as they are named in the live layer (October 2026). Detection is
    /// by name, so a rename at the source would quietly bring the 100 back; this pins what we expect.
    func testDefaultRecordsAreRecognised() {
        for name in ["DEFAULT SPEED LIMIT", "Default Speed Limit", "DEFAULT SPEED LIMIT- INTERSECTION 2"] {
            XCTAssertTrue(SpeedLimitMatch(limit: 100, zoneName: name).isDefaultArea, name)
        }
    }

    func testOrdinaryZonesAreNot() {
        for name in ["PORIRUA CITY UTA", "STATE HIGHWAY 1", "CLYDE-CLYDE LOOKOUT ROAD-DEFAULT LIMIT TO SUNDERLAND STREET", nil] {
            XCTAssertFalse(SpeedLimitMatch(limit: 100, zoneName: name).isDefaultArea, name ?? "nil")
        }
    }
}
