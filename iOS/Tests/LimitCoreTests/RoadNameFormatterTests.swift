import XCTest
@testable import LimitCore

final class RoadNameFormatterTests: XCTestCase {
    func testTitleCase() {
        XCTAssertEqual(RoadNameFormatter.display("GLOUCESTER STREET"), "Gloucester Street")
        XCTAssertEqual(RoadNameFormatter.display("  MAIN NORTH ROAD "), "Main North Road")
    }

    func testStripsUTASuffix() {
        XCTAssertEqual(RoadNameFormatter.display("WELLINGTON CITY UTA"), "Wellington City")
    }

    func testKeepsStateHighwayAbbreviations() {
        XCTAssertEqual(RoadNameFormatter.display("BLAKES ROAD - SHANDS ROAD TO SH 76"), "Blakes Road - Shands Road To SH 76")
        XCTAssertEqual(RoadNameFormatter.display("OLD NORTH ROAD - FROM SH1"), "Old North Road - From SH1")
    }

    func testParenthesesAndHyphens() {
        XCTAssertEqual(RoadNameFormatter.display("TE PAERAHI (PORANGAHAU BEACH)"), "Te Paerahi (Porangahau Beach)")
        XCTAssertEqual(RoadNameFormatter.display("MT-VICTORIA"), "Mt-Victoria")
    }

    func testEmptyIsNil() {
        XCTAssertNil(RoadNameFormatter.display(nil))
        XCTAssertNil(RoadNameFormatter.display("   "))
        XCTAssertNil(RoadNameFormatter.display(" UTA"))
    }
}
