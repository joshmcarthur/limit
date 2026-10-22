import Foundation
import Observation
import UIKit
import LimitCore

/// App-wide state: settings, the register and its sync, location and the current drive.
@MainActor
@Observable
final class AppModel {
    var settings: LimitSettings {
        didSet {
            persistSettings()
            engine.evaluator.setTolerance(settings.overTolerance)
            if !settings.showOnLockScreen { activity.end() } else if isDriving { activity.start(driveState.snapshot) }
        }
    }
    private(set) var driveState = DriveState.searching
    private(set) var syncState = SyncState.neverSynced
    private(set) var locationAccess = LocationAccess.notDetermined
    private(set) var isDriving = false

    @ObservationIgnored private var engine: DriveEngine
    @ObservationIgnored private let location = LocationService()
    @ObservationIgnored private let activity = DriveActivityController()
    @ObservationIgnored private let store: RegisterStore
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var isSyncing = false

    private static let settingsKey = "settings.v1"

    init() {
        let settings = LimitSettings.decode(UserDefaults.standard.data(forKey: Self.settingsKey))
        self.settings = settings
        self.engine = DriveEngine(tolerance: settings.overTolerance)

        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        store = RegisterStore(directory: support.appendingPathComponent("Register", isDirectory: true))
        loadStoredRegister()

        locationAccess = location.access
        location.onSample = { [weak self] sample in self?.handle(sample) }
        location.onAccessChange = { [weak self] access in self?.locationAccess = access }
    }

    // MARK: Lifecycle

    /// Call when the app becomes active.
    func didBecomeActive() {
        locationAccess = location.access
        if settings.hasCompletedOnboarding, !isDriving, locationAccess.isUsable { beginDrive() }
        if syncNeeded { syncRegister() }
    }

    func requestLocationAccess() {
        location.requestAuthorisation()
    }

    func finishOnboarding() {
        settings.hasCompletedOnboarding = true
        if locationAccess.isUsable { beginDrive() }
        if syncNeeded { syncRegister() }
    }

    // MARK: Drive

    func beginDrive() {
        guard !isDriving else { return }
        isDriving = true
        UIApplication.shared.isIdleTimerDisabled = true
        location.start()
        if settings.showOnLockScreen { activity.start(driveState.snapshot) }
        ticker = Task { [weak self] in
            // Age out a stalled GPS so the display shows "–" rather than a frozen number.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.refresh()
            }
        }
    }

    func endDrive() {
        guard isDriving else { return }
        isDriving = false
        UIApplication.shared.isIdleTimerDisabled = false
        ticker?.cancel()
        ticker = nil
        location.stop()
        activity.end()
        _ = engine.state(now: .distantFuture)
        driveState = .searching
    }

    private func handle(_ sample: LocationSample) {
        guard isDriving else { return }
        apply(engine.ingest(sample))
    }

    private func refresh() {
        guard isDriving else { return }
        apply(engine.state())
    }

    private func apply(_ state: DriveState) {
        guard state != driveState else { return }
        driveState = state
        if settings.showOnLockScreen { activity.update(state.snapshot) }
    }

    // MARK: Register

    private var syncNeeded: Bool {
        switch syncState {
        case .neverSynced, .failed: return true
        case .stale: return true
        case .upToDate(let at): return Date().timeIntervalSince(at) > 86_400
        case .updating: return false
        }
    }

    private func loadStoredRegister() {
        do {
            if let stored = try store.load() {
                engine.register = stored.register
                engine.registerCheckedAt = stored.metadata.checkedAt
                syncState = .resting(checkedAt: stored.metadata.checkedAt, now: Date())
            }
        } catch {
            try? store.clear()
        }
    }

    func syncRegister() {
        guard !isSyncing else { return }
        isSyncing = true
        syncState = .updating(progress: nil)
        let store = store
        Task {
            defer { isSyncing = false }
            do {
                let (register, metadata) = try await Self.download(into: store) { progress in
                    Task { @MainActor [weak self] in self?.syncState = .updating(progress: progress) }
                }
                engine.register = register
                engine.registerCheckedAt = metadata.checkedAt
                syncState = .upToDate(checkedAt: metadata.checkedAt)
            } catch {
                syncState = .failed(lastChecked: engine.registerCheckedAt)
            }
        }
    }

    private nonisolated static func download(
        into store: RegisterStore,
        progress: @escaping @Sendable (Double?) -> Void
    ) async throws -> (SpeedLimitRegister, RegisterMetadata) {
        let downloaded = try await RegisterDownloader().download(progress: progress)
        let metadata = RegisterMetadata(
            checkedAt: Date(), zoneCount: downloaded.zones.count, sourceFeatureCount: downloaded.sourceFeatureCount)
        try store.save(zones: downloaded.zones, metadata: metadata)
        return (SpeedLimitRegister(zones: downloaded.zones), metadata)
    }

    // MARK: Settings

    private func persistSettings() {
        UserDefaults.standard.set(settings.encoded(), forKey: Self.settingsKey)
    }
}
