import XCTest
@testable import LimitCore

private final class Source: HTTPFetching, @unchecked Sendable {
    private let lock = NSLock()
    private var _requests: [URL] = []
    var editedAtMillis: Int? = 1_700_000_000_000
    var layerFails = false
    /// Zones served, each with its own id so none are dropped as repeats.
    var records = 1
    /// What the count query says; defaults to `records`.
    var reportedCount: Int?

    var requests: [URL] { lock.lock(); defer { lock.unlock() }; return _requests }
    var pageRequests: Int { requests.filter { $0.absoluteString.contains("resultOffset") }.count }

    func data(from url: URL) async throws -> Data {
        lock.lock(); _requests.append(url); lock.unlock()
        let s = url.absoluteString
        if s.contains("returnCountOnly") { return Data("{\"count\":\(reportedCount ?? records)}".utf8) }
        if s.contains("resultOffset") {
            let features = (0..<records).map { i in
                """
                {"type":"Feature","properties":{"speedLimitZoneId":"z\(i)","speedLimitZoneValue":"50"},
                 "geometry":{"type":"Polygon","coordinates":[[[174,-41],[175,-41],[175,-40],[174,-40],[174,-41]]]}}
                """
            }.joined(separator: ",")
            return Data("""
            {"type":"FeatureCollection","properties":{"exceededTransferLimit":false},"features":[\(features)]}
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

    /// Small data sets in these tests, so the national-size floor is lowered unless a test sets its own.
    private func updater(_ source: Source, at now: Date, policy: RegisterVerificationPolicy = .init(minimumZones: 1)) -> RegisterUpdater {
        let endpoint = RegisterEndpoint(queryURL: URL(string: "https://example.test/FeatureServer/0/query")!, pageSize: 1_000)
        return RegisterUpdater(
            downloader: RegisterDownloader(endpoint: endpoint, fetcher: source),
            store: RegisterStore(directory: directory), policy: policy, now: { now })
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

    func testUnreadableLayerWithACopyDoesNotDownload() async throws {
        let source = Source()
        _ = try await updater(source, at: Date(timeIntervalSince1970: 100)).update()
        let pagesBefore = source.pageRequests
        source.layerFails = true
        do {
            _ = try await updater(source, at: Date(timeIntervalSince1970: 200)).update()
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? RegisterSyncError, .sourceUnavailable)
        }
        XCTAssertEqual(source.pageRequests, pagesBefore, "a source we can't ask is not asked for everything")
        XCTAssertEqual(try liveZoneCount(), 1)
    }

    func testUnreadableLayerWithNoCopyStillDownloads() async throws {
        let source = Source()
        source.layerFails = true
        let outcome = try await updater(source, at: Date(timeIntervalSince1970: 100)).update()
        guard case .downloaded(_, let metadata) = outcome else { return XCTFail("expected a download") }
        XCTAssertNil(metadata.sourceEditedAt)
    }

    func testALayerWithNoEditDateDownloadsAgain() async throws {
        let source = Source()
        _ = try await updater(source, at: Date(timeIntervalSince1970: 100)).update()
        source.editedAtMillis = nil
        let outcome = try await updater(source, at: Date(timeIntervalSince1970: 200)).update()
        guard case .downloaded = outcome else { return XCTFail("expected a download") }
    }

    func testCopySavedWithoutASourceEditDownloadsAgain() async throws {
        let source = Source()
        try RegisterStore(directory: directory).save(
            zones: [], metadata: RegisterMetadata(checkedAt: Date(), zoneCount: 0, sourceFeatureCount: 0))
        let outcome = try await updater(source, at: Date()).update()
        guard case .downloaded = outcome else { return XCTFail("expected a download") }
    }

    func testOldMetadataFilesStillDecode() throws {
        let generation = directory.appendingPathComponent("gen-old")
        try FileManager.default.createDirectory(at: generation, withIntermediateDirectories: true)
        try Data("{\"checkedAt\":\"2026-10-01T00:00:00Z\",\"zoneCount\":2,\"sourceFeatureCount\":3}".utf8)
            .write(to: generation.appendingPathComponent("register.json"))
        try Data("gen-old".utf8).write(to: directory.appendingPathComponent("current"))
        let metadata = try XCTUnwrap(RegisterStore(directory: directory).loadMetadata())
        XCTAssertNil(metadata.sourceEditedAt)
        XCTAssertEqual(metadata.zoneCount, 2)
    }

    // MARK: Schedule

    private let week: TimeInterval = 7 * 86_400

    private func ran(_ scheduled: ScheduledUpdate) -> RegisterUpdateOutcome? {
        if case .ran(let outcome) = scheduled { return outcome }
        return nil
    }

    func testAutomaticChecksWaitAWeekAndThenCostOnlyTheLayerRequest() async throws {
        let source = Source()
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        let first = try await updater(source, at: t0).updateIfDue()
        XCTAssertNotNil(ran(first), "first run goes straight away")
        let requestsAfterFirst = source.requests.count

        // Opening the app any number of times inside the week makes no request at all.
        for hours in [1.0, 24, 100, 167] {
            let scheduled = try await updater(source, at: t0.addingTimeInterval(hours * 3_600)).updateIfDue()
            guard case .notDue(let until) = scheduled else { return XCTFail("expected to wait at \(hours) h") }
            XCTAssertEqual(until, t0.addingTimeInterval(week))
        }
        XCTAssertEqual(source.requests.count, requestsAfterFirst)

        // After a week: one cheap layer request, and no download because nothing changed.
        let weekLater = try await updater(source, at: t0.addingTimeInterval(week)).updateIfDue()
        let outcome = try XCTUnwrap(ran(weekLater))
        guard case .unchanged = outcome else { return XCTFail("expected no download") }
        XCTAssertEqual(source.requests.count, requestsAfterFirst + 1)
        XCTAssertEqual(source.pageRequests, 1)
    }

    func testFailuresBackOffAndSurviveARelaunch() async throws {
        let source = Source()
        source.layerFails = true
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        // No copy yet, so the first attempt downloads blind; make that fail by returning nothing usable.
        source.records = 0
        _ = try? await updater(source, at: t0, policy: .standard).updateIfDue()
        XCTAssertEqual(RegisterStore(directory: directory).loadAttempts().consecutiveFailures, 1)

        let requests = source.requests.count
        guard case .notDue(let until) = try await updater(source, at: t0.addingTimeInterval(60)).updateIfDue() else {
            return XCTFail("expected to back off")
        }
        XCTAssertEqual(until, t0.addingTimeInterval(15 * 60))
        XCTAssertEqual(source.requests.count, requests)

        _ = try? await updater(source, at: t0.addingTimeInterval(15 * 60), policy: .standard).updateIfDue()
        guard case .notDue(let second) = try await updater(source, at: t0.addingTimeInterval(16 * 60)).updateIfDue() else {
            return XCTFail("expected a longer back-off")
        }
        XCTAssertEqual(second, t0.addingTimeInterval(15 * 60 + 3_600))
    }

    func testARejectedDownloadBacksOffLikeAnyOtherFailure() async throws {
        let source = Source()
        source.records = 10
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        _ = try await updater(source, at: t0).updateIfDue()
        source.records = 3
        source.editedAtMillis! += 60_000
        let t1 = t0.addingTimeInterval(week)
        _ = try? await updater(source, at: t1).updateIfDue()
        let pages = source.pageRequests
        guard case .notDue = try await updater(source, at: t1.addingTimeInterval(60)).updateIfDue() else {
            return XCTFail("expected to back off after a rejection")
        }
        XCTAssertEqual(source.pageRequests, pages, "no second full download while the source is broken")
    }

    func testManualChecksSkipTheWeeklyWaitButNotTheFloor() async throws {
        let source = Source()
        let t0 = Date(timeIntervalSince1970: 1_000_000)
        _ = try await updater(source, at: t0).updateIfDue()

        let tooSoon = try await updater(source, at: t0.addingTimeInterval(60)).updateIfDue(userInitiated: true)
        guard case .notDue(let until) = tooSoon else { return XCTFail("expected the floor to hold") }
        XCTAssertEqual(until, t0.addingTimeInterval(5 * 60))

        let allowed = try await updater(source, at: t0.addingTimeInterval(5 * 60)).updateIfDue(userInitiated: true)
        let outcome = try XCTUnwrap(ran(allowed))
        guard case .unchanged = outcome else { return XCTFail("expected a cheap check, not a download") }
    }

    func testAttemptsSurviveClearingAndStagedWrites() throws {
        let store = RegisterStore(directory: directory)
        store.saveAttempts(SyncAttempts(lastAttemptAt: Date(timeIntervalSince1970: 100), consecutiveFailures: 2))
        try store.save(zones: [], metadata: RegisterMetadata(checkedAt: Date(), zoneCount: 0, sourceFeatureCount: 0))
        XCTAssertEqual(store.loadAttempts().consecutiveFailures, 2)
        try store.clear()
        XCTAssertEqual(store.loadAttempts().consecutiveFailures, 2)
    }

    // MARK: Verification gate

    private func liveZoneCount() throws -> Int? {
        try RegisterStore(directory: directory).load()?.register.zoneCount
    }

    private func rejection(_ block: () async throws -> Void) async -> RegisterRejection? {
        do { try await block() } catch let error as RegisterSyncError {
            if case .rejected(let reason) = error { return reason }
        } catch {}
        return nil
    }

    func testAShrunkenSourceDoesNotReplaceTheLiveCopy() async throws {
        let source = Source()
        source.records = 10
        _ = try await updater(source, at: Date(timeIntervalSince1970: 100)).update()
        XCTAssertEqual(try liveZoneCount(), 10)

        source.records = 3               // the source is mid-rebuild
        source.editedAtMillis! += 60_000
        let reason = await rejection { _ = try await updater(source, at: Date(timeIntervalSince1970: 200)).update() }
        XCTAssertEqual(reason, .muchSmaller(count: 3, current: 10))
        XCTAssertEqual(try liveZoneCount(), 10, "the old copy is still live")
        XCTAssertEqual(try RegisterStore(directory: directory).loadMetadata()?.checkedAt, Date(timeIntervalSince1970: 100))
    }

    func testAnIncompleteDownloadIsRejected() async throws {
        let source = Source()
        source.records = 10
        source.reportedCount = 100        // the source says 100, only 10 came back
        let reason = await rejection { _ = try await updater(source, at: Date()).update() }
        XCTAssertEqual(reason, .incomplete(fetched: 10, expected: 100))
        XCTAssertNil(try liveZoneCount(), "nothing was written")
    }

    func testTooFewZonesIsRejectedEvenWithNothingToReplace() async throws {
        let source = Source()
        source.records = 4
        let reason = await rejection { _ = try await updater(source, at: Date(), policy: .standard).update() }
        XCTAssertEqual(reason, .tooFewZones(count: 4, minimum: 12_000))
        XCTAssertNil(try liveZoneCount())
    }

    func testARejectedDownloadLeavesNoStrayFolders() async throws {
        let source = Source()
        source.records = 4
        _ = await rejection { _ = try await updater(source, at: Date(), policy: .standard).update() }
        let leftovers = (try? FileManager.default.contentsOfDirectory(atPath: directory.path)) ?? []
        XCTAssertTrue(leftovers.filter { $0.hasPrefix("gen-") }.isEmpty)
    }

    func testAnUnreportedCountCannotShowIncompleteButTheOtherChecksStillApply() async throws {
        let source = Source()
        source.records = 4
        source.reportedCount = nil
        let reason = await rejection { _ = try await updater(source, at: Date(), policy: .standard).update() }
        XCTAssertEqual(reason, .tooFewZones(count: 4, minimum: 12_000))
    }

    func testACancelledDownloadNeverSwaps() async throws {
        let source = Source()
        source.records = 10
        _ = try await updater(source, at: Date(timeIntervalSince1970: 100)).update()
        source.records = 12
        source.editedAtMillis! += 60_000

        let task = Task { try await updater(source, at: Date(timeIntervalSince1970: 200)).update() }
        task.cancel()
        do { _ = try await task.value; XCTFail("expected cancellation") } catch is CancellationError {} catch {
            XCTFail("unexpected \(error)")
        }
        XCTAssertEqual(try liveZoneCount(), 10)
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path).filter { $0.hasPrefix("gen-") }
        XCTAssertEqual(leftovers.count, 1)
    }

    /// A real clock has fractions of a second, which the stored metadata drops; that must not look like a bad write.
    func testARealClockTimeStillPassesTheReadBack() async throws {
        let source = Source()
        source.records = 10
        let outcome = try await updater(source, at: Date(timeIntervalSince1970: 100.987)).update()
        guard case .downloaded(_, let metadata) = outcome else { return XCTFail("expected a download") }
        XCTAssertEqual(metadata.checkedAt, Date(timeIntervalSince1970: 100))
    }

    func testAGoodDownloadReplacesTheLiveCopy() async throws {
        let source = Source()
        source.records = 10
        _ = try await updater(source, at: Date(timeIntervalSince1970: 100)).update()
        source.records = 9               // 90% of the old size is fine
        source.editedAtMillis! += 60_000
        _ = try await updater(source, at: Date(timeIntervalSince1970: 200)).update()
        XCTAssertEqual(try liveZoneCount(), 9)
    }
}
