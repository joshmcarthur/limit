import ActivityKit
import Foundation
import LimitCore

/// Starts, updates and ends the Lock Screen / Dynamic Island Live Activity for a drive.
@MainActor
final class DriveActivityController {
    private var activity: Activity<DriveActivityAttributes>?
    private var lastState: DriveSnapshot?
    private var lastSent: Date?

    /// Updates are best-effort. There is no stale date: the widget dims a speed itself, from `sentAt`, if
    /// updates stop arriving.
    private func content(_ snapshot: DriveSnapshot) -> ActivityContent<DriveActivityContent> {
        ActivityContent(state: DriveActivityContent(snapshot: snapshot, sentAt: Date()), staleDate: nil)
    }

    func start(_ snapshot: DriveSnapshot) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // A card from a killed app outlives it, and we only hold the one we start, so clear any before starting.
        endAll()
        activity = try? Activity.request(attributes: DriveActivityAttributes(), content: content(snapshot), pushType: nil)
        lastState = snapshot
        lastSent = Date()
    }

    func update(_ snapshot: DriveSnapshot) {
        guard let activity else { return }
        // Unchanged content is still re-sent on a heartbeat, or it would go stale while driving steadily.
        guard LiveActivityRefresh.shouldSend(changed: snapshot != lastState,
                                             secondsSinceLastSend: lastSent.map { Date().timeIntervalSince($0) }) else { return }
        lastState = snapshot
        lastSent = Date()
        let content = content(snapshot)
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
