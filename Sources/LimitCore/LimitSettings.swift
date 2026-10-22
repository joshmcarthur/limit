import Foundation

/// User settings, as shown under "While driving" in onboarding and Settings.
public struct LimitSettings: Equatable, Codable, Sendable {
    public var showOnLockScreen = true
    /// Show "over" from this many km/h above the limit.
    public var overTolerance = OverLimitEvaluator.defaultTolerance
    public var hasCompletedOnboarding = false

    public init() {}

    /// "+3 km/h"
    public var toleranceLabel: String { "+\(overTolerance) km/h" }

    /// Missing or unreadable data gives defaults; a newer app's extra keys are ignored.
    public static func decode(_ data: Data?) -> LimitSettings {
        guard let data, let value = try? JSONDecoder().decode(LimitSettings.self, from: data) else { return LimitSettings() }
        return value
    }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }
}
