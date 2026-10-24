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
            if settings.suggestEndingDrive != oldValue.suggestEndingDrive { suggestingEndChanged() }
            if !settings.showOnLockScreen { activity.end() } else if isDriving { activity.start(driveState.snapshot) }
        }
    }
    private(set) var driveState = DriveState.searching
    private(set) var syncStatus = SyncStatus()
    private(set) var locationAccess = LocationAccess.notDetermined
    private(set) var isDriving = false

    @ObservationIgnored private var engine: DriveEngine
    @ObservationIgnored private let location = LocationService()
    @ObservationIgnored private let activity = DriveActivityController()
    @ObservationIgnored private let motion = MotionService()
    @ObservationIgnored private let stopNotifier = StopNotifier()
    @ObservationIgnored private var stopDetector = DriveStopDetector()
    @ObservationIgnored private let store: RegisterStore
    @ObservationIgnored private var ticker: Task<Void, Never>?
    @ObservationIgnored private var syncTask: Task<Void, Never>?

    /// What the sync row and the drive screen's footer show, worked out from the status each time it's read.
    var syncState: SyncState { syncStatus.state(now: Date()) }

    private static let settingsKey = "settings.v1"
    private static let driveEndedByDriverKey = "drive.endedByDriver"

    /// Kept apart from the settings: it's what happened last, not a preference.
    private var driveEndedByDriver: Bool {
        get { UserDefaults.standard.bool(forKey: Self.driveEndedByDriverKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.driveEndedByDriverKey) }
    }

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
        motion.onChange = { [weak self] mode in self?.travelModeChanged(mode) }
        stopNotifier.onEnd = { [weak self] in self?.endDrive(byDriver: true) }
        stopNotifier.onKeep = { [weak self] in self?.stopDetector.keepDriving(at: Date()) }
    }

    // MARK: Lifecycle

    /// Call when the app becomes active. Opening the app starts a drive, unless the driver ended the last one
    /// themselves: then it waits for Start again, even after a relaunch.
    func didBecomeActive() {
        locationAccess = location.access
        if settings.hasCompletedOnboarding, !isDriving, !driveEndedByDriver, locationAccess.isUsable { beginDrive() }
        syncRegister()
    }

    func requestLocationAccess() {
        location.requestAuthorisation()
    }

    func finishOnboarding() {
        settings.hasCompletedOnboarding = true
        if settings.suggestEndingDrive { requestStopPermissions() }
        if locationAccess.isUsable { beginDrive() }
        syncRegister()
    }

    // MARK: Drive

    func beginDrive() {
        guard !isDriving else { return }
        isDriving = true
        driveEndedByDriver = false
        UIApplication.shared.isIdleTimerDisabled = true
        location.start()
        stopDetector = DriveStopDetector()
        if settings.suggestEndingDrive { motion.start() }
        if settings.showOnLockScreen { activity.start(driveState.snapshot) }
        ticker = Task { [weak self] in
            // Age out a stalled GPS so the display shows "–" rather than a frozen number.
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                self?.refresh()
            }
        }
    }

    /// `byDriver` is false when the drive is ended for them (it looked over), so the next open starts one.
    func endDrive(byDriver: Bool) {
        guard isDriving else { return }
        isDriving = false
        driveEndedByDriver = byDriver
        UIApplication.shared.isIdleTimerDisabled = false
        ticker?.cancel()
        ticker = nil
        location.stop()
        motion.stop()
        stopNotifier.clear()
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
        evaluateStop()
    }

    // MARK: Drive stop

    private func travelModeChanged(_ mode: TravelMode) {
        guard isDriving else { return }
        stopDetector.observe(mode, at: Date())
        evaluateStop()
    }

    /// Run every second with the drive's ticker. A ping asks whether the drive is over; an end stops it, so
    /// location isn't left running in a pocket.
    private func evaluateStop() {
        guard settings.suggestEndingDrive else { return }
        switch stopDetector.evaluate(at: Date()) {
        case .none: break
        case .ping: stopNotifier.post()
        case .end: endDrive(byDriver: false)
        }
    }

    private func suggestingEndChanged() {
        if settings.suggestEndingDrive {
            requestStopPermissions()
            if isDriving { motion.start() }
        } else {
            motion.stop()
            stopNotifier.clear()
        }
    }

    /// Asked while the phone is parked: when the setting is turned on, and at the end of onboarding.
    private func requestStopPermissions() {
        stopNotifier.requestAccess()
        motion.requestAccess()
    }

    private func apply(_ state: DriveState) {
        if state != driveState { driveState = state }
        stopDetector.observe(speedKmh: state.snapshot.speed, at: Date())
        // Always offered: the controller re-sends unchanged content on a heartbeat so it can't go stale.
        if settings.showOnLockScreen { activity.update(state.snapshot) }
    }

    // MARK: Register

    private func loadStoredRegister() {
        do {
            if let stored = try store.load() { use(stored.register, checkedAt: stored.metadata.checkedAt) }
        } catch {
            try? store.clear()
        }
    }

    private func use(_ register: SpeedLimitRegister, checkedAt date: Date) {
        engine.register = register
        recordCheck(at: date)
    }

    private func recordCheck(at date: Date) {
        engine.registerCheckedAt = date
        syncStatus.finished(checkedAt: date)
    }

    /// Asks for an update. Opening the app calls this every time and the schedule in `RegisterUpdater`
    /// decides whether anything is actually requested, so it is safe to call as often as is convenient.
    func syncRegister(userInitiated: Bool = false) {
        guard syncTask == nil else { return }
        let store = store
        syncTask = Task {
            defer { syncTask = nil }
            // Progress comes through a stream so every tick is shown, in order, before the result.
            let (updates, continuation) = AsyncStream<Double?>.makeStream()
            let work = Task {
                defer { continuation.finish() }
                return try await Self.update(store: store, userInitiated: userInitiated) { continuation.yield($0) }
            }
            for await progress in updates { syncStatus.progressed(progress) }
            do {
                guard case .ran(let outcome) = try await work.value else { return }
                switch outcome {
                case .unchanged(let metadata): recordCheck(at: metadata.checkedAt)
                case .downloaded(let zones, let metadata): use(SpeedLimitRegister(zones: zones), checkedAt: metadata.checkedAt)
                }
            } catch {
                syncStatus.failed()
            }
        }
    }

    /// The Retry and Check now buttons: skips the weekly wait and the back-off, but not the short floor
    /// between attempts.
    func retrySync() { syncRegister(userInitiated: true) }

    private nonisolated static func update(
        store: RegisterStore,
        userInitiated: Bool,
        progress: @escaping @Sendable (Double?) -> Void
    ) async throws -> ScheduledUpdate {
        try await RegisterUpdater(store: store).updateIfDue(userInitiated: userInitiated, progress: progress)
    }

    // MARK: Settings

    private func persistSettings() {
        UserDefaults.standard.set(settings.encoded(), forKey: Self.settingsKey)
    }
}
