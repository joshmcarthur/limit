import Foundation

/// User settings, as shown under "While driving" in onboarding and Settings.
public struct LimitSettings: Equatable, Codable, Sendable {
    public var showOnLockScreen = true
    /// Show "over" from this many km/h above the limit.
    public var overTolerance = OverLimitEvaluator.defaultTolerance
    public var hasCompletedOnboarding = false
    /// Notice when the drive looks to be over (the person has got out and is walking, or has been still for
    /// a long while) and offer to end it, so location isn't left running in a pocket.
    public var suggestEndingDrive = true

    public init() {}

    /// Keys missing from a copy saved by an earlier build take their defaults, rather than the whole copy
    /// being thrown away; a newer app's extra keys are ignored.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = LimitSettings()
        showOnLockScreen = try c.decodeIfPresent(Bool.self, forKey: .showOnLockScreen) ?? defaults.showOnLockScreen
        overTolerance = try c.decodeIfPresent(Int.self, forKey: .overTolerance) ?? defaults.overTolerance
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding) ?? defaults.hasCompletedOnboarding
        suggestEndingDrive = try c.decodeIfPresent(Bool.self, forKey: .suggestEndingDrive) ?? defaults.suggestEndingDrive
    }

    /// "+3 km/h"
    public var toleranceLabel: String { "+\(overTolerance) km/h" }

    /// Missing or unreadable data gives defaults; a newer app's extra keys are ignored.
    public static func decode(_ data: Data?) -> LimitSettings {
        guard let data, let value = try? JSONDecoder().decode(LimitSettings.self, from: data) else { return LimitSettings() }
        return value
    }

    public func encoded() -> Data? { try? JSONEncoder().encode(self) }
}
