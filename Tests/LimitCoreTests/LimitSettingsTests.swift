import XCTest
@testable import LimitCore

final class LimitSettingsTests: XCTestCase {
    func testDefaultsMatchOnboardingDesign() {
        let s = LimitSettings()
        XCTAssertTrue(s.showOnLockScreen)
        XCTAssertEqual(s.overTolerance, 3)
        XCTAssertFalse(s.chimeOnLimitChange)
        XCTAssertFalse(s.hasCompletedOnboarding)
        XCTAssertEqual(s.toleranceLabel, "+3 km/h")
    }

    func testToleranceStepsAndClamps() {
        var s = LimitSettings()
        for _ in 0..<20 { s.stepTolerance(by: 1) }
        XCTAssertEqual(s.overTolerance, 10)
        XCTAssertFalse(s.canIncreaseTolerance)
        for _ in 0..<20 { s.stepTolerance(by: -1) }
        XCTAssertEqual(s.overTolerance, 1)
        XCTAssertFalse(s.canDecreaseTolerance)
    }

    func testRoundTrip() throws {
        var s = LimitSettings()
        s.overTolerance = 5
        s.chimeOnLimitChange = true
        XCTAssertEqual(LimitSettings.decode(s.encoded()), s)
    }

    func testBadDataGivesDefaults() {
        XCTAssertEqual(LimitSettings.decode(nil), LimitSettings())
        XCTAssertEqual(LimitSettings.decode(Data("garbage".utf8)), LimitSettings())
    }
}
