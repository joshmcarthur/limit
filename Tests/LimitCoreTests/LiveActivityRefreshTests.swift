import XCTest
@testable import LimitCore

final class LiveActivityRefreshTests: XCTestCase {
    func testAChangeIsSentAtOnce() {
        XCTAssertTrue(LiveActivityRefresh.shouldSend(changed: true, secondsSinceLastSend: 0))
    }

    func testUnchangedContentIsResentBeforeItGoesStale() {
        XCTAssertFalse(LiveActivityRefresh.shouldSend(changed: false, secondsSinceLastSend: 1))
        XCTAssertFalse(LiveActivityRefresh.shouldSend(changed: false, secondsSinceLastSend: 2.9))
        XCTAssertTrue(LiveActivityRefresh.shouldSend(changed: false, secondsSinceLastSend: 3))
    }

    func testTheHeartbeatBeatsTheDimAndStaleTimes() {
        XCTAssertLessThan(LiveActivityRefresh.heartbeat, LiveActivityRefresh.dimAfter)
    }

    func testNothingSentYetMeansSend() {
        XCTAssertTrue(LiveActivityRefresh.shouldSend(changed: false, secondsSinceLastSend: nil))
    }
}
