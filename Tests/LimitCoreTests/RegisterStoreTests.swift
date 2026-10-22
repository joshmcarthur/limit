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
        try Data("junk".utf8).write(to: directory.appendingPathComponent("register.lmtz"))
        XCTAssertThrowsError(try store.load())
        try store.clear()
        XCTAssertNil(try store.load())
    }
}
