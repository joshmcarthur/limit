package com.joshmcarthur.limit.core

import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZonedDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFails
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ZoneAttributesTest {
    private val square = "[[[174,-41],[175,-41],[175,-40],[174,-40],[174,-41]]]"

    private fun zone(properties: String): SpeedZone {
        val data = """
        {"type":"FeatureCollection","features":[{"type":"Feature","properties":{$properties},
        "geometry":{"type":"Polygon","coordinates":$square}}]}
        """.trimIndent().toByteArray()
        return GeoJSONZoneParser.parse(data).zones.first()
    }

    private fun date(iso: String): Instant = OffsetDateTime.parse(iso).toInstant()

    @Test
    fun aSeasonalRecurringRecord() {
        val z = zone(
            """
        "speedLimitZoneValue":"30","speedCategoryName":"Seasonal","speedLimitZoneSeasonalRecur":1,
        "speedLimitZoneStartDate":1638320400000,"speedLimitZoneEndDate":1651276800000
            """.trimIndent(),
        )
        assertEquals(ZoneKind.seasonal, z.kind)
        assertEquals(true, z.period?.repeatsYearly)
        assertTrue(z.isActive(date("2026-12-20T00:00:00+13:00")))
        assertFalse(z.isActive(date("2026-07-01T00:00:00+12:00")))
    }

    @Test
    fun anEmergencyRecordThatHasEnded() {
        val z = zone(
            """
        "speedLimitZoneValue":"50","speedCategoryName":"Temporary",
        "speedLimitZoneStartDate":1692316800000,"speedLimitZoneEndDate":1723852800000
            """.trimIndent(),
        )
        assertEquals(ZoneKind.emergency, z.kind)
        assertEquals(false, z.period?.repeatsYearly)
        assertTrue(z.isActive(date("2024-01-10T12:00:00+13:00")))
        assertFalse(z.isActive(date("2026-10-22T12:00:00+13:00")))
    }

    @Test
    fun anEndedPermanentRecordIsNotActive() {
        val z = zone(
            """
        "speedLimitZoneValue":"100","speedCategoryName":"Permanent",
        "speedLimitZoneStartDate":-2209161600000,"speedLimitZoneEndDate":1749513600000
            """.trimIndent(),
        )
        assertEquals(ZoneKind.permanent, z.kind)
        assertNull(z.period?.start)
        assertTrue(z.isActive(date("2025-01-01T12:00:00+13:00")))
        assertFalse(z.isActive(date("2026-10-22T12:00:00+13:00")))
    }

    @Test
    fun aPermanentRecordWithOnlyAPlaceholderStartHasNoPeriod() {
        val z = zone(
            """
        "speedLimitZoneValue":"50","speedCategoryName":"Permanent","speedLimitZoneStartDate":-2208985200000,
        "speedLimitZoneStructureTypeName":"Overpass"
            """.trimIndent(),
        )
        assertNull(z.period)
        assertEquals(StructureType.overpass, z.structure)
        assertTrue(z.isActive(Instant.now()))
    }

    @Test
    fun recurOnANonSeasonalRecordDoesNotRepeat() {
        val z = zone(
            """
        "speedLimitZoneValue":"50","speedCategoryName":"Permanent","speedLimitZoneSeasonalRecur":1,
        "speedLimitZoneStartDate":1638320400000,"speedLimitZoneEndDate":1651276800000
            """.trimIndent(),
        )
        assertEquals(false, z.period?.repeatsYearly)
    }

    @Test
    fun recordsWithNoCategoryOrDatesAreAlwaysActivePermanentZones() {
        val z = zone("\"speedLimitZoneValue\":\"60\"")
        assertEquals(ZoneKind.permanent, z.kind)
        assertEquals(StructureType.none, z.structure)
        assertNull(z.period)
    }

    @Test
    fun datesThatAreNotNumbersAreIgnored() {
        val z = zone("\"speedLimitZoneValue\":\"60\",\"speedLimitZoneEndDate\":\"soon\",\"speedLimitZoneStartDate\":null")
        assertNull(z.period)
    }

    private fun ring(): Ring = Ring(
        listOf(
            Coordinate(latitude = -41.0, longitude = 174.0),
            Coordinate(latitude = -41.0, longitude = 175.0),
            Coordinate(latitude = -40.0, longitude = 175.0),
            Coordinate(latitude = -40.0, longitude = 174.0),
        ),
    )!!

    @Test
    fun theStoreKeepsKindStructureAndPeriod() {
        val nz = ReducedLimit.timeZone
        val start = ZonedDateTime.of(2021, 12, 1, 14, 0, 0, 0, nz).toInstant()
        val end = ZonedDateTime.of(2022, 4, 30, 12, 0, 0, 0, nz).toInstant()
        val zones = listOf(
            SpeedZone(
                name = "SEASONAL",
                limit = 30,
                kind = ZoneKind.seasonal,
                period = ActivePeriod(start = start, end = end, repeatsYearly = true),
                polygons = listOf(Polygon(outer = ring())),
            )!!,
            SpeedZone(
                name = "EMERGENCY",
                limit = 50,
                kind = ZoneKind.emergency,
                period = ActivePeriod(start = start, end = end),
                polygons = listOf(Polygon(outer = ring())),
            )!!,
            SpeedZone(
                name = "OPEN END",
                limit = 50,
                structure = StructureType.underpass,
                period = ActivePeriod(start = start, end = null),
                polygons = listOf(Polygon(outer = ring())),
            )!!,
            SpeedZone(
                name = "NO END",
                limit = 50,
                structure = StructureType.intersection,
                period = ActivePeriod(start = null, end = end),
                polygons = listOf(Polygon(outer = ring())),
            )!!,
            SpeedZone(name = "PLAIN", limit = 100, polygons = listOf(Polygon(outer = ring())))!!,
        )
        val decoded = ZoneCodec.decode(ZoneCodec.encode(zones))
        assertEquals(zones.map { it.kind }, decoded.map { it.kind })
        assertEquals(zones.map { it.structure }, decoded.map { it.structure })
        assertEquals(zones.map { it.period }, decoded.map { it.period })
    }

    @Test
    fun postedLimitUnknownRoundTripsAndVersion3DoesNotHaveIt() {
        val z = SpeedZone(
            name = "SH 2",
            limit = 100,
            postedLimitUnknown = true,
            kind = ZoneKind.variable,
            polygons = listOf(Polygon(outer = ring())),
        )!!
        val decoded = ZoneCodec.decode(ZoneCodec.encode(listOf(z))).first()
        assertTrue(decoded.postedLimitUnknown)
        assertEquals(100, decoded.limit)
        val old = ZoneCodec.encode(listOf(z))
        old[4] = 3.toByte()
        val v3 = old.toMutableList()
        v3.removeAt(9 + 5)
        val decodedV3 = ZoneCodec.decode(v3.toByteArray()).first()
        assertFalse(decodedV3.postedLimitUnknown)
        assertEquals("SH 2", decodedV3.name)
        assertEquals(100, decodedV3.limit)
    }

    @Test
    fun anOldFormatCopyIsRejected() {
        val old = ZoneCodec.encode(emptyList())
        old[4] = 2.toByte()
        val error = assertFails { ZoneCodec.decode(old) }
        assertEquals(ZoneCodecError.UnsupportedVersion(2), error)
    }

    @Test
    fun anImpossibleKindOrFlagIsInvalid() {
        val z = SpeedZone(name = null, limit = 50, polygons = listOf(Polygon(outer = ring())))!!
        val bytes = ZoneCodec.encode(listOf(z))
        val badKind = bytes.copyOf()
        badKind[9 + 2] = 9.toByte()
        assertEquals(ZoneCodecError.Invalid, assertFails { ZoneCodec.decode(badKind) })
        val badFlags = bytes.copyOf()
        badFlags[9 + 4] = 0x80.toByte()
        assertEquals(ZoneCodecError.Invalid, assertFails { ZoneCodec.decode(badFlags) })
    }

    @Test
    fun aPackedDayThatIsNotADateIsInvalid() {
        val start = Instant.ofEpochSecond(1_700_000_000)
        val z = SpeedZone(
            name = null,
            limit = 50,
            period = ActivePeriod(start = start, end = null),
            polygons = listOf(Polygon(outer = ring())),
        )!!
        val bytes = ZoneCodec.encode(listOf(z))
        val bad = 20_231_399
        for (i in 0 until 4) {
            bytes[9 + 6 + i] = ((bad shr (8 * i)) and 0xFF).toByte()
        }
        assertEquals(ZoneCodecError.Invalid, assertFails { ZoneCodec.decode(bytes) })
    }

    @Test
    fun recordsThatDifferOnlyInDatesAreNotRepeats() {
        fun record(end: Long): SpeedZone =
            zone(
                "\"speedLimitZoneId\":\"a\",\"speedLimitZoneValue\":\"70\",\"speedCategoryName\":\"Seasonal\",\"speedLimitZoneSeasonalRecur\":1,\"speedLimitZoneStartDate\":1638320400000,\"speedLimitZoneEndDate\":$end",
            )
        val a = record(1651276800000)
        val b = record(1651276800000)
        val c = record(1682812800000)
        assertEquals(2, ZoneDeduplicator.unique(listOf(a, b, c)).size)
    }
}
