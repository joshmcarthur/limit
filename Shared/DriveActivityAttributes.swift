import ActivityKit
import Foundation
import LimitCore

/// Shared by the app (which starts and updates the activity) and the widget extension (which draws it).
struct DriveActivityAttributes: ActivityAttributes {
    typealias ContentState = DriveSnapshot
}
