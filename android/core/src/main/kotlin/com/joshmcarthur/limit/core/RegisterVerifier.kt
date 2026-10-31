package com.joshmcarthur.limit.core

/** Why a downloaded register wasn't allowed to replace the one in use. */
sealed class RegisterRejection : Exception() {
    /** Fewer records arrived than the source said it had when the download started. */
    data class Incomplete(val fetched: Int, val expected: Int) : RegisterRejection()

    /** Too few zones to be a national register, whatever the old copy looked like. */
    data class TooFewZones(val count: Int, val minimum: Int) : RegisterRejection()

    /** Far fewer zones than the copy already in use. */
    data class MuchSmaller(val count: Int, val current: Int) : RegisterRejection()

    /** What was written to disk isn't what we meant to write. */
    data object WriteMismatch : RegisterRejection()
}

data class DownloadedRegister(
    val zones: List<SpeedZone>,
    val sourceFeatureCount: Int,
    /** How many records the source said it had when the download began; null if it couldn't be learned. */
    val expectedFeatureCount: Int? = null,
)

/** What a download must look like before it can replace the live register. */
data class RegisterVerificationPolicy(
    /** NZTA's in-force set is about 9,000 zones after superseded records ended. */
    var minimumZones: Int = 8_000,
    /** The new copy must keep at least this fraction of the zones in the one in use. */
    var minimumFractionOfCurrent: Double = 0.8,
    /** The download must contain at least this fraction of the records the source reported at the start. */
    var minimumFractionOfExpected: Double = 0.99,
) {
    companion object {
        val standard: RegisterVerificationPolicy = RegisterVerificationPolicy()
    }
}

object RegisterVerifier {
    /** Checks a finished download. Null means it's fine to use; otherwise the reason it isn't. */
    fun check(
        downloaded: DownloadedRegister,
        current: RegisterMetadata?,
        policy: RegisterVerificationPolicy,
    ): RegisterRejection? {
        val expected = downloaded.expectedFeatureCount
        if (expected != null && expected > 0 &&
            downloaded.sourceFeatureCount.toDouble() < expected.toDouble() * policy.minimumFractionOfExpected
        ) {
            return RegisterRejection.Incomplete(fetched = downloaded.sourceFeatureCount, expected = expected)
        }
        val count = downloaded.zones.size
        if (count < policy.minimumZones) return RegisterRejection.TooFewZones(count = count, minimum = policy.minimumZones)
        if (current != null && current.zoneCount > 0 &&
            count.toDouble() < current.zoneCount.toDouble() * policy.minimumFractionOfCurrent
        ) {
            return RegisterRejection.MuchSmaller(count = count, current = current.zoneCount)
        }
        return null
    }
}

/**
 * 64-bit FNV-1a, to confirm a file on disk is byte for byte what we wrote. It guards against a bad or
 * partial write, not against tampering.
 */
object Checksum {
    fun fnv1a64(data: ByteArray): ULong {
        var hash = 0xcbf29ce484222325uL
        for (byte in data) {
            hash = hash xor (byte.toULong() and 0xffu)
            hash *= 0x100000001b3uL
        }
        return hash
    }
}
