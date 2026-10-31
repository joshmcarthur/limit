import CoreMotion
import LimitCore

/// Tells the app when the way the phone is travelling changes (driving to walking, say). CoreMotion only
/// calls back on a change, so this costs next to nothing. Needs Motion & Fitness access; without it nothing
/// is reported and the drive-stop check relies on GPS speed alone.
@MainActor
final class MotionService {
    private let manager = CMMotionActivityManager()
    var onChange: ((TravelMode) -> Void)?

    /// Whether updates can be started now without prompting.
    var isAuthorised: Bool {
        CMMotionActivityManager.isActivityAvailable() && CMMotionActivityManager.authorizationStatus() == .authorized
    }

    /// Asks for access. Reading a bit of history is how iOS is made to show the prompt.
    func requestAccess() {
        guard CMMotionActivityManager.isActivityAvailable(), CMMotionActivityManager.authorizationStatus() == .notDetermined else { return }
        let now = Date()
        manager.queryActivityStarting(from: now.addingTimeInterval(-60), to: now, to: .main) { _, _ in }
    }

    func start() {
        guard isAuthorised else { return }
        manager.startActivityUpdates(to: .main) { [weak self] activity in
            guard let activity else { return }
            // A low-confidence reading is too often a guess; ignore it rather than act on it.
            guard activity.confidence != .low else { return }
            let mode: TravelMode
            if activity.automotive { mode = .driving }
            else if activity.walking || activity.running || activity.cycling { mode = .onFoot }
            else { mode = .other }
            Task { @MainActor in self?.onChange?(mode) }
        }
    }

    func stop() { manager.stopActivityUpdates() }
}
