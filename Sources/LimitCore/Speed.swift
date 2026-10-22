import Foundation

public enum Speed {
    /// CoreLocation reports an invalid speed as a negative number; treat that, NaN and infinity as "no speed".
    public static func kilometresPerHour(fromMetresPerSecond mps: Double) -> Double? {
        guard mps.isFinite, mps >= 0 else { return nil }
        return mps * 3.6
    }

    /// The whole-number speed shown to the driver.
    public static func displayed(_ kmh: Double?) -> Int? {
        guard let kmh, kmh.isFinite, kmh >= 0 else { return nil }
        return Int(kmh.rounded())
    }
}
