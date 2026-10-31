import XCTest
@testable import LimitCore

final class ZoneActivityTests: XCTestCase {
    /// A moment in NZ local time.
    private func nz(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12, _ min: Int = 0) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ReducedLimit.timeZone
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    // MARK: Kinds

    func testCategoryNamesMapToKinds() {
        XCTAssertEqual(ZoneKind(category: "Permanent"), .permanent)
        XCTAssertEqual(ZoneKind(category: "Variable"), .variable)
        XCTAssertEqual(ZoneKind(category: "Seasonal"), .seasonal)
        XCTAssertEqual(ZoneKind(category: "Temporary"), .emergency)
        XCTAssertEqual(ZoneKind(category: " seasonal "), .seasonal)
    }

    func testUnknownOrMissingCategoryIsPermanentSoTheLimitStillShows() {
        XCTAssertEqual(ZoneKind(category: nil), .permanent)
        XCTAssertEqual(ZoneKind(category: ""), .permanent)
        XCTAssertEqual(ZoneKind(category: "Something new"), .permanent)
    }

    func testPriorityFollowsTheRegistersOverlapRules() {
        XCTAssertGreaterThan(ZoneKind.emergency.priority, ZoneKind.seasonal.priority)
        XCTAssertGreaterThan(ZoneKind.seasonal.priority, ZoneKind.permanent.priority)
        XCTAssertEqual(ZoneKind.permanent.priority, ZoneKind.variable.priority, "they can't overlap each other")
    }

    func testOnlySeasonalAndEmergencyAreTemporaryByNature() {
        XCTAssertEqual([ZoneKind.permanent, .variable, .seasonal, .emergency].map(\.isTemporaryByNature), [false, false, true, true])
    }

    func testStructureTypes() {
        XCTAssertEqual(StructureType(name: "Overpass"), .overpass)
        XCTAssertEqual(StructureType(name: "Underpass"), .underpass)
        XCTAssertEqual(StructureType(name: "Intersection"), .intersection)
        XCTAssertEqual(StructureType(name: nil), .none)
        XCTAssertEqual(StructureType(name: "Roundabout"), .none)
        XCTAssertTrue(StructureType.overpass.isGradeSeparated)
        XCTAssertTrue(StructureType.underpass.isGradeSeparated)
        XCTAssertFalse(StructureType.intersection.isGradeSeparated)
        XCTAssertFalse(StructureType.none.isGradeSeparated)
    }

    // MARK: One-off periods

    func testADatedPeriodIncludesBothEndDays() throws {
        let period = try XCTUnwrap(ActivePeriod(start: nz(2023, 8, 18, 0, 0), end: nz(2024, 8, 17, 0, 0)))
        XCTAssertFalse(period.isActive(at: nz(2023, 8, 17, 23, 59)))
        XCTAssertTrue(period.isActive(at: nz(2023, 8, 18, 0, 0)))
        XCTAssertTrue(period.isActive(at: nz(2024, 8, 17, 23, 59)), "the last day runs to the end of the day")
        XCTAssertFalse(period.isActive(at: nz(2024, 8, 18, 0, 0)))
    }

    func testAnEndedPeriodStaysEnded() throws {
        // Emergency limits for a 2023 closure are still in the register but no longer apply.
        let period = try XCTUnwrap(ActivePeriod(start: nz(2023, 8, 18), end: nz(2024, 8, 17)))
        XCTAssertFalse(period.isActive(at: nz(2026, 10, 22)))
    }

    func testAnOpenEndedPeriodNeverEnds() throws {
        let period = try XCTUnwrap(ActivePeriod(start: nz(2022, 5, 26), end: nil))
        XCTAssertFalse(period.isActive(at: nz(2022, 5, 25)))
        XCTAssertTrue(period.isActive(at: nz(2040, 1, 1)))
    }

    func testAPeriodWithNoStartHasAlwaysBegun() throws {
        let period = try XCTUnwrap(ActivePeriod(start: nil, end: nz(2025, 6, 10)))
        XCTAssertTrue(period.isActive(at: nz(1990, 1, 1)))
        XCTAssertTrue(period.isActive(at: nz(2025, 6, 10, 23, 0)))
        XCTAssertFalse(period.isActive(at: nz(2025, 6, 11, 0, 0)))
    }

    func testDaysAreNZDaysAcrossDaylightSavingChanges() throws {
        // NZ daylight time ends on 5 April 2026 (25 hours that day) and starts on 27 September 2026.
        let ends = try XCTUnwrap(ActivePeriod(start: nz(2026, 3, 1), end: nz(2026, 4, 5)))
        XCTAssertTrue(ends.isActive(at: nz(2026, 4, 5, 23, 59)))
        XCTAssertFalse(ends.isActive(at: nz(2026, 4, 6, 0, 0)))
        let starts = try XCTUnwrap(ActivePeriod(start: nz(2026, 9, 27), end: nz(2026, 10, 10)))
        XCTAssertFalse(starts.isActive(at: nz(2026, 9, 26, 23, 59)))
        XCTAssertTrue(starts.isActive(at: nz(2026, 9, 27, 0, 0)))
    }

    func testTheSameInstantIsJudgedInNZNotUTC() throws {
        let period = try XCTUnwrap(ActivePeriod(start: nz(2026, 12, 1), end: nz(2026, 12, 31)))
        // 30 November 2026, 11:30 UTC is already 1 December in NZ (UTC+13).
        let utc = ISO8601DateFormatter().date(from: "2026-11-30T11:30:00Z")!
        XCTAssertTrue(period.isActive(at: utc))
    }

    // MARK: Yearly periods

    func testAYearlyWindowRepeatsInEveryYear() throws {
        // Lake Brunner Motor Camp: 1 December to 30 April, recorded as 2021-22.
        let period = try XCTUnwrap(ActivePeriod(start: nz(2021, 12, 1), end: nz(2022, 4, 30), repeatsYearly: true))
        XCTAssertTrue(period.isActive(at: nz(2026, 12, 1)), "first day, years later")
        XCTAssertTrue(period.isActive(at: nz(2027, 1, 15)), "after New Year")
        XCTAssertTrue(period.isActive(at: nz(2027, 4, 30, 23, 59)), "last day")
        XCTAssertFalse(period.isActive(at: nz(2027, 5, 1)))
        XCTAssertFalse(period.isActive(at: nz(2026, 7, 1)))
        XCTAssertFalse(period.isActive(at: nz(2026, 11, 30, 23, 59)))
    }

    func testAYearlyWindowInsideOneCalendarYear() throws {
        let period = try XCTUnwrap(ActivePeriod(start: nz(2022, 7, 9), end: nz(2022, 7, 24), repeatsYearly: true))
        XCTAssertTrue(period.isActive(at: nz(2026, 7, 9)))
        XCTAssertTrue(period.isActive(at: nz(2026, 7, 24, 23, 59)))
        XCTAssertFalse(period.isActive(at: nz(2026, 7, 8, 23, 59)))
        XCTAssertFalse(period.isActive(at: nz(2026, 7, 25)))
        XCTAssertFalse(period.isActive(at: nz(2026, 1, 1)))
    }

    func testAYearlyWindowStartingOnLeapDayStillWorksInOtherYears() throws {
        let period = try XCTUnwrap(ActivePeriod(start: nz(2024, 2, 29), end: nz(2024, 3, 10), repeatsYearly: true))
        XCTAssertTrue(period.isActive(at: nz(2026, 3, 1)))
        XCTAssertFalse(period.isActive(at: nz(2026, 2, 27)))
    }

    func testAYearlyWindowNeedsBothEnds() {
        XCTAssertNil(ActivePeriod(start: nz(2022, 1, 1), end: nil, repeatsYearly: true))
        XCTAssertNil(ActivePeriod(start: nil, end: nz(2022, 1, 1), repeatsYearly: true))
    }

    func testNoDatesMeansNoPeriod() {
        XCTAssertNil(ActivePeriod(start: nil, end: nil))
        XCTAssertNil(ActivePeriod(start: nil, end: nil, repeatsYearly: true))
    }

    func testAnEndBeforeTheStartIsRejected() {
        XCTAssertNil(ActivePeriod(start: nz(2024, 5, 1), end: nz(2024, 4, 1)))
    }
}
