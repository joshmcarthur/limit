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
