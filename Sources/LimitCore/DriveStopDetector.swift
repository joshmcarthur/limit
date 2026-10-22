import Foundation

/// How the phone is travelling, as far as the drive-stop check cares.
public enum TravelMode: Equatable, Sendable {
    case driving
    /// Walking, running or cycling: the person has left the car, or never was in one.
    case onFoot
    /// Stationary or unknown. A stopped car reads as this too, so it says nothing either way.
    case other
}

/// Decides when a drive has probably ended, so location isn't left running in a pocket. Pure: the app feeds
/// it what it sees (the travel mode CoreMotion reports when it changes, and the GPS speed each second) and
/// asks `evaluate` what to do.
///
/// - Walking or cycling for `onFootFor` after driving: `.ping`, which the app turns into a notification
///   asking whether the drive is over. If it goes unanswered for `answerWithin`: `.end`.
/// - Whatever the motion data says (or if there is none), near-zero GPS speed for `idleFor`: `.end`.
public struct DriveStopDetector: Equatable, Sendable {
    public enum Action: Equatable, Sendable { case none, ping, end }

    public var onFootFor: TimeInterval = 60
    public var answerWithin: TimeInterval = 600
    public var idleFor: TimeInterval = 900
    /// Below this (km/h) the car counts as not moving.
    public var idleBelow = 3

    private var onFootSince: Date?
    private var pingedAt: Date?
    private var idleSince: Date?
    /// "Keep driving" was chosen: no more pings until the phone is seen driving again.
    private var keeping = false

    public init() {}

    public mutating func observe(_ mode: TravelMode, at now: Date) {
        switch mode {
        case .driving:
            onFootSince = nil
            pingedAt = nil
            keeping = false
        case .onFoot:
            if onFootSince == nil { onFootSince = now }
        case .other:
            break
        }
    }

    /// `nil` (no GPS speed) counts as not moving, since the battery is being spent either way.
    public mutating func observe(speedKmh: Int?, at now: Date) {
        if let speedKmh, speedKmh >= idleBelow {
            idleSince = nil
        } else if idleSince == nil {
            idleSince = now
        }
    }

    /// The person said the drive isn't over: wait for another fifteen minutes of stillness, and don't ask
    /// again until they've been seen driving.
    public mutating func keepDriving(at now: Date) {
        keeping = true
        onFootSince = nil
        pingedAt = nil
        idleSince = now
    }

    public mutating func evaluate(at now: Date) -> Action {
        if let pingedAt, now.timeIntervalSince(pingedAt) >= answerWithin { return .end }
        if let idleSince, now.timeIntervalSince(idleSince) >= idleFor { return .end }
        if !keeping, pingedAt == nil, let onFootSince, now.timeIntervalSince(onFootSince) >= onFootFor {
            pingedAt = now
            return .ping
        }
        return .none
    }
}
