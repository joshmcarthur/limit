import ActivityKit
import Foundation
import LimitCore

/// Starts, updates and ends the Lock Screen / Dynamic Island Live Activity for a drive.
@MainActor
final class DriveActivityController {
    private var activity: Activity<DriveActivityAttributes>?
    private var lastState: DriveActivityAttributes.ContentState?
    private var lastSent: Date?

    /// Updates are best-effort. Marking content stale after a few seconds lets the widget fall back to "–"
    /// instead of a frozen number if updates stop arriving.
    private func content(_ state: DriveActivityAttributes.ContentState) -> ActivityContent<DriveActivityAttributes.ContentState> {
        ActivityContent(state: state, staleDate: Date().addingTimeInterval(LiveActivityRefresh.staleAfter))
    }

    func start(_ snapshot: DriveSnapshot) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // A card from a killed app outlives it, and we only hold the one we start, so clear any before starting.
        endAll()
        let state = DriveActivityAttributes.ContentState(snapshot)
        activity = try? Activity.request(attributes: DriveActivityAttributes(), content: content(state), pushType: nil)
        lastState = state
        lastSent = Date()
    }

    func update(_ snapshot: DriveSnapshot) {
        guard let activity else { return }
        let state = DriveActivityAttributes.ContentState(snapshot)
        // Unchanged content is still re-sent on a heartbeat, or it would go stale while driving steadily.
        guard LiveActivityRefresh.shouldSend(changed: state != lastState,
                                             secondsSinceLastSend: lastSent.map { Date().timeIntervalSince($0) }) else { return }
        lastState = state
        lastSent = Date()
        let content = content(state)
        Task { await activity.update(content) }
    }

    func end() {
        activity = nil
        lastState = nil
        lastSent = nil
        endAll()
    }

    /// Ends every activity this app owns, including ones left behind by an earlier launch.
    private func endAll() {
        for existing in Activity<DriveActivityAttributes>.activities {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
