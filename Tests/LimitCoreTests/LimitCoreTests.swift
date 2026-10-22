import XCTest
@testable import LimitCore

final class LimitCoreTests: XCTestCase {
    func testRegisterName() {
        XCTAssertEqual(LimitCore.registerName, "NZTA National Speed Limit Register")
    }
}
