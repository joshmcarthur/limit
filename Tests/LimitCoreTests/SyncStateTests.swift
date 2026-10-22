import XCTest
@testable import LimitCore

final class SyncStateTests: XCTestCase {
    private var calendar: Calendar {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Pacific/Auckland")!
        return c
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func testToday() {
        let now = date(2026, 10, 22, 15, 0)
        XCTAssertEqual(FreshnessText.when(date(2026, 10, 22, 6, 40), now: now, calendar: calendar), "today, 6:40 am")
        XCTAssertEqual(FreshnessText.when(date(2026, 10, 22, 12, 5), now: now, calendar: calendar), "today, 12:05 pm")
        XCTAssertEqual(FreshnessText.when(date(2026, 10, 22, 0, 9), now: now, calendar: calendar), "today, 12:09 am")
    }

    func testYesterdayAndOlder() {
        let now = date(2026, 10, 22, 15, 0)
        XCTAssertEqual(FreshnessText.when(date(2026, 10, 21, 23, 0), now: now, calendar: calendar), "yesterday")
        XCTAssertEqual(FreshnessText.when(date(2026, 10, 3, 9, 0), now: now, calendar: calendar), "3 Oct")
    }

    func testRestingState() {
        let now = date(2026, 10, 22)
        XCTAssertEqual(SyncState.resting(checkedAt: nil, now: now), .neverSynced)
        XCTAssertEqual(SyncState.resting(checkedAt: now.addingTimeInterval(-86_400), now: now),
                       .upToDate(checkedAt: now.addingTimeInterval(-86_400)))
        XCTAssertEqual(SyncState.resting(checkedAt: now.addingTimeInterval(-40 * 86_400), now: now),
                       .stale(checkedAt: now.addingTimeInterval(-40 * 86_400)))
    }

    func testFooterMatchesDesign() {
        let now = date(2026, 10, 22, 15, 0)
        let state = SyncState.upToDate(checkedAt: date(2026, 10, 22, 6, 40))
        XCTAssertEqual(FreshnessText.footer(for: state, now: now, calendar: calendar), "Speed limits checked today, 6:40 am")
        XCTAssertEqual(FreshnessText.footer(for: .neverSynced, now: now, calendar: calendar), "Speed limits not downloaded yet")
    }

    func testRowCopy() {
        let now = date(2026, 10, 22, 15, 0)
        let row = FreshnessText.row(for: .updating(progress: 0.42), now: now, calendar: calendar)
        XCTAssertEqual(row.title, "Updating speed limits…")
        XCTAssertEqual(row.subtitle, "42% · NZTA National Speed Limit Register")
        let failed = FreshnessText.row(for: .failed(lastChecked: date(2026, 10, 3)), now: now, calendar: calendar)
        XCTAssertEqual(failed.subtitle, "Still using speed limit data from 3 Oct.")
        XCTAssertEqual(failed.title, "Couldn’t update the speed limit database")
        XCTAssertFalse(failed.subtitle.lowercased().contains("error"))
        let nothingYet = FreshnessText.row(for: .failed(lastChecked: nil), now: now, calendar: calendar)
        XCTAssertEqual(nothingYet.subtitle, "There's no speed limit data on this phone yet.")
    }
}
