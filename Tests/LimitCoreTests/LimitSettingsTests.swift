import XCTest
@testable import LimitCore

final class LimitSettingsTests: XCTestCase {
    func testDefaultsMatchOnboardingDesign() {
        let s = LimitSettings()
        XCTAssertTrue(s.showOnLockScreen)
        XCTAssertEqual(s.overTolerance, 3)
        XCTAssertFalse(s.hasCompletedOnboarding)
        XCTAssertEqual(s.toleranceLabel, "+3 km/h")
        XCTAssertTrue(s.suggestEndingDrive)
    }

    func testRoundTrip() throws {
        var s = LimitSettings()
        s.overTolerance = 5
        XCTAssertEqual(LimitSettings.decode(s.encoded()), s)
    }

    /// The chime setting was removed; a copy saved by an earlier build still carries it.
    func testSettingsSavedWithTheOldChimeKeyStillDecode() {
        let old = Data("{\"showOnLockScreen\":false,\"overTolerance\":5,\"chimeOnLimitChange\":true,\"hasCompletedOnboarding\":true}".utf8)
        let s = LimitSettings.decode(old)
        XCTAssertFalse(s.showOnLockScreen)
        XCTAssertEqual(s.overTolerance, 5)
        XCTAssertTrue(s.hasCompletedOnboarding)
    }

    /// A copy saved before "Suggest ending my drive" existed keeps its other settings.
    func testSettingsSavedBeforeTheDriveStopKeyKeepTheRest() {
        let old = Data("{\"showOnLockScreen\":false,\"overTolerance\":5,\"hasCompletedOnboarding\":true}".utf8)
        let s = LimitSettings.decode(old)
        XCTAssertFalse(s.showOnLockScreen)
        XCTAssertEqual(s.overTolerance, 5)
        XCTAssertTrue(s.hasCompletedOnboarding)
        XCTAssertTrue(s.suggestEndingDrive, "defaults on")
    }

    func testBadDataGivesDefaults() {
        XCTAssertEqual(LimitSettings.decode(nil), LimitSettings())
        XCTAssertEqual(LimitSettings.decode(Data("garbage".utf8)), LimitSettings())
    }
}
