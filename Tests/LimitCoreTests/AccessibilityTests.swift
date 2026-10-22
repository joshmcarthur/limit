import XCTest
@testable import LimitCore

final class AccessibilityTests: XCTestCase {
    func testSignLabels() {
        XCTAssertEqual(AccessibilityLabels.sign(.limit(50, isStale: false)), "Speed limit 50 kilometres per hour")
        XCTAssertEqual(AccessibilityLabels.sign(.unknown), "Speed limit unknown")
        XCTAssertEqual(AccessibilityLabels.sign(.openRoad(isStale: false)), "No limit recorded for this road, follow the posted signs")
    }

    func testReadoutLabels() {
        XCTAssertEqual(AccessibilityLabels.readout(speed: 47, over: .notOver), "Your speed is 47 kilometres per hour")
        XCTAssertEqual(AccessibilityLabels.readout(speed: 38, over: .over(by: 8)),
                       "Your speed is 38 kilometres per hour, 8 over the limit")
        XCTAssertEqual(AccessibilityLabels.readout(speed: nil, over: .notOver), "Your speed isn't available, there's no GPS")
    }
}
