import XCTest
@testable import LimitCore

private final class Source: HTTPFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URL] = []
    var editedAtMillis: Int? = 1_700_000_000_000
    var layerFails = false

    var requests: [URL] { lock.lock(); defer { lock.unlock() }; return _requests }
    var pageRequests: Int { requests.filter { $0.absoluteString.contains("resultOffset") }.count }

    func data(from url: URL) async throws -> Data {
        lock.lock(); _requests.append(url); lock.unlock()
        let s = url.absoluteString
        if s.contains("returnCountOnly") { return Data("{\"count\":1}".utf8) }
        if s.contains("resultOffset") {
            return Data("""
            {"type":"FeatureCollection","properties":{"exceededTransferLimit":false},"features":[
            {"type":"Feature","properties":{"speedLimitZoneId":"a","speedLimitZoneValue":"50"},
             "geometry":{"type":"Polygon","coordinates":[[[174,-41],[175,-41],[175,-40],[174,-40],[174,-41]]]}}]}
            """.utf8)
        }
        if layerFails { throw RegisterSyncError.badResponse }
        let editing = editedAtMillis.map { "\"editingInfo\":{\"dataLastEditDate\":\($0)}," } ?? ""
        return Data("{\(editing)\"name\":\"layer\"}".utf8)
    }
}

final class RegisterUpdaterTests: XCTestCase {
    private var directory: URL!

    override func setUp() {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
    }

    private func updater(_ source: Source, at now: Date) -> RegisterUpdater {
        let endpoint = RegisterEndpoint(queryURL: URL(string: "https://example.test/FeatureServer/0/query")!, pageSize: 10)
        return RegisterUpdater(
            downloader: RegisterDownloader(endpoint: endpoint, fetcher: source),
            store: RegisterStore(directory: directory), now: { now })
    }

    func testLayerURLIsTheLayerNotTheQuery() {
        let endpoint = RegisterEndpoint(queryURL: URL(string: "https://example.test/FeatureServer/0/query")!)
        XCTAssertEqual(endpoint.layerURL().absoluteString, "https://example.test/FeatureServer/0?f=json")
    }

    func testEditDateParsing() {
        XCTAssertEqual(SourceEditCheck.editDate(in: Data("{\"editingInfo\":{\"dataLastEditDate\":1792637751497}}".utf8)),
                       Date(timeIntervalSince1970: 1_792_637_751))
        XCTAssertNil(SourceEditCheck.editDate(in: Data("{\"name\":\"x\"}".utf8)))
        XCTAssertNil(SourceEditCheck.editDate(in: Data("{\"editingInfo\":{}}".utf8)))
        XCTAssertNil(SourceEditCheck.editDate(in: Data("not json".utf8)))
    }

    /// Found on the live layer: the source date has milliseconds, the stored copy only seconds.
    func testASourceDateWithMillisecondsIsStillUnchangedNextTime() async throws {
        let source = Source()
        source.editedAtMillis = 1_700_000_000_497
        _ = try await updater(source, at: Date(timeIntervalSince1970: 100)).update()
        let outcome = try await updater(source, at: Date(timeIntervalSince1970: 200)).update()
        guard case .unchanged = outcome else { return XCTFail("expected no download") }
    }

    func testFirstRunDownloadsAndRemembersTheSourceEdit() async throws {
        let source = Source()
        let outcome = try await updater(source, at: Date(timeIntervalSince1970: 100)).update()
        guard case .downloaded(let zones, let metadata) = outcome else { return XCTFail("expected a download") }
        XCTAssertEqual(zones.count, 1)
        XCTAssertEqual(metadata.sourceEditedAt, Date(timeIntervalSince1970: 1_700_000_000))
        XCTAssertEqual(try RegisterStore(directory: directory).loadMetadata()?.sourceEditedAt, metadata.sourceEditedAt)
    }

    func testUnchangedSourceSkipsTheDownloadButRefreshesTheCheckedDate() async throws {
        let source = Source()
        _ = try await updater(source, at: Date(timeIntervalSince1970: 100)).update()
        let pagesAfterFirst = source.pageRequests

        let outcome = try await updater(source, at: Date(timeIntervalSince1970: 5_000)).update()
        guard case .unchanged(let metadata) = outcome else { return XCTFail("expected no download") }
        XCTAssertEqual(source.pageRequests, pagesAfterFirst)
        XCTAssertEqual(metadata.checkedAt, Date(timeIntervalSince1970: 5_000))
        XCTAssertEqual(try RegisterStore(directory: directory).loadMetadata()?.checkedAt, Date(timeIntervalSince1970: 5_000))
        XCTAssertEqual(try RegisterStore(directory: directory).load()?.register.zoneCount, 1)
    }

    func testNewerSourceDownloadsAgain() async throws {
        let source = Source()
        _ = try await updater(source, at: Date(timeIntervalSince1970: 100)).update()
        source.editedAtMillis! += 60_000
        let outcome = try await updater(source, at: Date(timeIntervalSince1970: 200)).update()
        guard case .downloaded(_, let metadata) = outcome else { return XCTFail("expected a download") }
        XCTAssertEqual(metadata.sourceEditedAt, Date(timeIntervalSince1970: 1_700_000_060))
    }

    func testUnreadableLayerFallsBackToDownloading() async throws {
        let source = Source()
        _ = try await updater(source, at: Date(timeIntervalSince1970: 100)).update()
        source.layerFails = true
        let outcome = try await updater(source, at: Date(timeIntervalSince1970: 200)).update()
        guard case .downloaded(_, let metadata) = outcome else { return XCTFail("expected a download") }
        XCTAssertNil(metadata.sourceEditedAt)
    }

    func testCopySavedWithoutASourceEditDownloadsAgain() async throws {
        let source = Source()
        try RegisterStore(directory: directory).save(
            zones: [], metadata: RegisterMetadata(checkedAt: Date(), zoneCount: 0, sourceFeatureCount: 0))
        let outcome = try await updater(source, at: Date()).update()
        guard case .downloaded = outcome else { return XCTFail("expected a download") }
    }

    func testOldMetadataFilesStillDecode() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{\"checkedAt\":\"2026-10-01T00:00:00Z\",\"zoneCount\":2,\"sourceFeatureCount\":3}".utf8)
            .write(to: directory.appendingPathComponent("register.json"))
        let metadata = try XCTUnwrap(RegisterStore(directory: directory).loadMetadata())
        XCTAssertNil(metadata.sourceEditedAt)
        XCTAssertEqual(metadata.zoneCount, 2)
    }
}
