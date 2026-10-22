import XCTest
@testable import LimitCore

final class SchoolPeriodParserTests: XCTestCase {
    private func w(_ sh: Int, _ sm: Int, _ eh: Int, _ em: Int) -> TimeWindow {
        TimeWindow(startMinute: sh * 60 + sm, endMinute: eh * 60 + em)!
    }

    /// Wordings copied from the live layer (speedLimitZoneVarPrdDesc).
    func testWordingsFromTheRegister() {
        let cases: [(String, [TimeWindow])] = [
            ("Periods of Operation 08:30 – 9:15am and 2:45 – 3:30pm", [w(8, 30, 9, 15), w(14, 45, 15, 30)]),
            ("School Days 8.30 to 9.30 am and 2.30 to 3.30 pm", [w(8, 30, 9, 30), w(14, 30, 15, 30)]),
            ("School Days 8.30am to 9.30am and 2.30pm to 3.30pm   ", [w(8, 30, 9, 30), w(14, 30, 15, 30)]),
            ("7.45am to 9.15am & \n2.30pm to 4.00pm, \nSchool Days Only", [w(7, 45, 9, 15), w(14, 30, 16, 0)]),
            ("8.15-9am, 2.45-3.30pm", [w(8, 15, 9, 0), w(14, 45, 15, 30)]),
            ("8.20am - 9.20am,\n2.20pm - 3.20pm", [w(8, 20, 9, 20), w(14, 20, 15, 20)]),
            ("8:00-9:30am\n2:30-3:30pm\n10 minutes at any other time when children cross the road or enter or leave vehicles at the roadside.",
             [w(8, 0, 9, 30), w(14, 30, 15, 30)]),
            ("School morning period starts at 8.25am and ends at 9.00am;\nSchool afternoon period starts at 2.55pm and ends at 3.15pm;\n10 minutes at any other time when children cross the road or enter or leave vehicles at the roadside.",
             [w(8, 25, 9, 0), w(14, 55, 15, 15)]),
            ("40km/h variable speed limit between the hours of 8:00am - 9:30am and 2:30pm - 3:30pm on any school day, and for up to ten minutes at any other time when children cross the road or enter or leave vehicles at the side of the road.",
             [w(8, 0, 9, 30), w(14, 30, 15, 30)]),
        ]
        for (text, expected) in cases {
            XCTAssertEqual(SchoolPeriodParser.windows(from: text), expected, text)
        }
    }

    func testRelativeToTheBellHasNoClockTimes() {
        let relative = [
            "35 minutes before the start of school until the start of school;\n20 minutes at the end of school, beginning no earlier than 5 minutes before the end of school;\n10 minutes at any other time when children cross the road or enter or leave vehicles at the roadside.",
            "45 minutes before the start of school and ending no later than 45 minutes after the start; 45 minutes after the end of school, beginning no earlier than 45 minutes before the end of school.",
            "Periods of Operation The 30km/h speed limit may operate for a maximum period of:(a) 35 minutes before the start of school until the start of school;(b) 20 minutes at the end of school, beginning no earlier than 5 minutes before the end of school;(c) 10 minutes at any other time when children cross the road or enter or leave vehicles at the roadside.",
        ]
        for text in relative { XCTAssertNil(SchoolPeriodParser.windows(from: text), text) }
    }

    func testHighwayVariableSpeedNoticesAreNotWindows() {
        XCTAssertNil(SchoolPeriodParser.windows(from: "A variable speed limit of 50 60 70 80 90 or 100 km/h.A speed limit applies from the point on the State highway at which a variable speed limit sign facing the road user is installed."))
        XCTAssertNil(SchoolPeriodParser.windows(from: "Waka Kotahi may set a 30/40/50/60/70/80 or 100km/h variable speed limit on the sections of State Highway 1."))
    }

    func testTimesThatDifferByDayAreNotGuessed() {
        XCTAssertNil(SchoolPeriodParser.windows(from: "30km/h variable speed limit between the hours of 8:25am - 9:15am and 2:30pm - 3:20pm on any school day (Monday, Tuesday, Wednesday, and Thursday only)"))
        XCTAssertNil(SchoolPeriodParser.windows(from: "8.10-8.45am and 3.10-3.30pm (2.30-2.50pm on Wednesdays)"))
    }

    func testListsOfSeveralSchoolsAreNotGuessed() {
        XCTAssertNil(SchoolPeriodParser.windows(from: "Schools:\n\nPapakōwhai School\n8:15 a.m. - 9:30 a.m.\n2:30 p.m. - 3:30 p.m.\n\nRangikura School\n8:15 a.m. - 9:30 a.m.\n2:30 p.m. - 3:30 p.m."))
    }

    func testDottedAMPM() {
        XCTAssertEqual(SchoolPeriodParser.windows(from: "8:15 a.m. - 9:30 a.m.\n1:30 p.m. - 3:30 p.m."), [w(8, 15, 9, 30), w(13, 30, 15, 30)])
    }

    func testSingleWindowIsAccepted() {
        XCTAssertEqual(SchoolPeriodParser.windows(from: "8.30am to 9.15am"), [w(8, 30, 9, 15)])
    }

    func testStartInTheMorningWhenOnlyTheEndSaysPM() {
        XCTAssertEqual(SchoolPeriodParser.windows(from: "11.30 to 12.15 pm"), [w(11, 30, 12, 15)])
    }

    func testImplausibleWindowsAreRejected() {
        XCTAssertNil(SchoolPeriodParser.windows(from: "9.30am to 8.30am"), "ends before it starts")
        XCTAssertNil(SchoolPeriodParser.windows(from: "8.00am to 2.00pm"), "longer than a school period")
        XCTAssertNil(SchoolPeriodParser.windows(from: "1.00am to 2.00am"), "middle of the night")
        XCTAssertNil(SchoolPeriodParser.windows(from: "8.00am to 9.00am and 8.30am to 9.30am"), "overlapping")
        XCTAssertNil(SchoolPeriodParser.windows(from: "8.00am to 9.00am and 2.00pm"), "odd number of times")
        XCTAssertNil(SchoolPeriodParser.windows(from: ""))
    }

    // MARK: Active windows

    private func date(_ iso: String) -> Date { ISO8601DateFormatter().date(from: iso)! }

    func testActiveOnlyOnWeekdaysInsideTheWindowsInNZTime() throws {
        let reduced = try XCTUnwrap(ReducedLimit(limit: 40, windows: [w(8, 30, 9, 15), w(14, 45, 15, 30)]))
        // Thursday 22 October 2026, NZDT (UTC+13).
        XCTAssertTrue(reduced.isActive(at: date("2026-10-22T08:30:00+13:00")), "window start is inclusive")
        XCTAssertTrue(reduced.isActive(at: date("2026-10-22T15:29:00+13:00")))
        XCTAssertFalse(reduced.isActive(at: date("2026-10-22T09:15:00+13:00")), "window end is exclusive")
        XCTAssertFalse(reduced.isActive(at: date("2026-10-22T12:00:00+13:00")))
        // The same instant seen from another zone is still judged in NZ time.
        XCTAssertTrue(reduced.isActive(at: date("2026-10-21T19:40:00Z")), "08:40 NZDT")
        // Saturday and Sunday.
        XCTAssertFalse(reduced.isActive(at: date("2026-10-24T08:45:00+13:00")))
        XCTAssertFalse(reduced.isActive(at: date("2026-10-25T08:45:00+13:00")))
        // Monday and Friday count.
        XCTAssertTrue(reduced.isActive(at: date("2026-10-19T08:45:00+13:00")))
        XCTAssertTrue(reduced.isActive(at: date("2026-10-23T08:45:00+13:00")))
    }

    func testNoWindowsMeansNoReducedLimit() {
        XCTAssertNil(ReducedLimit(limit: 40, windows: []))
    }

    // MARK: The real layer

    /// Opt-in: runs over a saved copy of the layer's variable-speed records in data/ (gitignored), if there.
    /// Guards against the parser regressing on the wordings that actually exist.
    func testCoverageOnASavedCopyOfTheRegister() throws {
        let dir = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("data")
        var texts: [String] = []
        for name in ["var0.json", "var2000.json", "var4000.json"] {
            guard let data = try? Data(contentsOf: dir.appendingPathComponent(name)),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let features = object["features"] as? [[String: Any]] else { continue }
            texts += features.compactMap { ($0["attributes"] as? [String: Any])?["speedLimitZoneVarPrdDesc"] as? String }
        }
        try XCTSkipIf(texts.isEmpty, "no saved register sample in data/")
        let parsed = texts.filter { SchoolPeriodParser.windows(from: $0) != nil }.count
        print("school windows parsed from \(parsed) of \(texts.count) records")
        XCTAssertGreaterThan(Double(parsed) / Double(texts.count), 0.5)
    }
}
