import XCTest
@testable import LimitCore

final class LiveActivityRefreshTests: XCTestCase {
    func testAChangeIsSentAtOnce() {
        XCTAssertTrue(LiveActivityRefresh.shouldSend(changed: true, secondsSinceLastSend: 0))
    }

    func testUnchangedContentIsResentBeforeItGoesStale() {
        XCTAssertFalse(LiveActivityRefresh.shouldSend(changed: false, secondsSinceLastSend: 1))
        XCTAssertFalse(LiveActivityRefresh.shouldSend(changed: false, secondsSinceLastSend: 4.9))
        XCTAssertTrue(LiveActivityRefresh.shouldSend(changed: false, secondsSinceLastSend: 5))
    }

    func testTheHeartbeatBeatsTheStaleTime() {
        XCTAssertLessThan(LiveActivityRefresh.heartbeat, LiveActivityRefresh.staleAfter)
    }

    func testNothingSentYetMeansSend() {
        XCTAssertTrue(LiveActivityRefresh.shouldSend(changed: false, secondsSinceLastSend: nil))
    }
}
