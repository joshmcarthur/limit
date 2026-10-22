import XCTest
@testable import LimitCore

final class SyncScheduleTests: XCTestCase {
    private let schedule = SyncSchedule.standard
    private let now = Date(timeIntervalSince1970: 10_000_000)
    private let week: TimeInterval = 7 * 86_400

    private func decide(_ attempts: SyncAttempts = SyncAttempts(), success: Date? = nil, manual: Bool = false) -> SyncSchedule.Decision {
        schedule.decision(attempts: attempts, lastSuccessAt: success, now: now, userInitiated: manual)
    }

    func testNothingStoredAndNothingTriedGoesNow() {
        XCTAssertEqual(decide(), .now)
    }

    func testAFreshCopyWaitsUntilAWeekAfterItsLastCheck() {
        let checked = now.addingTimeInterval(-86_400)
        XCTAssertEqual(decide(success: checked), .wait(until: checked.addingTimeInterval(week)))
        XCTAssertEqual(decide(success: now.addingTimeInterval(-week)), .now, "exactly a week is due")
    }

    func testBackOffStepsAndRepeatsTheLast() {
        let last = now.addingTimeInterval(-1)
        let steps: [TimeInterval] = [15 * 60, 3_600, 6 * 3_600, 86_400, 86_400, 86_400]
        for (i, step) in steps.enumerated() {
            let attempts = SyncAttempts(lastAttemptAt: last, consecutiveFailures: i + 1)
            XCTAssertEqual(decide(attempts), .wait(until: last.addingTimeInterval(step)), "failure \(i + 1)")
        }
    }

    func testBackOffEndsAndTheNextAttemptIsAllowed() {
        let attempts = SyncAttempts(lastAttemptAt: now.addingTimeInterval(-15 * 60), consecutiveFailures: 1)
        XCTAssertEqual(decide(attempts), .now)
    }

    func testTheLaterOfTheWeekAndTheBackOffWins() {
        let checked = now.addingTimeInterval(-6 * 86_400)
        let attempts = SyncAttempts(lastAttemptAt: now.addingTimeInterval(-60), consecutiveFailures: 1)
        XCTAssertEqual(decide(attempts, success: checked), .wait(until: checked.addingTimeInterval(week)))
    }

    func testManualChecksIgnoreTheWeekAndTheBackOff() {
        let attempts = SyncAttempts(lastAttemptAt: now.addingTimeInterval(-10 * 60), consecutiveFailures: 4)
        XCTAssertEqual(decide(attempts, success: now.addingTimeInterval(-3_600), manual: true), .now)
    }

    func testManualChecksKeepTheFloor() {
        let last = now.addingTimeInterval(-60)
        XCTAssertEqual(decide(SyncAttempts(lastAttemptAt: last, consecutiveFailures: 0), manual: true),
                       .wait(until: last.addingTimeInterval(5 * 60)))
    }

    func testAClockSetBackwardsCannotLockTheAppOutForLong() {
        let future = now.addingTimeInterval(30 * 86_400)
        XCTAssertEqual(decide(SyncAttempts(lastAttemptAt: future, consecutiveFailures: 1), success: future),
                       .wait(until: now.addingTimeInterval(week)))
    }
}
