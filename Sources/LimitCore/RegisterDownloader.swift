import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum RegisterSyncError: Error, Equatable {
    case badResponse
    /// The source said it is busy or limiting us (429 or 503). The sync stops rather than trying again.
    case sourceBusy
    /// The source refused the request (another 4xx). Asking again won't change the answer.
    case requestRefused(status: Int)
    /// The source can't be reached to see whether anything changed, so nothing was downloaded.
    case sourceUnavailable
    /// The source returned features but none carried a usable limit, so there's nothing to drive with.
    /// This is a data problem (wrong layer or field), not a network one.
    case noLimitsInSource(featureCount: Int)
    case emptySource
    /// The download finished but failed a check, so the register in use was kept.
    case rejected(RegisterRejection)
}

public protocol HTTPFetching: Sendable {
    func data(from url: URL) async throws -> Data
}

public struct URLSessionFetcher: HTTPFetching, @unchecked Sendable {
    private let session: URLSession
    private let userAgent: String

    public init(session: URLSession = .shared, userAgent: String = LimitCore.userAgent) {
        self.session = session
        self.userAgent = userAgent
    }

    public func data(from url: URL) async throws -> Data {
        var request = URLRequest(url: url)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        return try await withCheckedThrowingContinuation { continuation in
            let task = session.dataTask(with: request) { data, response, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode), let data {
                    continuation.resume(returning: data)
                } else if let http = response as? HTTPURLResponse {
                    continuation.resume(throwing: Self.error(forStatus: http.statusCode))
                } else {
                    continuation.resume(throwing: RegisterSyncError.badResponse)
                }
            }
            task.resume()
        }
    }

    static func error(forStatus status: Int) -> RegisterSyncError {
        switch status {
        case 429, 503: return .sourceBusy
        case 400..<500: return .requestRefused(status: status)
        default: return .badResponse
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
    public static let outFields = [
        "speedLimitZoneId", "speedLimitZoneName", "speedLimitZoneValue",
        "speedLimitZoneVariableSpeed", "speedLimitZoneVarPrdDesc",
    ]

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

    /// The layer's description. Small (about 5 KB compressed), and it carries when the data last changed.
    public func layerURL() -> URL {
        var components = URLComponents(url: queryURL, resolvingAgainstBaseURL: false)!
        components.path = String(components.path.dropLast(queryURL.lastPathComponent.count + 1))
        components.queryItems = [URLQueryItem(name: "f", value: "json")]
        return components.url!
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
    /// How many records the source said it had when the download began; nil if it couldn't be learned.
    public var expectedFeatureCount: Int?
}

/// Downloads every page of the register. Progress is 0...1, or nil if the total couldn't be learned.
public struct RegisterDownloader: Sendable {
    public var endpoint: RegisterEndpoint
    public var fetcher: HTTPFetching
    /// Extra attempts per request after the first. Each waits four times as long as the last (1 s, 4 s),
    /// and a busy or refusing source is never retried.
    public var retries = 2
    public var sleep: @Sendable (TimeInterval) async throws -> Void = { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) }
    private let maxPages = 5_000

    public init(endpoint: RegisterEndpoint = .nzta, fetcher: HTTPFetching = URLSessionFetcher()) {
        self.endpoint = endpoint
        self.fetcher = fetcher
    }

    public func download(progress: @Sendable (Double?) -> Void = { _ in }) async throws -> DownloadedRegister {
        let total = try await totalCount()
        progress(total == nil ? nil : 0)

        var zones: [SpeedZone] = []
        var fetched = 0
        var offset = 0
        for _ in 0..<maxPages {
            try Task.checkCancellation()
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
        return DownloadedRegister(zones: ZoneDeduplicator.unique(zones), sourceFeatureCount: fetched, expectedFeatureCount: total)
    }

    /// Nil if the count can't be learned; a source that is busy or refusing us stops the sync here instead.
    private func totalCount() async throws -> Int? {
        let data: Data
        do { data = try await fetch(endpoint.countURL()) } catch { if Self.isFinal(error) { throw error }; return nil }
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let count = object["count"] as? Int
        else { return nil }
        return count
    }

    private func fetch(_ url: URL) async throws -> Data {
        var attempt = 0
        while true {
            do { return try await fetcher.data(from: url) } catch {
                if attempt >= retries || Self.isFinal(error) { throw error }
                try await sleep(pow(4, Double(attempt)))
                attempt += 1
            }
        }
    }

    private static func isFinal(_ error: Error) -> Bool {
        switch error as? RegisterSyncError {
        case .sourceBusy?, .requestRefused?: return true
        default: return error is CancellationError
        }
    }
}
