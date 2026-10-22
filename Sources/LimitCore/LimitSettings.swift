import Foundation

/// User settings, as shown under "While driving" in onboarding and Settings.
public struct LimitSettings: Equatable, Codable, Sendable {
    public var showOnLockScreen = true
    /// Show "over" from this many km/h above the limit.
    public var overTolerance = OverLimitEvaluator.defaultTolerance
    /// A single chime when the limit changes. Off by default; nothing ever sounds when going over.
    public var chimeOnLimitChange = false
    public var hasCompletedOnboarding = false

    public init() {}

    public mutating func stepTolerance(by delta: Int) {
        let range = OverLimitEvaluator.toleranceRange
        overTolerance = min(max(overTolerance + delta, range.lowerBound), range.upperBound)
    }

    public var canDecreaseTolerance: Bool { overTolerance > OverLimitEvaluator.toleranceRange.lowerBound }
    public var canIncreaseTolerance: Bool { overTolerance < OverLimitEvaluator.toleranceRange.upperBound }

    /// "+3 km/h"
    public var toleranceLabel: String { "+\(overTolerance) km/h" }

    /// Missing or unreadable data gives defaults; a newer app's extra keys are ignored.
    public static func decode(_ data: Data?) -> LimitSettings {
        guard let data, let value = try? JSONDecoder().decode(LimitSettings.self, from: data) else { return LimitSettings() }
        return value
    }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }
}
