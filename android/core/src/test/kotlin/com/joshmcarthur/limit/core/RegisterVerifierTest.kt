package com.joshmcarthur.limit.core

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNotNull
import kotlin.test.assertNull

class RegisterVerifierTest {
    private fun downloaded(zones: Int, fetched: Int? = null, expected: Int? = null): DownloadedRegister {
        val ring = Ring(
            listOf(
                Coordinate(latitude = -41.0, longitude = 174.0),
                Coordinate(latitude = -41.0, longitude = 175.0),
                Coordinate(latitude = -40.0, longitude = 175.0),
                Coordinate(latitude = -40.0, longitude = 174.0),
            ),
        )!!
        val zone = SpeedZone(name = null, limit = 50, polygons = listOf(Polygon(outer = ring)))!!
        return DownloadedRegister(
            zones = List(zones) { zone },
            sourceFeatureCount = fetched ?: zones,
            expectedFeatureCount = expected,
        )
    }

    private fun current(count: Int) =
        RegisterMetadata(checkedAt = Instant.now(), zoneCount = count, sourceFeatureCount = count)

    private val policy = RegisterVerificationPolicy(minimumZones = 100)

    @Test
    fun acceptsAHealthyDownload() {
        assertNull(RegisterVerifier.check(downloaded(zones = 1_000, expected = 1_000), current = current(1_000), policy = policy))
    }

    @Test
    fun thresholdsAreInclusive() {
        assertNull(RegisterVerifier.check(downloaded(zones = 800), current = current(1_000), policy = policy))
        assertNotNull(RegisterVerifier.check(downloaded(zones = 799), current = current(1_000), policy = policy))
        assertNull(RegisterVerifier.check(downloaded(zones = 100), current = null, policy = policy))
        assertNotNull(RegisterVerifier.check(downloaded(zones = 99), current = null, policy = policy))
        assertNull(RegisterVerifier.check(downloaded(zones = 990, fetched = 990, expected = 1_000), current = null, policy = policy))
        assertNotNull(RegisterVerifier.check(downloaded(zones = 989, fetched = 989, expected = 1_000), current = null, policy = policy))
    }

    @Test
    fun growthIsFine() {
        assertNull(RegisterVerifier.check(downloaded(zones = 5_000), current = current(1_000), policy = policy))
    }

    @Test
    fun reasonsAreSpecific() {
        assertEquals(
            RegisterRejection.Incomplete(fetched = 150, expected = 1_000),
            RegisterVerifier.check(downloaded(zones = 150, fetched = 150, expected = 1_000), current = null, policy = policy),
        )
        assertEquals(
            RegisterRejection.TooFewZones(count = 50, minimum = 100),
            RegisterVerifier.check(downloaded(zones = 50), current = null, policy = policy),
        )
        assertEquals(
            RegisterRejection.MuchSmaller(count = 200, current = 1_000),
            RegisterVerifier.check(downloaded(zones = 200), current = current(1_000), policy = policy),
        )
    }

    @Test
    fun anEmptyCurrentCopyDoesNotBlockAnything() {
        assertNull(RegisterVerifier.check(downloaded(zones = 150), current = current(0), policy = policy))
    }

    @Test
    fun checksumDetectsAChangedByte() {
        val a = byteArrayOf(1, 2, 3, 4)
        val b = byteArrayOf(1, 2, 3, 5)
        assertNotEquals(Checksum.fnv1a64(a), Checksum.fnv1a64(b))
        assertEquals(Checksum.fnv1a64(a), Checksum.fnv1a64(byteArrayOf(1, 2, 3, 4)))
        assertEquals(0xcbf29ce484222325uL, Checksum.fnv1a64(byteArrayOf()))
    }
}
