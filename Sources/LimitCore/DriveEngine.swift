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
public struct DriveSnapshot: Equatable, Hashable, Sendable, Codable {
    public var sign: SignState
    public var speed: Int?
    public var over: OverLimitState
    public var roadName: String?
    /// Set when the limit shown is a seasonal or temporary one.
    public var limitNote: LimitNote?
    /// The position is outside New Zealand, where there is no data: the limit is unknown for good reason,
    /// not because the road is still being found.
    public var isOutsideNewZealand: Bool

    public init(sign: SignState = .unknown, speed: Int? = nil, over: OverLimitState = .notOver,
                roadName: String? = nil, limitNote: LimitNote? = nil, isOutsideNewZealand: Bool = false) {
        self.sign = sign
        self.speed = speed
        self.over = over
        self.roadName = roadName
        self.limitNote = limitNote
        self.isOutsideNewZealand = isOutsideNewZealand
    }

    public var limit: Int? { sign.limit }

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
    public var register: SpeedLimitRegister {
        // A new register numbers its zones afresh, so what was matched in the old one no longer means anything.
        didSet { zone.reset() }
    }
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
    private var zone = ZoneConfirmer()

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
            zone.observe(register.lookup(sample.coordinate, at: now, preferring: zone.current), confirmations: zoneChangeConfirmations)
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
            zone.reset()
            return .searching
        }

        let speed = Speed.displayed(Speed.kilometresPerHour(fromMetresPerSecond: sample.speedMetresPerSecond))
        let match = zone.current
        let age = registerCheckedAt.map { now.timeIntervalSince($0) }
        let sign = SignState.make(limit: match?.limit, dataAge: age, isDefaultArea: match?.isDefaultArea ?? false, policy: freshness)
        let over = evaluator.evaluate(speed: speed, limit: sign.limit)

        var snapshot = DriveSnapshot(sign: sign, speed: speed, over: over)
        if sign.isOpenRoad {
            // The default zone's own name is register jargon, and it carries no limit to qualify.
            snapshot.roadName = "Open road"
        } else if match == nil, !Coverage.isNewZealand(sample.coordinate) {
            snapshot.roadName = Coverage.outsideNewZealandName
            snapshot.isOutsideNewZealand = true
        } else if sign.limit != nil {
            snapshot.roadName = RoadNameFormatter.display(match?.zoneName)
            snapshot.limitNote = LimitNote(kind: match?.kind)
        }
        return DriveState(snapshot: snapshot, gps: sample.horizontalAccuracy <= goodAccuracy ? .good : .weak)
    }
}
