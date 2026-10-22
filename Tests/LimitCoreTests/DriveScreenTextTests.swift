import XCTest
@testable import LimitCore

final class DriveScreenTextTests: XCTestCase {
    private let withLimit = DriveSnapshot(sign: .limit(50, isStale: false), roadName: "Cuba Street")
    private let limitNoName = DriveSnapshot(sign: .limit(50, isStale: false))
    private let noLimit = DriveSnapshot.searching

    private func text(_ snapshot: DriveSnapshot, driving: Bool = true, access: LocationAccess = .authorized) -> (String, String) {
        (DriveScreenText.headline(isDriving: driving, access: access, snapshot: snapshot),
         DriveScreenText.subheadline(isDriving: driving, access: access, snapshot: snapshot))
    }

    func testOnlyAuthorizedAccessIsUsable() {
        XCTAssertTrue(LocationAccess.authorized.isUsable)
        for access in [LocationAccess.notDetermined, .denied, .reduced] { XCTAssertFalse(access.isUsable) }
    }

    func testAnEndedDriveWinsOverEverythingElse() {
        for access in [LocationAccess.notDetermined, .denied, .reduced, .authorized] {
            let (headline, subheadline) = text(withLimit, driving: false, access: access)
            XCTAssertEqual(headline, "Drive ended")
            XCTAssertEqual(subheadline, "Start a drive to see the limit")
        }
    }

    func testWithoutUsableAccessItSaysWhatToDoAndNeverShowsARoad() {
        let cases: [(LocationAccess, String)] = [
            (.denied, "Turn on location for Limit in Settings"),
            (.reduced, "Turn on Precise Location so Limit can find your road"),
            (.notDetermined, "Allow location to see the limit"),
        ]
        for (access, advice) in cases {
            let (headline, subheadline) = text(withLimit, access: access)
            XCTAssertEqual(headline, "Location needed")
            XCTAssertEqual(subheadline, advice)
        }
    }

    func testWithAccessItNamesTheRoadAndCreditsTheRegister() {
        let (headline, subheadline) = text(withLimit)
        XCTAssertEqual(headline, "Cuba Street")
        XCTAssertEqual(subheadline, LimitCore.attribution)
    }

    func testALimitWithNoRoadNameIsStillAnnounced() {
        XCTAssertEqual(text(limitNoName).0, "Speed limit")
    }

    func testWithNoLimitYetItSaysSoAndPointsAtTheSigns() {
        let (headline, subheadline) = text(noLimit)
        XCTAssertEqual(headline, "Finding your road…")
        XCTAssertEqual(subheadline, "Obey the posted speed limit signs")
    }
}
