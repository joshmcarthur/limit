import Foundation

/// How old register data may be before the sign warns, and before it stops showing a limit at all.
/// The thresholds are proposals to tune on device.
public struct FreshnessPolicy: Equatable, Sendable {
    public var staleAfter: TimeInterval
    public var unknownAfter: TimeInterval

    public init(staleAfter: TimeInterval = 30 * 86_400, unknownAfter: TimeInterval = 180 * 86_400) {
        self.staleAfter = staleAfter
        self.unknownAfter = unknownAfter
    }

    public static let standard = FreshnessPolicy()

    public enum Level: Equatable, Sendable { case fresh, stale, tooOld }

    public func level(forAge age: TimeInterval) -> Level {
        if age >= unknownAfter { return .tooOld }
        if age >= staleAfter { return .stale }
        return .fresh
    }
}

/// What the speed sign shows.
public enum SignState: Hashable, Codable, Sendable {
    case limit(Int, isStale: Bool)
    /// The register has only its national default here, which says nothing about this road: it is what
    /// covers any street no council has recorded a zone for. Shows no number, so the driver reads the signs.
    case openRoad(isStale: Bool)
    /// No fix, off the register, or data too old to trust. Never shows the last known limit.
    case unknown

    public var limit: Int? {
        if case .limit(let value, _) = self { return value }
        return nil
    }

    public var isOpenRoad: Bool {
        if case .openRoad = self { return true }
        return false
    }

    public static func make(limit: Int?, dataAge: TimeInterval?, isDefaultArea: Bool = false,
                            policy: FreshnessPolicy = .standard) -> SignState {
        guard let limit, let dataAge else { return .unknown }
        switch policy.level(forAge: dataAge) {
        case .fresh: return isDefaultArea ? .openRoad(isStale: false) : .limit(limit, isStale: false)
        case .stale: return isDefaultArea ? .openRoad(isStale: true) : .limit(limit, isStale: true)
        case .tooOld: return .unknown
        }
    }
}

/// Proportions from the SpeedSign component guidelines.
public enum SignMetrics {
    public static func ringWidth(diameter: Double) -> Double { diameter * 0.11 }

    public static func numeralSize(diameter: Double, limit: Int) -> Double {
        diameter * (limit >= 100 ? 0.36 : 0.42)
    }

    /// The stale badge is dropped below 40 pt.
    public static func showsStaleBadge(diameter: Double) -> Bool { diameter >= 40 }
}
