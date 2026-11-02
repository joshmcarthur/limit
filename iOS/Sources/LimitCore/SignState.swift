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
    /// A variable speed sign can show any of several limits. The register only stored the highest, so the
    /// circle is empty and red: there is a limit, and the sign on the road has the number.
    case variablePosted(isStale: Bool)
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

    public var isVariablePosted: Bool {
        if case .variablePosted = self { return true }
        return false
    }

    public static func make(limit: Int?, dataAge: TimeInterval?, isDefaultArea: Bool = false,
                            postedLimitUnknown: Bool = false, policy: FreshnessPolicy = .standard) -> SignState {
        guard let dataAge else { return .unknown }
        if policy.level(forAge: dataAge) == .tooOld { return .unknown }
        let stale = policy.level(forAge: dataAge) == .stale
        if postedLimitUnknown { return .variablePosted(isStale: stale) }
        guard let limit else { return .unknown }
        if isDefaultArea { return .openRoad(isStale: stale) }
        return .limit(limit, isStale: stale)
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
