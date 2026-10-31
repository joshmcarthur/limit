import XCTest
@testable import LimitCore

/// The design system promises these contrast ratios; fail the build if a token edit breaks one.
final class DesignTokensTests: XCTestCase {
    private typealias T = DesignTokens

    func testContrastKnownValues() {
        XCTAssertEqual(HexColor(0x000000).contrast(with: HexColor(0xFFFFFF)), 21, accuracy: 0.001)
        XCTAssertEqual(HexColor(0xFFFFFF).contrast(with: HexColor(0xFFFFFF)), 1, accuracy: 0.001)
    }

    func testMutedInkMeetsAAOnGroundAndSurfaceInBothThemes() {
        for (fg, bg) in [(T.inkMuted, T.ground), (T.inkMuted, T.surface)] {
            XCTAssertGreaterThanOrEqual(fg.light.contrast(with: bg.light), 4.5)
            XCTAssertGreaterThanOrEqual(fg.dark.contrast(with: bg.dark), 4.5)
        }
    }

    func testTintMeetsAAAsTextAndOnButtons() {
        for bg in [T.ground, T.surface] {
            XCTAssertGreaterThanOrEqual(T.tint.light.contrast(with: bg.light), 4.5)
            XCTAssertGreaterThanOrEqual(T.tint.dark.contrast(with: bg.dark), 4.5)
        }
        XCTAssertGreaterThanOrEqual(HexColor(0xFFFFFF).contrast(with: T.tint.light), 4.5)
    }

    func testCautionInkMeetsAAAsText() {
        for bg in [T.ground, T.surface] {
            XCTAssertGreaterThanOrEqual(T.cautionInk.light.contrast(with: bg.light), 4.5)
            XCTAssertGreaterThanOrEqual(T.cautionInk.dark.contrast(with: bg.dark), 4.5)
        }
    }

    func testOverLimitPillTextIsReadable() {
        XCTAssertGreaterThanOrEqual(T.onCaution.light.contrast(with: T.caution.light), 4.5)
    }

    func testSignIsReadableAndUnknownRingMeetsGraphicContrast() {
        XCTAssertGreaterThanOrEqual(T.signInk.light.contrast(with: T.signFace.light), 7)
        XCTAssertGreaterThanOrEqual(T.unknown.light.contrast(with: T.signFace.light), 3)
        XCTAssertGreaterThanOrEqual(T.signRing.light.contrast(with: T.signFace.light), 3)
    }

    func testSignColoursAreThemeIndependent() {
        for c in [T.signFace, T.signRing, T.signInk, T.island, T.onIsland] {
            XCTAssertEqual(c.light, c.dark)
        }
    }

    func testHexDecoding() {
        let c = HexColor(0xC8102E)
        XCTAssertEqual([c.red, c.green, c.blue], [0xC8, 0x10, 0x2E])
    }
}
