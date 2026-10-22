import XCTest
@testable import LimitCore

final class DriveScreenTextTests: XCTestCase {
    private let withLimit = DriveSnapshot(sign: .limit(50, isStale: false), roadName: "Cuba Street")
    private let limitNoName = DriveSnapshot(sign: .limit(50, isStale: false))
    private let noLimit = DriveSnapshot.searching

    private func text(_ snapshot: DriveSnapshot, driving: Bool = true, access: LocationAccess = .authorized) -> (String, String?) {
        (DriveScreenText.headline(isDriving: driving, access: access, snapshot: snapshot),
         DriveScreenText.subheadline(isDriving: driving, access: access, snapshot: snapshot))
    }

    func testOnlyAuthorizedAccessIsUsable() {
        XCTAssertTrue(LocationAccess.authorized.isUsable)
        for access in [LocationAccess.notDetermined, .denied, .reduced] { XCTAssertFalse(access.isUsable) }
    }

    func testAnEndedDriveWithAccessSaysSo() {
        let (headline, subheadline) = text(withLimit, driving: false, access: .authorized)
        XCTAssertEqual(headline, "Drive ended")
        XCTAssertEqual(subheadline, "Location and the Lock Screen card are off.")
    }

    func testWithoutUsableAccessItSaysWhatToDoAndNeverShowsARoad() {
        let cases: [(LocationAccess, String)] = [
            (.denied, "Turn on location for Limit in Settings"),
            (.reduced, "Turn on Precise Location so Limit can find your road"),
            (.notDetermined, "Allow location to see the limit"),
        ]
        for (access, advice) in cases {
            for driving in [true, false] {
                // Not driving is what someone sees who said no to location before any drive began.
                let (headline, subheadline) = text(withLimit, driving: driving, access: access)
                XCTAssertEqual(headline, "Location needed")
                XCTAssertEqual(subheadline, advice)
            }
        }
    }

    func testWithAccessItNamesTheRoadAndNothingElse() {
        let (headline, subheadline) = text(withLimit)
        XCTAssertEqual(headline, "Cuba Street")
        XCTAssertNil(subheadline, "the register credit lives at the bottom of the screen now")
    }

    func testALimitWithNoRoadNameIsStillAnnounced() {
        XCTAssertEqual(text(limitNoName).0, "Speed limit")
    }

    func testWithNoLimitYetItSaysSoAndPointsAtTheSigns() {
        let (headline, subheadline) = text(noLimit)
        XCTAssertEqual(headline, "Finding your road…")
        XCTAssertEqual(subheadline, "Obey the posted speed limit signs")
    }

    func testOutsideNewZealandSaysSoInsteadOfLookingForever() {
        let outside = DriveSnapshot(roadName: "Outside New Zealand", isOutsideNewZealand: true)
        let (headline, subheadline) = text(outside)
        XCTAssertEqual(headline, "Outside New Zealand")
        XCTAssertEqual(subheadline, "Limit only has New Zealand speed limits. Your speed is still shown.")
    }
}
