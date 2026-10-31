import XCTest
@testable import LimitCore

final class SyncStatusTests: XCTestCase {
    private let day: TimeInterval = 86_400
    private let now = Date(timeIntervalSince1970: 10_000_000)

    func testNothingCheckedYetIsNeverSynced() {
        XCTAssertEqual(SyncStatus().state(now: now), .neverSynced)
    }

    func testACheckedCopyIsUpToDateAndThenStaleAsTimePassesWithoutAnyEvent() {
        var status = SyncStatus()
        status.finished(checkedAt: now)
        XCTAssertEqual(status.state(now: now.addingTimeInterval(day)), .upToDate(checkedAt: now))
        XCTAssertEqual(status.state(now: now.addingTimeInterval(31 * day)), .stale(checkedAt: now),
                       "the app left open past the stale threshold must say so")
    }

    func testUpdatingShowsProgressAndTheFirstReportStartsIt() {
        var status = SyncStatus()
        XCTAssertFalse(status.isUpdating)
        status.progressed(nil)
        XCTAssertTrue(status.isUpdating)
        XCTAssertEqual(status.state(now: now), .updating(progress: nil))
        status.progressed(0.4)
        XCTAssertEqual(status.state(now: now), .updating(progress: 0.4))
    }

    func testFinishingClearsTheProgressAndRecordsTheCheck() {
        var status = SyncStatus()
        status.progressed(0.9)
        status.finished(checkedAt: now)
        XCTAssertFalse(status.isUpdating)
        XCTAssertEqual(status.state(now: now), .upToDate(checkedAt: now))
    }

    func testAFailureKeepsTheLastCheckBecauseThatCopyIsStillInUse() {
        var status = SyncStatus(checkedAt: now.addingTimeInterval(-3 * day))
        status.progressed(nil)
        status.failed()
        XCTAssertFalse(status.isUpdating)
        XCTAssertEqual(status.state(now: now), .failed(lastChecked: now.addingTimeInterval(-3 * day)))
    }

    func testAFailureWithNothingStoredHasNoLastCheck() {
        var status = SyncStatus()
        status.failed()
        XCTAssertEqual(status.state(now: now), .failed(lastChecked: nil))
    }

    func testARetryAfterAFailureCanSucceed() {
        var status = SyncStatus()
        status.failed()
        status.progressed(nil)
        XCTAssertEqual(status.state(now: now), .updating(progress: nil))
        status.finished(checkedAt: now)
        XCTAssertEqual(status.state(now: now), .upToDate(checkedAt: now))
    }
}
