import Foundation

/// Why a downloaded register wasn't allowed to replace the one in use.
public enum RegisterRejection: Error, Equatable, Sendable {
    /// Fewer records arrived than the source said it had when the download started.
    case incomplete(fetched: Int, expected: Int)
    /// Too few zones to be a national register, whatever the old copy looked like.
    case tooFewZones(count: Int, minimum: Int)
    /// Far fewer zones than the copy already in use.
    case muchSmaller(count: Int, current: Int)
    /// What was written to disk isn't what we meant to write.
    case writeMismatch
}

/// What a download must look like before it can replace the live register.
public struct RegisterVerificationPolicy: Equatable, Sendable {
    /// A national register is about 21,000 zones once ended records are left out (about 26,000 with them).
    /// The NZTA layer was seen mid-rebuild at 1,250, then 5,000, then 13,700, so the floor sits above that.
    /// Re-measure with `swift run -c release RegisterCheck` whenever the layer changes shape.
    public var minimumZones: Int
    /// The new copy must keep at least this fraction of the zones in the one in use.
    public var minimumFractionOfCurrent: Double
    /// The download must contain at least this fraction of the records the source reported at the start.
    public var minimumFractionOfExpected: Double

    public init(minimumZones: Int = 15_000, minimumFractionOfCurrent: Double = 0.8, minimumFractionOfExpected: Double = 0.99) {
        self.minimumZones = minimumZones
        self.minimumFractionOfCurrent = minimumFractionOfCurrent
        self.minimumFractionOfExpected = minimumFractionOfExpected
    }

    public static let standard = RegisterVerificationPolicy()
}

public enum RegisterVerifier {
    /// Checks a finished download. Nil means it's fine to use; otherwise the reason it isn't.
    public static func check(
        _ downloaded: DownloadedRegister, current: RegisterMetadata?, policy: RegisterVerificationPolicy
    ) -> RegisterRejection? {
        if let expected = downloaded.expectedFeatureCount, expected > 0,
           Double(downloaded.sourceFeatureCount) < Double(expected) * policy.minimumFractionOfExpected {
            return .incomplete(fetched: downloaded.sourceFeatureCount, expected: expected)
        }
        let count = downloaded.zones.count
        if count < policy.minimumZones { return .tooFewZones(count: count, minimum: policy.minimumZones) }
        if let current, current.zoneCount > 0, Double(count) < Double(current.zoneCount) * policy.minimumFractionOfCurrent {
            return .muchSmaller(count: count, current: current.zoneCount)
        }
        return nil
    }
}

/// 64-bit FNV-1a, to confirm a file on disk is byte for byte what we wrote. It guards against a bad or
/// partial write, not against tampering.
enum Checksum {
    static func fnv1a64(_ data: Data) -> UInt64 {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in data {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return hash
    }
}
