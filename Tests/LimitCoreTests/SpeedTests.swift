import XCTest
@testable import LimitCore

final class SpeedTests: XCTestCase {
    func testConversion() {
        XCTAssertEqual(Speed.kilometresPerHour(fromMetresPerSecond: 10)!, 36, accuracy: 1e-9)
        XCTAssertEqual(Speed.kilometresPerHour(fromMetresPerSecond: 0)!, 0, accuracy: 1e-9)
    }

    func testInvalidSpeedsAreNil() {
        XCTAssertNil(Speed.kilometresPerHour(fromMetresPerSecond: -1))
        XCTAssertNil(Speed.kilometresPerHour(fromMetresPerSecond: .nan))
        XCTAssertNil(Speed.kilometresPerHour(fromMetresPerSecond: .infinity))
    }

    func testDisplayedRounds() {
        XCTAssertEqual(Speed.displayed(46.5), 47)
        XCTAssertEqual(Speed.displayed(46.49), 46)
        XCTAssertNil(Speed.displayed(nil))
        XCTAssertNil(Speed.displayed(-3))
    }
}
