import ActivityKit
import Foundation
import LimitCore

/// Starts, updates and ends the Lock Screen / Dynamic Island Live Activity for a drive.
@MainActor
final class DriveActivityController {
    private var activity: Activity<DriveActivityAttributes>?
    private var lastState: DriveSnapshot?
    private var lastShowsSpeed = false
    private var lastSent: Date?

    /// Updates are best-effort. There is no stale date: the widget dims a speed itself, from `sentAt`, if
    /// updates stop arriving. A card that shows the zone name does not dim.
    private func content(_ snapshot: DriveSnapshot, showsSpeed: Bool) -> ActivityContent<DriveActivityContent> {
        ActivityContent(state: DriveActivityContent(snapshot: snapshot, sentAt: Date(), showsSpeed: showsSpeed), staleDate: nil)
    }

    func start(_ snapshot: DriveSnapshot, showsSpeed: Bool) {
        guard activity == nil, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // A card from a killed app outlives it, and we only hold the one we start, so clear any before starting.
        endAll()
        activity = try? Activity.request(attributes: DriveActivityAttributes(), content: content(snapshot, showsSpeed: showsSpeed), pushType: nil)
        lastState = snapshot
        lastShowsSpeed = showsSpeed
        lastSent = Date()
    }

    func update(_ snapshot: DriveSnapshot, showsSpeed: Bool) {
        guard let activity else { return }
        let changed = snapshot != lastState || showsSpeed != lastShowsSpeed
        guard LiveActivityRefresh.shouldSend(
            contentChanged: changed,
            speedOnlyChange: changed && showsSpeed == lastShowsSpeed && Self.isSpeedOnlyChange(from: lastState, to: snapshot),
            showsSpeed: showsSpeed,
            secondsSinceLastSend: lastSent.map { Date().timeIntervalSince($0) }
        ) else { return }
        lastState = snapshot
        lastShowsSpeed = showsSpeed
        lastSent = Date()
        let content = content(snapshot, showsSpeed: showsSpeed)
        Task { await activity.update(content) }
    }

    /// True when the only difference a driver would see is the speed or the over-limit state.
    private static func isSpeedOnlyChange(from previous: DriveSnapshot?, to next: DriveSnapshot) -> Bool {
        guard var previous else { return false }
        let speedChanged = previous.speed != next.speed || previous.over != next.over
        previous.speed = next.speed
        previous.over = next.over
        return speedChanged && previous == next
    }

    func end() {
        activity = nil
        lastState = nil
        lastShowsSpeed = false
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
