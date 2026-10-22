import Foundation

/// Learns when the source layer's data last changed, without downloading any of it.
public struct SourceEditCheck: Sendable {
    public var endpoint: RegisterEndpoint
    public var fetcher: HTTPFetching

    public init(endpoint: RegisterEndpoint = .nzta, fetcher: HTTPFetching = URLSessionFetcher()) {
        self.endpoint = endpoint
        self.fetcher = fetcher
    }

    public enum Result: Equatable, Sendable {
        case edited(Date)
        /// The layer answered but doesn't say when it last changed.
        case undated
        /// The layer couldn't be read.
        case unreachable
    }

    public func check() async -> Result {
        guard let data = try? await fetcher.data(from: endpoint.layerURL()) else { return .unreachable }
        return Self.editDate(in: data).map(Result.edited) ?? .undated
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

public enum ScheduledUpdate: Sendable {
    /// The schedule says it's too soon; no request was made.
    case notDue(until: Date)
    case ran(RegisterUpdateOutcome)
}

/// Brings the stored register up to date: a cheap check first, a full download only when the source changed.
public struct RegisterUpdater: Sendable {
    public var downloader: RegisterDownloader
    public var store: RegisterStore
    public var policy: RegisterVerificationPolicy
    public var schedule: SyncSchedule
    public var now: @Sendable () -> Date

    public init(downloader: RegisterDownloader = RegisterDownloader(), store: RegisterStore,
                policy: RegisterVerificationPolicy = .standard, schedule: SyncSchedule = .standard,
                now: @escaping @Sendable () -> Date = { Date() }) {
        self.downloader = downloader
        self.store = store
        self.policy = policy
        self.schedule = schedule
        self.now = now
    }

    /// Whether the schedule allows a request now. `userInitiated` is for a person asking, which skips the
    /// weekly wait and the back-off but not the short floor between attempts.
    public func decision(userInitiated: Bool = false) -> SyncSchedule.Decision {
        schedule.decision(attempts: store.loadAttempts(), lastSuccessAt: (try? store.loadMetadata())?.checkedAt,
                          now: now(), userInitiated: userInitiated)
    }

    /// Updates only if the schedule allows it. Everything that opens the app or taps Retry goes through here.
    public func updateIfDue(userInitiated: Bool = false, progress: @Sendable (Double?) -> Void = { _ in }) async throws -> ScheduledUpdate {
        if case .wait(let until) = decision(userInitiated: userInitiated) { return .notDue(until: until) }
        return .ran(try await update(progress: progress))
    }

    /// Updates now, whatever the schedule says, and records the attempt so the schedule can see it.
    public func update(progress: @Sendable (Double?) -> Void = { _ in }) async throws -> RegisterUpdateOutcome {
        var attempts = store.loadAttempts()
        attempts.lastAttemptAt = now()
        attempts.consecutiveFailures += 1
        store.saveAttempts(attempts)
        let outcome = try await perform(progress: progress)
        attempts.consecutiveFailures = 0
        store.saveAttempts(attempts)
        return outcome
    }

    private func perform(progress: @Sendable (Double?) -> Void) async throws -> RegisterUpdateOutcome {
        // Read before downloading: an edit that lands mid-download is then picked up by the next check.
        let check = await SourceEditCheck(endpoint: downloader.endpoint, fetcher: downloader.fetcher).check()
        let stored = try? store.loadMetadata()
        var latest: Date?
        switch check {
        case .edited(let date): latest = date
        case .undated: break
        // With a copy in hand, a source we can't even ask isn't worth a full download to find out.
        case .unreachable: if stored != nil { throw RegisterSyncError.sourceUnavailable }
        }

        if let stored, let storedEdit = stored.sourceEditedAt, let latest, latest <= storedEdit {
            try store.updateCheckedAt(now())
            var metadata = stored
            metadata.checkedAt = now()
            return .unchanged(metadata)
        }

        // Download, check, write beside the live copy, read it back, and only then switch. The copy in use
        // is untouched until the last step, so a cancelled, incomplete or bad download can't replace it.
        let downloaded = try await downloader.download(progress: progress)
        try Task.checkCancellation()
        if let rejection = RegisterVerifier.check(downloaded, current: try? store.loadMetadata(), policy: policy) {
            throw RegisterSyncError.rejected(rejection)
        }
        let metadata = RegisterMetadata(
            checkedAt: now(), zoneCount: downloaded.zones.count,
            sourceFeatureCount: downloaded.sourceFeatureCount, sourceEditedAt: latest)
        let staged = try store.stage(zones: downloaded.zones, metadata: metadata)
        guard store.verifyWritten(staged) else {
            store.discard(staged)
            throw RegisterSyncError.rejected(.writeMismatch)
        }
        if Task.isCancelled {
            store.discard(staged)
            throw CancellationError()
        }
        try store.commit(staged)
        return .downloaded(zones: downloaded.zones, metadata: staged.metadata)
    }
}
