import Foundation

/// What the register sync is doing and when the stored copy was last checked. The `SyncState` shown to the
/// driver is worked out from this each time it is read, so "up to date" turns into "may be out of date" by
/// itself while the app stays open.
public struct SyncStatus: Equatable, Sendable {
    public enum Activity: Equatable, Sendable {
        case idle
        /// `progress` is 0...1, or nil when the total is unknown.
        case updating(progress: Double?)
        case failed
    }

    public private(set) var checkedAt: Date?
    public private(set) var activity = Activity.idle

    public init(checkedAt: Date? = nil) {
        self.checkedAt = checkedAt
    }

    public var isUpdating: Bool {
        if case .updating = activity { return true }
        return false
    }

    public func state(now: Date, policy: FreshnessPolicy = .standard) -> SyncState {
        switch activity {
        case .idle: return .resting(checkedAt: checkedAt, now: now, policy: policy)
        case .updating(let progress): return .updating(progress: progress)
        case .failed: return .failed(lastChecked: checkedAt)
        }
    }

    /// An update is running; the first call starts it.
    public mutating func progressed(_ progress: Double?) {
        activity = .updating(progress: progress)
    }

    /// The stored copy was checked at `date`, whether or not it needed replacing.
    public mutating func finished(checkedAt date: Date) {
        checkedAt = date
        activity = .idle
    }

    /// The last check is kept, since the copy on the phone is still the one in use.
    public mutating func failed() {
        activity = .failed
    }
}
