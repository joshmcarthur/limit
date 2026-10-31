package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFails
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class ZoneCodecTest {
    private fun ring(lat: Double, lon: Double, size: Double): Ring =
        Ring(
            listOf(
                Coordinate(latitude = lat, longitude = lon),
                Coordinate(latitude = lat, longitude = lon + size),
                Coordinate(latitude = lat + size, longitude = lon + size),
                Coordinate(latitude = lat + size, longitude = lon),
            ),
        )!!

    private fun sampleZones(): List<SpeedZone> = listOf(
        SpeedZone(
            name = "GLOUCESTER STREET",
            limit = 30,
            polygons = listOf(
                Polygon(outer = ring(-43.53, 172.63, 0.01), holes = listOf(ring(-43.529, 172.631, 0.002))),
                Polygon(outer = ring(-43.60, 172.70, 0.01)),
            ),
        )!!,
        SpeedZone(name = null, limit = 100, polygons = listOf(Polygon(outer = ring(-41.2, 174.7, 0.5))))!!,
        SpeedZone(name = "TE PAERAHI — Māori ō", limit = 50, polygons = listOf(Polygon(outer = ring(-40.4, 176.6, 0.01))))!!,
    )

    @Test
    fun roundTrip() {
        val original = sampleZones()
        val decoded = ZoneCodec.decode(ZoneCodec.encode(original))
        assertEquals(original.size, decoded.size)
        for ((a, b) in original.zip(decoded)) {
            assertEquals(a.limit, b.limit)
            assertEquals(a.name, b.name)
            assertEquals(a.polygons.size, b.polygons.size)
            assertEquals(a.polygons.map { it.holes.size }, b.polygons.map { it.holes.size })
            for ((pa, pb) in a.polygons.zip(b.polygons)) {
                for ((x, y) in pa.outer.points.zip(pb.outer.points)) {
                    assertEquals(x.latitude, y.latitude, 1e-6)
                    assertEquals(x.longitude, y.longitude, 1e-6)
                }
            }
        }
    }

    @Test
    fun decodedZonesStillContainPoints() {
        val decoded = ZoneCodec.decode(ZoneCodec.encode(sampleZones()))
        assertTrue(decoded[0].contains(Coordinate(latitude = -43.525, longitude = 172.636)))
        assertFalse(decoded[0].contains(Coordinate(latitude = -43.528, longitude = 172.632)))
        assertTrue(decoded[1].contains(Coordinate(latitude = -41.0, longitude = 175.0)))
        assertFalse(decoded[1].contains(Coordinate(latitude = -40.5, longitude = 175.0)))
    }

    @Test
    fun empty() {
        assertEquals(0, ZoneCodec.decode(ZoneCodec.encode(emptyList())).size)
    }

    @Test
    fun badMagicAndVersion() {
        val magicError = assertFails { ZoneCodec.decode("NOPE\u0001".toByteArray(Charsets.UTF_8)) }
        assertEquals(ZoneCodecError.BadMagic, magicError)
        val data = ZoneCodec.encode(emptyList())
        data[4] = 9.toByte()
        val versionError = assertFails { ZoneCodec.decode(data) }
        assertEquals(ZoneCodecError.UnsupportedVersion(9), versionError)
    }

    @Test
    fun everyTruncationThrowsRatherThanCrashing() {
        val data = ZoneCodec.encode(sampleZones())
        for (length in 0 until data.size) {
            assertFails("length $length") { ZoneCodec.decode(data.copyOf(length)) }
        }
    }

    @Test
    fun hugeCountsAreRejected() {
        val data = ZoneCodec.magic + byteArrayOf(ZoneCodec.version.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte(), 0xFF.toByte())
        assertFails { ZoneCodec.decode(data) }
    }
}
