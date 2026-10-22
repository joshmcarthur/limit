import ActivityKit
import Foundation
import LimitCore

/// Shared by the app (which starts and updates the activity) and the widget extension (which draws it).
struct DriveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var limit: Int?
        var isLimitStale: Bool
        var roadName: String?
        var speed: Int?
        var overBy: Int?

        init(_ snapshot: DriveSnapshot) {
            limit = snapshot.limit
            isLimitStale = snapshot.isLimitStale
            roadName = snapshot.roadName
            speed = snapshot.speed
            overBy = snapshot.overBy
        }

        var snapshot: DriveSnapshot {
            DriveSnapshot(limit: limit, isLimitStale: isLimitStale, roadName: roadName, speed: speed, overBy: overBy)
        }
    }
}
