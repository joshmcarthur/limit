public enum OverLimitState: Hashable, Codable, Sendable {
    case notOver
    /// Whole km/h above the limit.
    case over(by: Int)

    public var isOver: Bool {
        if case .over = self { return true }
        return false
    }
}

/// Decides when to show "over". Triggers once the driver is `tolerance` km/h or more above the limit and
/// clears with hysteresis, so the readout doesn't flicker at the boundary.
public struct OverLimitEvaluator: Equatable, Sendable {
    public static let toleranceRange = 1...10
    public static let defaultTolerance = 3

    public private(set) var tolerance: Int
    private var isOver = false

    public init(tolerance: Int = OverLimitEvaluator.defaultTolerance) {
        self.tolerance = Self.clamp(tolerance)
    }

    public mutating func setTolerance(_ value: Int) {
        tolerance = Self.clamp(value)
    }

    /// Both inputs are whole km/h as displayed. A missing speed or limit always clears the state.
    public mutating func evaluate(speed: Int?, limit: Int?) -> OverLimitState {
        guard let speed, let limit else {
            isOver = false
            return .notOver
        }
        let delta = speed - limit
        let clearAt = max(tolerance - 2, 0)
        if isOver {
            if delta <= clearAt { isOver = false }
        } else if delta >= tolerance {
            isOver = true
        }
        return isOver ? .over(by: max(delta, 0)) : .notOver
    }

    private static func clamp(_ value: Int) -> Int {
        min(max(value, toleranceRange.lowerBound), toleranceRange.upperBound)
    }
}
