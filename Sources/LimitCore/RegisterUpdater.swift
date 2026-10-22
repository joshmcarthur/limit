import Foundation

/// Learns when the source layer's data last changed, without downloading any of it.
public struct SourceEditCheck: Sendable {
    public var endpoint: RegisterEndpoint
    public var fetcher: HTTPFetching

    public init(endpoint: RegisterEndpoint = .nzta, fetcher: HTTPFetching = URLSessionFetcher()) {
        self.endpoint = endpoint
        self.fetcher = fetcher
    }

    /// Nil if the layer couldn't be read or doesn't say.
    public func latestEdit() async -> Date? {
        guard let data = try? await fetcher.data(from: endpoint.layerURL()) else { return nil }
        return Self.editDate(in: data)
    }

    /// `editingInfo.dataLastEditDate` is milliseconds since 1970. Kept to whole seconds, because the stored
    /// metadata (ISO 8601) drops the fraction and a stored date would otherwise always look older.
    static func editDate(in data: Data) -> Date? {
        guard let layer = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let info = layer["editingInfo"] as? [String: Any],
              let millis = (info["dataLastEditDate"] as? NSNumber)?.doubleValue, millis > 0
        else { return nil }
        return Date(timeIntervalSince1970: (millis / 1000).rounded(.down))
    }
}

public enum RegisterUpdateOutcome: Sendable {
    /// The source hasn't changed since the stored copy, so nothing was downloaded.
    case unchanged(RegisterMetadata)
    case downloaded(zones: [SpeedZone], metadata: RegisterMetadata)
}

/// Brings the stored register up to date: a cheap check first, a full download only when the source changed.
public struct RegisterUpdater: Sendable {
    public var downloader: RegisterDownloader
    public var store: RegisterStore
    public var now: @Sendable () -> Date

    public init(downloader: RegisterDownloader = RegisterDownloader(), store: RegisterStore,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.downloader = downloader
        self.store = store
        self.now = now
    }

    public func update(progress: @Sendable (Double?) -> Void = { _ in }) async throws -> RegisterUpdateOutcome {
        // Read before downloading: an edit that lands mid-download is then picked up by the next check.
        let latest = await SourceEditCheck(endpoint: downloader.endpoint, fetcher: downloader.fetcher).latestEdit()

        if let stored = try? store.loadMetadata(), let storedEdit = stored.sourceEditedAt, let latest, latest <= storedEdit {
            try store.updateCheckedAt(now())
            var metadata = stored
            metadata.checkedAt = now()
            return .unchanged(metadata)
        }

        let downloaded = try await downloader.download(progress: progress)
        let metadata = RegisterMetadata(
            checkedAt: now(), zoneCount: downloaded.zones.count,
            sourceFeatureCount: downloaded.sourceFeatureCount, sourceEditedAt: latest)
        try store.save(zones: downloaded.zones, metadata: metadata)
        return .downloaded(zones: downloaded.zones, metadata: metadata)
    }
}
