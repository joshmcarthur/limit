import XCTest
@testable import LimitCore

final class RegisterStoreTests: XCTestCase {
    private var directory: URL!

    override func setUpWithError() throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent("limit-tests-\(UUID().uuidString)")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: directory)
    }

    private func zones() -> [SpeedZone] {
        let ring = Ring(points: [
            Coordinate(latitude: -41.1, longitude: 173.9), Coordinate(latitude: -41.1, longitude: 174.1),
            Coordinate(latitude: -40.9, longitude: 174.1), Coordinate(latitude: -40.9, longitude: 173.9),
        ])!
        return [SpeedZone(name: "MAIN ROAD", limit: 60, polygons: [Polygon(outer: ring)])!]
    }

    private let checked = Date(timeIntervalSince1970: 1_800_000_000)

    func testEmptyStoreLoadsNil() throws {
        XCTAssertNil(try RegisterStore(directory: directory).load())
        XCTAssertNil(try RegisterStore(directory: directory).loadMetadata())
    }

    func testSaveThenLoad() throws {
        let store = RegisterStore(directory: directory)
        let meta = RegisterMetadata(checkedAt: checked, zoneCount: 1, sourceFeatureCount: 3)
        try store.save(zones: zones(), metadata: meta)
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.metadata, meta)
        XCTAssertEqual(loaded.register.lookup(Coordinate(latitude: -41, longitude: 174))?.limit, 60)
    }

    func testUpdateCheckedAtKeepsData() throws {
        let store = RegisterStore(directory: directory)
        try store.save(zones: zones(), metadata: RegisterMetadata(checkedAt: checked, zoneCount: 1, sourceFeatureCount: 1))
        try store.updateCheckedAt(checked.addingTimeInterval(86_400))
        let loaded = try XCTUnwrap(store.load())
        XCTAssertEqual(loaded.metadata.checkedAt, checked.addingTimeInterval(86_400))
        XCTAssertEqual(loaded.register.zoneCount, 1)
    }

    func testCorruptDataThrowsAndClearRecovers() throws {
        let store = RegisterStore(directory: directory)
        try store.save(zones: zones(), metadata: RegisterMetadata(checkedAt: checked, zoneCount: 1, sourceFeatureCount: 1))
        let generation = try XCTUnwrap(store.currentGeneration)
        try Data("junk".utf8).write(to: directory.appendingPathComponent(generation).appendingPathComponent("register.lmtz"))
        XCTAssertThrowsError(try store.load())
        try store.clear()
        XCTAssertNil(try store.load())
    }

    // MARK: Blue-green swap

    private func other() -> [SpeedZone] {
        let ring = Ring(points: [
            Coordinate(latitude: -45.1, longitude: 169.9), Coordinate(latitude: -45.1, longitude: 170.1),
            Coordinate(latitude: -44.9, longitude: 170.1), Coordinate(latitude: -44.9, longitude: 169.9),
        ])!
        return [SpeedZone(name: "OTHER ROAD", limit: 80, polygons: [Polygon(outer: ring)])!]
    }

    private func meta(_ count: Int = 1) -> RegisterMetadata {
        RegisterMetadata(checkedAt: checked, zoneCount: count, sourceFeatureCount: count)
    }

    private func generations() throws -> [String] {
        try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasPrefix("gen-") }
    }

    func testAStagedCopyIsNotLiveUntilCommitted() throws {
        let store = RegisterStore(directory: directory)
        try store.save(zones: zones(), metadata: meta())
        let staged = try store.stage(zones: other(), metadata: meta())

        let before = try XCTUnwrap(store.load())
        XCTAssertNotNil(before.register.lookup(Coordinate(latitude: -41, longitude: 174)), "still the old copy")
        XCTAssertNil(before.register.lookup(Coordinate(latitude: -45, longitude: 170)))

        try store.commit(staged)
        let after = try XCTUnwrap(store.load())
        XCTAssertEqual(after.register.lookup(Coordinate(latitude: -45, longitude: 170))?.limit, 80)
        XCTAssertNil(after.register.lookup(Coordinate(latitude: -41, longitude: 174)))
    }

    func testCommitDeletesTheOldCopy() throws {
        let store = RegisterStore(directory: directory)
        try store.save(zones: zones(), metadata: meta())
        try store.save(zones: other(), metadata: meta())
        XCTAssertEqual(try generations().count, 1)
    }

    func testDiscardLeavesTheLiveCopyUntouched() throws {
        let store = RegisterStore(directory: directory)
        try store.save(zones: zones(), metadata: meta())
        let live = store.currentGeneration
        store.discard(try store.stage(zones: other(), metadata: meta()))
        XCTAssertEqual(store.currentGeneration, live)
        XCTAssertEqual(try generations().count, 1)
        XCTAssertEqual(try XCTUnwrap(store.load()).register.lookup(Coordinate(latitude: -41, longitude: 174))?.limit, 60)
    }

    func testAnInterruptedCopyIsIgnoredAndCleanedUp() throws {
        let store = RegisterStore(directory: directory)
        try store.save(zones: zones(), metadata: meta())
        // A crash mid-download: a folder with half a file, never pointed at.
        let stray = directory.appendingPathComponent("gen-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: stray, withIntermediateDirectories: true)
        try Data("half".utf8).write(to: stray.appendingPathComponent("register.lmtz"))

        XCTAssertEqual(try XCTUnwrap(store.load()).register.zoneCount, 1, "the live copy is unaffected")
        _ = try store.stage(zones: other(), metadata: meta())
        XCTAssertFalse(FileManager.default.fileExists(atPath: stray.path), "cleared on the next write")
    }

    func testADanglingPointerLoadsNothing() throws {
        let store = RegisterStore(directory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("gen-missing".utf8).write(to: directory.appendingPathComponent("current"))
        XCTAssertNil(try store.load())
    }

    func testAPointerCannotEscapeTheDirectory() throws {
        let store = RegisterStore(directory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("gen-../../x".utf8).write(to: directory.appendingPathComponent("current"))
        XCTAssertNil(store.currentGeneration)
    }

    func testClearRemovesEverything() throws {
        let store = RegisterStore(directory: directory)
        try store.save(zones: zones(), metadata: meta())
        try store.clear()
        XCTAssertNil(try store.load())
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: directory.path), [])
    }
}
