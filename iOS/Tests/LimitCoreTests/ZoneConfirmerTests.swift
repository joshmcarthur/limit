import XCTest
@testable import LimitCore

final class ZoneConfirmerTests: XCTestCase {
    private let a = SpeedLimitMatch(limit: 50, zoneName: "A")
    private let b = SpeedLimitMatch(limit: 70, zoneName: "B")
    private let c = SpeedLimitMatch(limit: 100, zoneName: "C")

    func testTheFirstMatchIsTakenAtOnce() {
        var zone = ZoneConfirmer()
        zone.observe(a, confirmations: 3)
        XCTAssertEqual(zone.current, a)
    }

    func testADifferentZoneNeedsEnoughSamplesInARow() {
        var zone = ZoneConfirmer()
        zone.observe(a, confirmations: 2)
        zone.observe(b, confirmations: 2)
        XCTAssertEqual(zone.current, a, "one stray fix changes nothing")
        zone.observe(b, confirmations: 2)
        XCTAssertEqual(zone.current, b)
    }

    func testAnInterruptedRunStartsAgain() {
        var zone = ZoneConfirmer()
        zone.observe(a, confirmations: 2)
        zone.observe(b, confirmations: 2)
        zone.observe(a, confirmations: 2)   // back to the current zone: the candidate is forgotten
        zone.observe(b, confirmations: 2)
        XCTAssertEqual(zone.current, a)
        zone.observe(c, confirmations: 2)   // a different candidate restarts the count
        zone.observe(b, confirmations: 2)
        XCTAssertEqual(zone.current, a)
    }

    func testLeavingTheRegisterIsAlsoAChangeThatNeedsConfirming() {
        var zone = ZoneConfirmer()
        zone.observe(a, confirmations: 2)
        zone.observe(nil, confirmations: 2)
        XCTAssertEqual(zone.current, a)
        zone.observe(nil, confirmations: 2)
        XCTAssertNil(zone.current)
    }

    func testFewerThanOneConfirmationStillNeedsOne() {
        var zone = ZoneConfirmer()
        zone.observe(a, confirmations: 0)
        zone.observe(b, confirmations: 0)
        XCTAssertEqual(zone.current, b)
    }

    func testResetForgetsTheZoneAndTheCandidate() {
        var zone = ZoneConfirmer()
        zone.observe(a, confirmations: 2)
        zone.observe(b, confirmations: 2)
        zone.reset()
        XCTAssertNil(zone.current)
        zone.observe(c, confirmations: 2)
        XCTAssertEqual(zone.current, c, "taken at once, and the old candidate doesn't count")
    }
}
