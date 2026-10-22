import XCTest
@testable import LimitCore

private struct ClosureFetcher: HTTPFetching {
    let handler: @Sendable (URL) throws -> Data
    func data(from url: URL) async throws -> Data { try handler(url) }
}

private final class Recorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [Double?] = []
    func add(_ v: Double?) { lock.lock(); values.append(v); lock.unlock() }
    var all: [Double?] { lock.lock(); defer { lock.unlock() }; return values }
}

final class RegisterDownloaderTests: XCTestCase {
    private let square = "[[[174,-41],[175,-41],[175,-40],[174,-40],[174,-41]]]"

    private func feature(_ limit: Int?, name: String = "X") -> String {
        let limitProp = limit.map { ",\"speedLimit\":\($0)" } ?? ""
        return """
        {"type":"Feature","properties":{"speedLimitZoneName":"\(name)"\(limitProp)},"geometry":{"type":"Polygon","coordinates":\(square)}}
        """
    }

    private func page(_ features: [String], exceeded: Bool) -> Data {
        Data("""
        {"type":"FeatureCollection","properties":{"exceededTransferLimit":\(exceeded)},"features":[\(features.joined(separator: ","))]}
        """.utf8)
    }

    private func offset(of url: URL) -> Int {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Int(items.first { $0.name == "resultOffset" }?.value ?? "") ?? -1
    }

    private func isCount(_ url: URL) -> Bool {
        (URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []).contains { $0.name == "returnCountOnly" }
    }

    private let endpoint = RegisterEndpoint(queryURL: URL(string: "https://example.test/query")!, pageSize: 2)

    func testEndpointURLs() {
        let url = endpoint.pageURL(offset: 4)
        let items = Dictionary(uniqueKeysWithValues: URLComponents(url: url, resolvingAgainstBaseURL: false)!.queryItems!.map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(items["resultOffset"], "4")
        XCTAssertEqual(items["resultRecordCount"], "2")
        XCTAssertEqual(items["f"], "pgeojson")
        XCTAssertEqual(items["where"], "whenIneffective IS NULL")
        XCTAssertEqual(items["orderByFields"], "OBJECTID")
        XCTAssertEqual(items["outFields"], "speedLimitZoneId,speedLimitZoneName,speedLimitZoneValue")
        XCTAssertEqual(items["outSR"], "4326")
        let count = URLComponents(url: endpoint.countURL(), resolvingAgainstBaseURL: false)!.queryItems!
        XCTAssertTrue(count.contains(URLQueryItem(name: "returnCountOnly", value: "true")))
        XCTAssertTrue(count.contains(URLQueryItem(name: "where", value: "whenIneffective IS NULL")))
    }

    func testRepeatedRecordsAreDroppedFromTheDownload() async throws {
        let repeated = """
        {"type":"Feature","properties":{"speedLimitZoneId":"z1","speedLimitZoneValue":"30"},"geometry":{"type":"Polygon","coordinates":\(square)}}
        """
        let fetcher = ClosureFetcher { [self] url in
            isCount(url) ? Data("{\"count\":3}".utf8) : page([repeated, repeated, repeated], exceeded: false)
        }
        let wide = RegisterEndpoint(queryURL: endpoint.queryURL, pageSize: 10)
        let result = try await RegisterDownloader(endpoint: wide, fetcher: fetcher).download()
        XCTAssertEqual(result.zones.count, 1)
        XCTAssertEqual(result.sourceFeatureCount, 3)
    }

    func testPagesUntilTheSourceStopsExceeding() async throws {
        let fetcher = ClosureFetcher { [self] url in
            if isCount(url) { return Data("{\"count\":5}".utf8) }
            switch offset(of: url) {
            case 0: return page([feature(50), feature(60)], exceeded: true)
            case 2: return page([feature(30), feature(40)], exceeded: true)
            case 4: return page([feature(100)], exceeded: false)
            default: XCTFail("unexpected offset"); return page([], exceeded: false)
            }
        }
        let recorder = Recorder()
        let result = try await RegisterDownloader(endpoint: endpoint, fetcher: fetcher).download { recorder.add($0) }
        XCTAssertEqual(result.zones.map(\.limit), [50, 60, 30, 40, 100])
        XCTAssertEqual(result.sourceFeatureCount, 5)
        XCTAssertEqual(recorder.all.last ?? nil, 1)
        XCTAssertEqual(recorder.all.first ?? 99, 0)
    }

    func testProgressIsNilWhenCountUnavailable() async throws {
        let fetcher = ClosureFetcher { [self] url in
            if isCount(url) { throw URLError(.notConnectedToInternet) }
            return page([feature(50)], exceeded: false)
        }
        var downloader = RegisterDownloader(endpoint: endpoint, fetcher: fetcher)
        downloader.retries = 0
        let recorder = Recorder()
        _ = try await downloader.download { recorder.add($0) }
        XCTAssertNil(recorder.all.first ?? 0)
    }

    func testSourceWithoutLimitsFailsFastAndHonestly() async {
        let fetcher = ClosureFetcher { [self] url in
            if isCount(url) { return Data("{\"count\":99999}".utf8) }
            XCTAssertEqual(offset(of: url), 0, "should stop after the first page")
            return page([feature(nil), feature(nil)], exceeded: true)
        }
        do {
            _ = try await RegisterDownloader(endpoint: endpoint, fetcher: fetcher).download()
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? RegisterSyncError, .noLimitsInSource(featureCount: 2))
        }
    }

    func testEmptySource() async {
        let fetcher = ClosureFetcher { [self] url in
            isCount(url) ? Data("{\"count\":0}".utf8) : page([], exceeded: false)
        }
        do {
            _ = try await RegisterDownloader(endpoint: endpoint, fetcher: fetcher).download()
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? RegisterSyncError, .emptySource)
        }
    }

    func testArcGISErrorBodyIsABadResponse() async {
        let fetcher = ClosureFetcher { url in
            Data("{\"error\":{\"code\":400,\"message\":\"Invalid\"}}".utf8)
        }
        do {
            _ = try await RegisterDownloader(endpoint: endpoint, fetcher: fetcher).download()
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? RegisterSyncError, .badResponse)
        }
    }

    func testRetriesTransientFailures() async throws {
        final class Counter: @unchecked Sendable { var n = 0 }
        let counter = Counter()
        let fetcher = ClosureFetcher { [self] url in
            if isCount(url) { return Data("{\"count\":1}".utf8) }
            counter.n += 1
            if counter.n < 3 { throw URLError(.timedOut) }
            return page([feature(50)], exceeded: false)
        }
        let wide = RegisterEndpoint(queryURL: endpoint.queryURL, pageSize: 10)
        let result = try await RegisterDownloader(endpoint: wide, fetcher: fetcher).download()
        XCTAssertEqual(result.zones.count, 1)
        XCTAssertEqual(counter.n, 3)
    }
}
