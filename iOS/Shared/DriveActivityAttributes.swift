import ActivityKit
import Foundation
import LimitCore

/// What the activity is sent: the frame to draw, and when it was sent. The time lives apart from the
/// snapshot so that it doesn't count as a change (a change is sent at once; unchanged content only on the
/// heartbeat). The widget times its dimming from it, with no further update.
struct DriveActivityContent: Codable, Hashable {
    var snapshot: DriveSnapshot
    var sentAt: Date
}

/// Shared by the app (which starts and updates the activity) and the widget extension (which draws it).
struct DriveActivityAttributes: ActivityAttributes {
    typealias ContentState = DriveActivityContent
}
