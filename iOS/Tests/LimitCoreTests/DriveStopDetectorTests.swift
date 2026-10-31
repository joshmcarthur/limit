import XCTest
@testable import LimitCore

final class DriveStopDetectorTests: XCTestCase {
    private let t0 = Date(timeIntervalSince1970: 1_000_000)
    private func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    func testNothingHappensWhileDriving() {
        var d = DriveStopDetector()
        d.observe(.driving, at: at(0))
        d.observe(speedKmh: 60, at: at(0))
        XCTAssertEqual(d.evaluate(at: at(3_600)), .none)
    }

    func testWalkingForAMinutePingsOnce() {
        var d = DriveStopDetector()
        d.observe(.driving, at: at(0))
        d.observe(.onFoot, at: at(100))
        d.observe(speedKmh: 4, at: at(100))
        XCTAssertEqual(d.evaluate(at: at(159)), .none, "a brief stop on foot isn't the end of a drive")
        XCTAssertEqual(d.evaluate(at: at(160)), .ping)
        XCTAssertEqual(d.evaluate(at: at(170)), .none, "only one ping")
    }

    func testSittingBackInTheCarBeforeTheMinuteCancelsIt() {
        var d = DriveStopDetector()
        d.observe(.onFoot, at: at(0))
        d.observe(.driving, at: at(30))
        XCTAssertEqual(d.evaluate(at: at(200)), .none)
    }

    func testAStoppedCarReadingAsOtherDoesNothing() {
        var d = DriveStopDetector()
        d.observe(.driving, at: at(0))
        d.observe(.other, at: at(10))
        d.observe(speedKmh: 4, at: at(10))
        XCTAssertEqual(d.evaluate(at: at(400)), .none, "a long red light isn't a stop")
    }

    func testStillOnFootAfterOtherStillCounts() {
        var d = DriveStopDetector()
        d.observe(.onFoot, at: at(0))
        d.observe(.other, at: at(20))
        XCTAssertEqual(d.evaluate(at: at(60)), .ping, "sitting down after the walk doesn't undo leaving the car")
    }

    func testAnUnansweredPingEndsTheDriveAfterTenMinutes() {
        var d = DriveStopDetector()
        d.observe(.onFoot, at: at(0))
        XCTAssertEqual(d.evaluate(at: at(60)), .ping)
        XCTAssertEqual(d.evaluate(at: at(60 + 599)), .none)
        XCTAssertEqual(d.evaluate(at: at(60 + 600)), .end)
    }

    func testKeepDrivingStopsTheEndAndFurtherPings() {
        var d = DriveStopDetector()
        d.observe(.onFoot, at: at(0))
        XCTAssertEqual(d.evaluate(at: at(60)), .ping)
        d.keepDriving(at: at(100))
        d.observe(speedKmh: 30, at: at(101))
        XCTAssertEqual(d.evaluate(at: at(1_000)), .none)
        d.observe(.onFoot, at: at(1_000))
        XCTAssertEqual(d.evaluate(at: at(1_100)), .none, "no nagging until driving is seen again")
        d.observe(.driving, at: at(1_200))
        d.observe(.onFoot, at: at(1_300))
        XCTAssertEqual(d.evaluate(at: at(1_360)), .ping)
    }

    func testFifteenMinutesStillEndsTheDriveWithNoMotionData() {
        var d = DriveStopDetector()
        d.observe(speedKmh: 0, at: at(0))
        d.observe(speedKmh: 1, at: at(500))
        XCTAssertEqual(d.evaluate(at: at(899)), .none)
        XCTAssertEqual(d.evaluate(at: at(900)), .end)
    }

    func testMovingResetsTheIdleClock() {
        var d = DriveStopDetector()
        d.observe(speedKmh: 0, at: at(0))
        d.observe(speedKmh: 25, at: at(800))
        d.observe(speedKmh: 0, at: at(801))
        XCTAssertEqual(d.evaluate(at: at(1_500)), .none)
        XCTAssertEqual(d.evaluate(at: at(801 + 900)), .end)
    }

    func testNoGPSSpeedCountsAsNotMoving() {
        var d = DriveStopDetector()
        d.observe(speedKmh: nil, at: at(0))
        XCTAssertEqual(d.evaluate(at: at(900)), .end)
    }

    func testKeepDrivingGivesAnotherFifteenMinutesOfStillness() {
        var d = DriveStopDetector()
        d.observe(speedKmh: 0, at: at(0))
        d.keepDriving(at: at(800))
        d.observe(speedKmh: 0, at: at(801))
        XCTAssertEqual(d.evaluate(at: at(1_500)), .none)
        XCTAssertEqual(d.evaluate(at: at(800 + 900)), .end)
    }
}
