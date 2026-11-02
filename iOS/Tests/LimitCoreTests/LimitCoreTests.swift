import XCTest
@testable import LimitCore

final class LimitCoreTests: XCTestCase {
    func testRegisterName() {
        XCTAssertEqual(LimitCore.registerName, "NZTA National Speed Limit Register")
    }

    /// CC BY 4.0 asks for credit. The drive screen and the About screen name the author. The Lock Screen does not.
    func testAttributionNamesTheAuthorAndTheRegister() {
        XCTAssertTrue(LimitCore.attribution.contains("Waka Kotahi"))
        XCTAssertTrue(LimitCore.attribution.contains("National Speed Limit Register"))
    }
}
