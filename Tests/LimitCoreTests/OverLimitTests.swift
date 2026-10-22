import XCTest
@testable import LimitCore

final class OverLimitTests: XCTestCase {
    func testTriggersAtTolerance() {
        var e = OverLimitEvaluator(tolerance: 3)
        XCTAssertEqual(e.evaluate(speed: 52, limit: 50), .notOver)
        XCTAssertEqual(e.evaluate(speed: 53, limit: 50), .over(by: 3))
    }

    func testReportsDeltaLikeTheDesign() {
        var e = OverLimitEvaluator(tolerance: 3)
        XCTAssertEqual(e.evaluate(speed: 38, limit: 30), .over(by: 8))
    }

    func testHysteresisKeepsOverUntilBelowClearThreshold() {
        var e = OverLimitEvaluator(tolerance: 3)
        _ = e.evaluate(speed: 54, limit: 50)
        XCTAssertTrue(e.evaluate(speed: 52, limit: 50).isOver)   // inside the band
        XCTAssertEqual(e.evaluate(speed: 51, limit: 50), .notOver) // delta 1 <= clearAt 1
        XCTAssertEqual(e.evaluate(speed: 52, limit: 50), .notOver) // needs 3 to re-trigger
    }

    func testMissingInputsClear() {
        var e = OverLimitEvaluator(tolerance: 3)
        _ = e.evaluate(speed: 60, limit: 50)
        XCTAssertEqual(e.evaluate(speed: nil, limit: 50), .notOver)
        XCTAssertEqual(e.evaluate(speed: 52, limit: 50), .notOver)
        _ = e.evaluate(speed: 60, limit: 50)
        XCTAssertEqual(e.evaluate(speed: 60, limit: nil), .notOver)
    }

    func testToleranceIsClamped() {
        XCTAssertEqual(OverLimitEvaluator(tolerance: 0).tolerance, 1)
        XCTAssertEqual(OverLimitEvaluator(tolerance: 99).tolerance, 10)
    }

    func testToleranceOneClearsAtLimit() {
        var e = OverLimitEvaluator(tolerance: 1)
        XCTAssertEqual(e.evaluate(speed: 51, limit: 50), .over(by: 1))
        XCTAssertEqual(e.evaluate(speed: 50, limit: 50), .notOver)
    }
}
