import XCTest
@testable import LimitCore

final class LimitNoteTests: XCTestCase {
    func testOnlySeasonalAndEmergencyRecordsGetANote() {
        XCTAssertEqual(LimitNote(kind: .seasonal), .seasonal)
        XCTAssertEqual(LimitNote(kind: .emergency), .temporary)
        XCTAssertNil(LimitNote(kind: .permanent))
        XCTAssertNil(LimitNote(kind: .variable), "school zones carry no note")
        XCTAssertNil(LimitNote(kind: nil))
    }

    func testTheWording() {
        XCTAssertEqual(LimitNote.seasonal.label, "Seasonal limit, obey the posted signs")
        XCTAssertEqual(LimitNote.temporary.label, "Temporary limit, obey the posted signs")
    }

    func testVoiceOverReadsTheNoteAfterTheLimit() {
        XCTAssertEqual(AccessibilityLabels.sign(.limit(30, isStale: false), note: .seasonal),
                       "Speed limit 30 kilometres per hour, seasonal")
        XCTAssertEqual(AccessibilityLabels.sign(.limit(50, isStale: false), note: .temporary),
                       "Speed limit 50 kilometres per hour, temporary")
        XCTAssertEqual(AccessibilityLabels.sign(.limit(50, isStale: false), note: nil), "Speed limit 50 kilometres per hour")
        XCTAssertEqual(AccessibilityLabels.sign(.unknown, note: .seasonal), "Speed limit unknown", "no limit, nothing to qualify")
    }

    func testTheNoteSurvivesTheTripToTheLiveActivity() throws {
        let snapshot = DriveSnapshot(sign: .limit(30, isStale: false), speed: 28, roadName: "Motor Camp", limitNote: .seasonal)
        let decoded = try JSONDecoder().decode(DriveSnapshot.self, from: JSONEncoder().encode(snapshot))
        XCTAssertEqual(decoded.limitNote, .seasonal)
        XCTAssertNotEqual(snapshot, DriveSnapshot(sign: .limit(30, isStale: false), speed: 28, roadName: "Motor Camp"), "a note is a change worth sending")
    }

    // MARK: From the engine

    private func ring() -> Ring {
        Ring(points: [
            Coordinate(latitude: -41, longitude: 174), Coordinate(latitude: -41, longitude: 175),
            Coordinate(latitude: -40, longitude: 175), Coordinate(latitude: -40, longitude: 174),
        ])!
    }

    private func nz(_ y: Int, _ m: Int, _ d: Int) -> Date {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ReducedLimit.timeZone
        return calendar.date(from: DateComponents(year: y, month: m, day: d, hour: 12))!
    }

    private func snapshot(_ zone: SpeedZone, at date: Date) -> DriveSnapshot {
        var engine = DriveEngine(register: SpeedLimitRegister(zones: [zone]), registerCheckedAt: date)
        let sample = LocationSample(coordinate: Coordinate(latitude: -40.5, longitude: 174.5), speedMetresPerSecond: 8,
                                    horizontalAccuracy: 5, timestamp: date)
        return engine.ingest(sample, now: date).snapshot
    }

    func testTheDriveScreenGetsTheNoteWhileASeasonalLimitIsInForce() {
        let summer = ActivePeriod(start: nz(2021, 12, 1), end: nz(2022, 4, 30), repeatsYearly: true)
        let zone = SpeedZone(name: "MOTOR CAMP", limit: 30, kind: .seasonal, period: summer, polygons: [Polygon(outer: ring())])!
        XCTAssertEqual(snapshot(zone, at: nz(2026, 12, 20)).limitNote, .seasonal)
        XCTAssertEqual(snapshot(zone, at: nz(2026, 12, 20)).limit, 30)
        XCTAssertNil(snapshot(zone, at: nz(2026, 7, 1)).limit, "out of season and nothing else underneath")
    }

    func testAPermanentLimitHasNoNote() {
        let zone = SpeedZone(name: "ROAD", limit: 50, polygons: [Polygon(outer: ring())])!
        XCTAssertNil(snapshot(zone, at: nz(2026, 10, 22)).limitNote)
    }

    func testAnEmergencyLimitIsLabelledTemporary() {
        let zone = SpeedZone(name: "DIVERSION", limit: 50, kind: .emergency,
                             period: ActivePeriod(start: nz(2026, 10, 1), end: nz(2026, 12, 31)), polygons: [Polygon(outer: ring())])!
        XCTAssertEqual(snapshot(zone, at: nz(2026, 10, 22)).limitNote, .temporary)
    }
}
