import Foundation

/// What the store remembers about trying to sync, so the limits below hold across launches.
public struct SyncAttempts: Codable, Equatable, Sendable {
    public var lastAttemptAt: Date?
    /// Attempts since the last success. Counted when an attempt starts, so one that is killed halfway
    /// (the app suspended mid-download) still counts as a failure.
    public var consecutiveFailures: Int

    public init(lastAttemptAt: Date? = nil, consecutiveFailures: Int = 0) {
        self.lastAttemptAt = lastAttemptAt
        self.consecutiveFailures = consecutiveFailures
    }
}

/// How often the app may ask the source for anything. Opening the app never causes more requests than this
/// allows; only the person tapping Retry goes faster, and not faster than `manualFloor`.
public struct SyncSchedule: Equatable, Sendable {
    /// Between automatic checks when a stored copy exists. The register changes often, but a limit rarely
    /// changes on any one road, and the sign only warns after 30 days.
    public var checkInterval: TimeInterval
    /// Wait after the 1st, 2nd, 3rd... failure in a row; the last value repeats.
    public var backoff: [TimeInterval]
    /// The shortest gap between attempts when the person asked for the check.
    public var manualFloor: TimeInterval

    public init(checkInterval: TimeInterval = 7 * 86_400,
                backoff: [TimeInterval] = [15 * 60, 3_600, 6 * 3_600, 86_400],
                manualFloor: TimeInterval = 5 * 60) {
        self.checkInterval = checkInterval
        self.backoff = backoff
        self.manualFloor = manualFloor
    }

    public static let standard = SyncSchedule()

    public enum Decision: Equatable, Sendable {
        case now
        case wait(until: Date)
    }

    /// `lastSuccessAt` is when the stored copy was last checked or downloaded; nil if there's no copy.
    public func decision(attempts: SyncAttempts, lastSuccessAt: Date?, now: Date, userInitiated: Bool) -> Decision {
        // A clock set backwards must not push the next attempt far into the future.
        let lastAttempt = attempts.lastAttemptAt.map { min($0, now) }
        if userInitiated {
            if let lastAttempt, lastAttempt.addingTimeInterval(manualFloor) > now {
                return .wait(until: lastAttempt.addingTimeInterval(manualFloor))
            }
            return .now
        }
        var due = Date.distantPast
        if let lastSuccessAt { due = min(lastSuccessAt, now).addingTimeInterval(checkInterval) }
        if attempts.consecutiveFailures > 0, let lastAttempt {
            let step = backoff.isEmpty ? 0 : backoff[min(attempts.consecutiveFailures - 1, backoff.count - 1)]
            due = max(due, lastAttempt.addingTimeInterval(step))
        }
        return due > now ? .wait(until: due) : .now
    }
}
