import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum RegisterSyncError: Error, Equatable {
    case badResponse
    /// The source returned features but none carried a usable limit, so there's nothing to drive with.
    /// This is a data problem (wrong layer or field), not a network one.
    case noLimitsInSource(featureCount: Int)
    case emptySource
}

public protocol HTTPFetching: Sendable {
    func data(from url: URL) async throws -> Data
}

public struct URLSessionFetcher: HTTPFetching, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(from url: URL) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: url) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: RegisterSyncError.badResponse)
                }
            }
            task.resume()
        }
    }
}

/// The ArcGIS feature service query endpoint for the register.
public struct RegisterEndpoint: Equatable, Sendable {
    public var queryURL: URL
    public var pageSize: Int

    public init(queryURL: URL, pageSize: Int = 2_000) {
        self.queryURL = queryURL
        self.pageSize = pageSize
    }

    /// NZTA's speed limit zone layer. Check its licence and attribute as it requires on the About screen.
    public static let nzta = RegisterEndpoint(queryURL: URL(string:
        "https://services.arcgis.com/CXBb7LAjgIIdcsPt/ArcGIS/rest/services/SpeedLimitZoneFull__View/FeatureServer/0/query")!)

    /// The layer also holds superseded and expired records (about two thirds of it), so only zones with
    /// no `whenIneffective` date are requested.
    public static let inForce = "whenIneffective IS NULL"

    /// Only the fields the app reads; the layer's legal text fields are large.
    public static let outFields = ["speedLimitZoneId", "speedLimitZoneName", "speedLimitZoneValue"]

    public func pageURL(offset: Int) -> URL {
        url([
            ("where", Self.inForce), ("outFields", Self.outFields.joined(separator: ",")),
            ("returnGeometry", "true"), ("outSR", "4326"), ("geometryPrecision", "6"),
            // Without a stable order, paging by offset can skip or repeat records.
            ("orderByFields", "OBJECTID"),
            ("resultOffset", String(offset)), ("resultRecordCount", String(pageSize)),
            ("f", "pgeojson"),
        ])
    }

    public func countURL() -> URL {
        url([("where", Self.inForce), ("returnCountOnly", "true"), ("f", "json")])
    }

    private func url(_ items: [(String, String)]) -> URL {
        var components = URLComponents(url: queryURL, resolvingAgainstBaseURL: false)!
        components.queryItems = items.map { URLQueryItem(name: $0.0, value: $0.1) }
        return components.url!
    }
}

public struct DownloadedRegister: Sendable {
    public var zones: [SpeedZone]
    public var sourceFeatureCount: Int
}

/// Downloads every page of the register. Progress is 0...1, or nil if the total couldn't be learned.
public struct RegisterDownloader: Sendable {
    public var endpoint: RegisterEndpoint
    public var fetcher: HTTPFetching
    /// Extra attempts per request after the first.
    public var retries = 2
    private let maxPages = 5_000

    public init(endpoint: RegisterEndpoint = .nzta, fetcher: HTTPFetching = URLSessionFetcher()) {
        self.endpoint = endpoint
        self.fetcher = fetcher
    }

    public func download(progress: @Sendable (Double?) -> Void = { _ in }) async throws -> DownloadedRegister {
        let total = await totalCount()
        progress(total == nil ? nil : 0)

        var zones: [SpeedZone] = []
        var fetched = 0
        var offset = 0
        for _ in 0..<maxPages {
            let data = try await fetch(endpoint.pageURL(offset: offset))
            let page: ZoneParseResult
            do { page = try GeoJSONZoneParser.parse(data) } catch { throw RegisterSyncError.badResponse }

            if offset == 0, page.featureCount > 0, page.zones.isEmpty, page.skippedWithoutLimit == page.featureCount {
                throw RegisterSyncError.noLimitsInSource(featureCount: page.featureCount)
            }
            zones += page.zones
            fetched += page.featureCount
            offset += page.featureCount
            if let total, total > 0 {
                progress(min(Double(fetched) / Double(total), 1))
            } else {
                progress(nil)
            }

            if page.featureCount == 0 || (!page.exceededTransferLimit && page.featureCount < endpoint.pageSize) { break }
        }

        guard fetched > 0 else { throw RegisterSyncError.emptySource }
        guard !zones.isEmpty else { throw RegisterSyncError.noLimitsInSource(featureCount: fetched) }
        progress(1)
        return DownloadedRegister(zones: zones, sourceFeatureCount: fetched)
    }

    private func totalCount() async -> Int? {
        guard let data = try? await fetch(endpoint.countURL()),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let count = object["count"] as? Int
        else { return nil }
        return count
    }

    private func fetch(_ url: URL) async throws -> Data {
        var attempt = 0
        while true {
            do { return try await fetcher.data(from: url) } catch {
                if attempt >= retries { throw error }
                attempt += 1
            }
        }
    }
}
