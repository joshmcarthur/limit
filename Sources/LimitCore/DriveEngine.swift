import Foundation

public struct LocationSample: Equatable, Sendable {
    public var coordinate: Coordinate
    /// Metres per second; negative when the system has no valid speed.
    public var speedMetresPerSecond: Double
    /// Metres; negative when the position is invalid.
    public var horizontalAccuracy: Double
    public var timestamp: Date

    public init(coordinate: Coordinate, speedMetresPerSecond: Double, horizontalAccuracy: Double, timestamp: Date) {
        self.coordinate = coordinate
        self.speedMetresPerSecond = speedMetresPerSecond
        self.horizontalAccuracy = horizontalAccuracy
        self.timestamp = timestamp
    }
}

public enum GPSQuality: Equatable, Sendable {
    case searching, weak, good

    /// Status line copy for the top of the driving screen.
    public var label: String {
        switch self {
        case .searching: return "Searching for GPS…"
        case .weak: return "GPS · weak"
        case .good: return "GPS · good"
        }
    }
}

/// Everything a driving surface (app, Live Activity, widget) needs to draw one frame.
public struct DriveSnapshot: Equatable, Sendable, Codable {
    public var limit: Int?
    public var isLimitStale: Bool
    public var roadName: String?
    public var speed: Int?
    public var overBy: Int?

    public init(limit: Int? = nil, isLimitStale: Bool = false, roadName: String? = nil, speed: Int? = nil, overBy: Int? = nil) {
        self.limit = limit
        self.isLimitStale = isLimitStale
        self.roadName = roadName
        self.speed = speed
        self.overBy = overBy
    }

    public var sign: SignState {
        guard let limit else { return .unknown }
        return .limit(limit, isStale: isLimitStale)
    }

    public var over: OverLimitState {
        overBy.map { .over(by: $0) } ?? .notOver
    }

    public static let searching = DriveSnapshot()
}

public struct DriveState: Equatable, Sendable {
    public var snapshot: DriveSnapshot
    public var gps: GPSQuality
    public static let searching = DriveState(snapshot: .searching, gps: .searching)
}

/// Turns location samples into drive state. A sample that is too old, or whose position is too poor,
/// shows as no speed and an unknown limit rather than a frozen last value.
public struct DriveEngine {
    public var register: SpeedLimitRegister
    /// When the register data was last checked against the source; nil if never.
    public var registerCheckedAt: Date?
    public var freshness: FreshnessPolicy
    public var evaluator: OverLimitEvaluator
    /// A sample older than this at display time is treated as lost.
    public var maxSampleAge: TimeInterval = 5
    /// Worse than this (metres) and the position can't say which road you are on.
    public var maxUsableAccuracy: Double = 100
    public var goodAccuracy: Double = 25

    /// How many samples in a row must agree on a different zone before the sign changes. One stray fix
    /// near a boundary (GPS wander of tens of metres) then can't flip the limit; 2 costs about a second.
    public var zoneChangeConfirmations = 2

    private var lastSample: LocationSample?
    private var stableMatch: SpeedLimitMatch?
    private var pendingMatch: SpeedLimitMatch?
    private var pendingCount = 0

    public init(
        register: SpeedLimitRegister = .empty,
        registerCheckedAt: Date? = nil,
        freshness: FreshnessPolicy = .standard,
        tolerance: Int = OverLimitEvaluator.defaultTolerance
    ) {
        self.register = register
        self.registerCheckedAt = registerCheckedAt
        self.freshness = freshness
        self.evaluator = OverLimitEvaluator(tolerance: tolerance)
    }

    public mutating func ingest(_ sample: LocationSample, now: Date = Date()) -> DriveState {
        lastSample = sample
        if sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= maxUsableAccuracy {
            confirm(register.lookup(sample.coordinate, at: now))
        }
        return state(now: now)
    }

    /// Recompute without a new sample, so a stalled GPS ages out of the display.
    public mutating func state(now: Date = Date()) -> DriveState {
        guard let sample = lastSample,
              now.timeIntervalSince(sample.timestamp) <= maxSampleAge,
              sample.horizontalAccuracy >= 0, sample.horizontalAccuracy <= maxUsableAccuracy
        else {
            _ = evaluator.evaluate(speed: nil, limit: nil)
            // After a gap the car may be anywhere, so don't hold on to the last zone.
            stableMatch = nil
            pendingMatch = nil
            pendingCount = 0
            return .searching
        }

        let speed = Speed.displayed(Speed.kilometresPerHour(fromMetresPerSecond: sample.speedMetresPerSecond))
        let match = stableMatch
        let age = registerCheckedAt.map { now.timeIntervalSince($0) }
        let sign = SignState.make(limit: match?.limit, dataAge: age, policy: freshness)
        let over = evaluator.evaluate(speed: speed, limit: sign.limit)

        var snapshot = DriveSnapshot(speed: speed)
        if case .limit(let limit, let isStale) = sign {
            snapshot.limit = limit
            snapshot.isLimitStale = isStale
            snapshot.roadName = RoadNameFormatter.display(match?.zoneName)
        }
        if case .over(let by) = over { snapshot.overBy = by }
        return DriveState(snapshot: snapshot, gps: sample.horizontalAccuracy <= goodAccuracy ? .good : .weak)
    }

    /// Moves to `raw` only once enough samples in a row agree on it. The first match after having none is
    /// taken at once.
    private mutating func confirm(_ raw: SpeedLimitMatch?) {
        guard let stable = stableMatch else { stableMatch = raw; return }
        if raw == stable { pendingMatch = nil; pendingCount = 0; return }
        pendingCount = raw == pendingMatch ? pendingCount + 1 : 1
        pendingMatch = raw
        if pendingCount >= max(zoneChangeConfirmations, 1) {
            stableMatch = raw
            pendingMatch = nil
            pendingCount = 0
        }
    }
}
