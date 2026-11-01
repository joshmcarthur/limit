import XCTest
@testable import LimitCore

final class LiveActivityRefreshTests: XCTestCase {
    func testAZoneChangeIsSentAtOnce() {
        XCTAssertTrue(LiveActivityRefresh.shouldSend(
            contentChanged: true, speedOnlyChange: false, showsSpeed: false, secondsSinceLastSend: 0))
        XCTAssertTrue(LiveActivityRefresh.shouldSend(
            contentChanged: true, speedOnlyChange: false, showsSpeed: true, secondsSinceLastSend: 0))
    }

    func testASpeedOnlyChangeIsNotSentWhenTheCardShowsTheName() {
        XCTAssertFalse(LiveActivityRefresh.shouldSend(
            contentChanged: true, speedOnlyChange: true, showsSpeed: false, secondsSinceLastSend: 20))
    }

    func testASpeedOnlyChangeIsSentAtOnceWhenTheCardShowsSpeed() {
        XCTAssertTrue(LiveActivityRefresh.shouldSend(
            contentChanged: true, speedOnlyChange: true, showsSpeed: true, secondsSinceLastSend: 0))
    }

    func testUnchangedSpeedIsResentOnTheHeartbeat() {
        XCTAssertFalse(LiveActivityRefresh.shouldSend(
            contentChanged: false, speedOnlyChange: false, showsSpeed: true, secondsSinceLastSend: 11))
        XCTAssertTrue(LiveActivityRefresh.shouldSend(
            contentChanged: false, speedOnlyChange: false, showsSpeed: true, secondsSinceLastSend: 12))
    }

    func testTheNameCardDoesNotHeartbeat() {
        XCTAssertFalse(LiveActivityRefresh.shouldSend(
            contentChanged: false, speedOnlyChange: false, showsSpeed: false, secondsSinceLastSend: 20))
        XCTAssertFalse(LiveActivityRefresh.shouldSend(
            contentChanged: false, speedOnlyChange: false, showsSpeed: false, secondsSinceLastSend: nil))
    }

    func testTheHeartbeatBeatsTheDim() {
        XCTAssertEqual(LiveActivityRefresh.heartbeat, 12)
        XCTAssertEqual(LiveActivityRefresh.dimAfter, 15)
        XCTAssertLessThan(LiveActivityRefresh.heartbeat, LiveActivityRefresh.dimAfter)
    }

    func testNothingSentYetMeansSendWhenTheCardShowsSpeed() {
        XCTAssertTrue(LiveActivityRefresh.shouldSend(
            contentChanged: false, speedOnlyChange: false, showsSpeed: true, secondsSinceLastSend: nil))
    }
}
