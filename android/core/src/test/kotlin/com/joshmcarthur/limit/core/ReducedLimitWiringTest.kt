package com.joshmcarthur.limit.core

import java.time.OffsetDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFails
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ReducedLimitWiringTest {
    private val square = "[[[174,-41],[175,-41],[175,-40],[174,-40],[174,-41]]]"
    private val inside = Coordinate(latitude = -40.5, longitude = 174.5)

    private fun feature(value: String = "50", variable: String?, periods: String?, category: String? = null): ByteArray {
        val extra = listOfNotNull(
            category?.let { "\"speedCategoryName\":\"$it\"" },
            variable?.let { "\"speedLimitZoneVariableSpeed\":\"$it\"" },
            periods?.let { "\"speedLimitZoneVarPrdDesc\":\"$it\"" },
        ).joinToString(",")
        val comma = if (extra.isEmpty()) "" else ",$extra"
        return """
        {"type":"FeatureCollection","features":[{"type":"Feature",
        "properties":{"speedLimitZoneValue":"$value"$comma},
        "geometry":{"type":"Polygon","coordinates":$square}}]}
        """.trimIndent().toByteArray()
    }

    private fun zone(data: ByteArray): SpeedZone = GeoJSONZoneParser.parse(data).zones.first()

    private fun date(iso: String) = OffsetDateTime.parse(iso).toInstant()

    @Test
    fun parsesASchoolZone() {
        val z = zone(feature(variable = "40 km/h", periods = "8.30am to 9.15am and 2.45pm to 3.30pm"))
        assertEquals(50, z.limit)
        assertEquals(40, z.reduced?.limit)
        assertEquals(2, z.reduced?.windows?.size)
    }

    @Test
    fun aListOfSpeedsHidesTheNumberAndOneLowerSpeedDoesNot() {
        val highway = zone(feature(value = "100", variable = "50 km/h, 60 km/h, 70 km/h, 80 km/h, 90 km/h", periods = null, category = "Variable"))
        assertTrue(highway.postedLimitUnknown)
        assertEquals(100, highway.limit)
        assertNull(highway.reduced)
        val school = zone(feature(value = "50", variable = "40 km/h", periods = "8.30am to 9.15am", category = "Variable"))
        assertFalse(school.postedLimitUnknown)
        assertEquals(40, school.reduced?.limit)
        val step = zone(feature(value = "100", variable = "70 km/h", periods = null, category = "Variable"))
        assertFalse(step.postedLimitUnknown)
        assertFalse(zone(feature(value = "100", variable = "50 km/h, 60 km/h", periods = null, category = "Permanent")).postedLimitUnknown)
    }

    @Test
    fun reducedLimitIsIgnoredWhenItCannotBeTrusted() {
        assertNull(zone(feature(variable = "40 km/h", periods = "35 minutes before the start of school")).reduced)
        assertNull(zone(feature(variable = "30 km/h, 40 km/h, 50 km/h", periods = "8.30am to 9.15am")).reduced)
        assertNull(zone(feature(variable = "60 km/h", periods = "8.30am to 9.15am")).reduced)
        assertNull(zone(feature(variable = "", periods = "8.30am to 9.15am")).reduced)
        assertNull(zone(feature(variable = "40 km/h", periods = null)).reduced)
        assertEquals(50, zone(feature(variable = "40 km/h", periods = "nonsense")).limit)
    }

    @Test
    fun lookupFollowsTheClock() {
        val z = zone(feature(variable = "40 km/h", periods = "8.30am to 9.15am and 2.45pm to 3.30pm"))
        val register = SpeedLimitRegister(zones = listOf(z))
        assertEquals(40, register.lookup(inside, at = date("2026-10-22T08:45:00+13:00"))?.limit)
        assertEquals(50, register.lookup(inside, at = date("2026-10-22T11:00:00+13:00"))?.limit)
        assertEquals(50, register.lookup(inside, at = date("2026-10-24T08:45:00+13:00"))?.limit)
    }

    @Test
    fun smallerSchoolZoneOverridesTheAreaAroundIt() {
        val school = zone(feature(variable = "40 km/h", periods = "8.30am to 9.15am"))
        val area = SpeedZone(
            name = null,
            limit = 100,
            polygons = listOf(
                Polygon(
                    outer = Ring(
                        listOf(
                            Coordinate(latitude = -45.0, longitude = 170.0),
                            Coordinate(latitude = -45.0, longitude = 178.0),
                            Coordinate(latitude = -38.0, longitude = 178.0),
                            Coordinate(latitude = -38.0, longitude = 170.0),
                        ),
                    )!!,
                ),
            ),
        )!!
        val register = SpeedLimitRegister(zones = listOf(area, school))
        assertEquals(40, register.lookup(inside, at = date("2026-10-22T08:45:00+13:00"))?.limit)
        assertEquals(50, register.lookup(inside, at = date("2026-10-22T12:00:00+13:00"))?.limit)
    }

    @Test
    fun storageKeepsTheReducedLimit() {
        val z = zone(feature(variable = "40 km/h", periods = "8.30am to 9.15am and 2.45pm to 3.30pm"))
        val decoded = ZoneCodec.decode(ZoneCodec.encode(listOf(z))).first()
        assertEquals(z.reduced, decoded.reduced)
        assertEquals(50, decoded.limit)
    }

    @Test
    fun anOldFormatCopyIsRejectedSoItGetsDownloadedAgain() {
        val old = ZoneCodec.encode(emptyList())
        old[4] = 1.toByte()
        assertEquals(ZoneCodecError.UnsupportedVersion(1), assertFails { ZoneCodec.decode(old) })
    }

    @Test
    fun badWindowsInStorageAreInvalid() {
        val z = zone(feature(variable = "40 km/h", periods = "8.30am to 9.15am"))
        val bytes = ZoneCodec.encode(listOf(z))
        val end = 9 + 3 + 2
        bytes[end] = 0
        bytes[end + 1] = 0
        assertEquals(ZoneCodecError.Invalid, assertFails { ZoneCodec.decode(bytes) })
    }

    @Test
    fun engineUsesTheSampleTimeForTheLimit() {
        val z = zone(feature(variable = "40 km/h", periods = "8.30am to 9.15am"))
        val engine = DriveEngine(
            register = SpeedLimitRegister(zones = listOf(z)),
            registerCheckedAt = date("2026-10-22T07:00:00+13:00"),
        )
        fun limit(at: String): Int? {
            val now = date(at)
            return engine.ingest(
                LocationSample(coordinate = inside, speedMetresPerSecond = 10.0, horizontalAccuracy = 5.0, timestamp = now),
                now = now,
            ).snapshot.limit
        }
        assertEquals(40, limit("2026-10-22T08:45:00+13:00"))
        limit("2026-10-22T09:30:00+13:00")
        assertEquals(50, limit("2026-10-22T09:30:01+13:00"))
    }
}
