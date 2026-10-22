import ActivityKit
import Foundation
import LimitCore

/// Starts, updates and ends the Lock Screen / Dynamic Island Live Activity for a drive.
@MainActor
final class DriveActivityController {
    private var activity: Activity<DriveActivityAttributes>?
    private var lastState: DriveActivityAttributes.ContentState?

    /// Updates are best-effort. Marking content stale after a few seconds lets the widget fall back to "–"
    /// instead of a frozen number if updates stop arriving.
    private func content(_ state: DriveActivityAttributes.ContentState) -> ActivityContent<DriveActivityAttributes.ContentState> {
        ActivityContent(state: state, staleDate: Date().addingTimeInterval(10))
    }

    func start(_ snapshot: DriveSnapshot) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        let state = DriveActivityAttributes.ContentState(snapshot)
        activity = try? Activity.request(attributes: DriveActivityAttributes(), content: content(state), pushType: nil)
        lastState = state
    }

    func update(_ snapshot: DriveSnapshot) {
        guard let activity else { return }
        let state = DriveActivityAttributes.ContentState(snapshot)
        guard state != lastState else { return }
        lastState = state
        let content = content(state)
        Task { await activity.update(content) }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        lastState = nil
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
    }
}
