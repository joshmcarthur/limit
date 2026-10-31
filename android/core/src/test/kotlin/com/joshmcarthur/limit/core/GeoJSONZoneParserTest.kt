package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFails
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class GeoJSONZoneParserTest {
    private fun collection(features: String, exceeded: Boolean = false): ByteArray =
        """{"type":"FeatureCollection","properties":{"exceededTransferLimit":$exceeded},"features":[$features]}"""
            .toByteArray()

    private val square = "[[[174,-41],[175,-41],[175,-40],[174,-40],[174,-41]]]"

    @Test
    fun parsesPolygonWithLimitAndName() {
        val data = collection(
            """{"type":"Feature","properties":{"speedLimitZoneValue":50,"speedLimitZoneName":"MAIN NORTH ROAD"},
         "geometry":{"type":"Polygon","coordinates":$square}}""",
        )
        val result = GeoJSONZoneParser.parse(data)
        assertEquals(1, result.zones.size)
        assertEquals(50, result.zones[0].limit)
        assertEquals("MAIN NORTH ROAD", result.zones[0].name)
        assertTrue(result.zones[0].contains(Coordinate(latitude = -40.5, longitude = 174.5)))
    }

    @Test
    fun readsTheLiveLayersFields() {
        val data = collection(
            """{"type":"Feature","properties":{"speedLimitZoneId":"73490856-e594","speedLimitZoneName":"CUBA STREET","speedLimitZoneValue":"10"},
         "geometry":{"type":"Polygon","coordinates":$square}}""",
        )
        val zone = GeoJSONZoneParser.parse(data).zones.first()
        assertEquals(10, zone.limit)
        assertEquals("73490856-e594", zone.id)
        assertEquals("CUBA STREET", zone.name)
    }

    @Test
    fun theLimitCanBeTextWithUnits() {
        for (value in listOf("\"60 km/h\"", "\"60\"", "60")) {
            val data = collection(
                """{"type":"Feature","properties":{"speedLimitZoneValue":$value},"geometry":{"type":"Polygon","coordinates":$square}}""",
            )
            assertEquals(60, GeoJSONZoneParser.parse(data).zones.firstOrNull()?.limit, value)
        }
    }

    @Test
    fun onlyTheLayersLimitFieldIsRead() {
        for (key in listOf("speedLimit", "SPEED_LIMIT", "limit", "speed")) {
            val data = collection(
                """{"type":"Feature","properties":{"$key":60},"geometry":{"type":"Polygon","coordinates":$square}}""",
            )
            val result = GeoJSONZoneParser.parse(data)
            assertTrue(result.zones.isEmpty(), key)
            assertEquals(1, result.skippedWithoutLimit, key)
        }
    }

    @Test
    fun multiPolygonAndHoles() {
        val hole = "[[174.4,-40.6],[174.6,-40.6],[174.6,-40.4],[174.4,-40.4],[174.4,-40.6]]"
        val inner = square.drop(1).dropLast(1)
        val data = collection(
            """{"type":"Feature","properties":{"speedLimitZoneValue":30},
         "geometry":{"type":"MultiPolygon","coordinates":[[$inner,$hole],[[[176,-41],[177,-41],[177,-40],[176,-40],[176,-41]]]]}}""",
        )
        val zone = GeoJSONZoneParser.parse(data).zones.first()
        assertEquals(2, zone.polygons.size)
        assertTrue(zone.contains(Coordinate(latitude = -40.9, longitude = 174.1)))
        assertFalse(zone.contains(Coordinate(latitude = -40.5, longitude = 174.5)))
        assertTrue(zone.contains(Coordinate(latitude = -40.5, longitude = 176.5)))
    }

    @Test
    fun featuresWithoutALimitAreCountedNotInvented() {
        val data = collection(
            """{"type":"Feature","properties":{"speedLimitZoneName":"ACACIA BAY ROAD"},
         "geometry":{"type":"Polygon","coordinates":$square}}""",
            exceeded = true,
        )
        val result = GeoJSONZoneParser.parse(data)
        assertTrue(result.zones.isEmpty())
        assertEquals(1, result.featureCount)
        assertEquals(1, result.skippedWithoutLimit)
        assertTrue(result.exceededTransferLimit)
    }

    @Test
    fun implausibleLimitsAreRejected() {
        for (value in listOf("0", "7", "150", "49.5", "\"fast\"")) {
            val data = collection(
                """{"type":"Feature","properties":{"speedLimitZoneValue":$value},"geometry":{"type":"Polygon","coordinates":$square}}""",
            )
            assertEquals(1, GeoJSONZoneParser.parse(data).skippedWithoutLimit, value)
        }
    }

    @Test
    fun badGeometryMakesNoZone() {
        val data = collection(
            """{"type":"Feature","properties":{"speedLimitZoneValue":50},"geometry":{"type":"Point","coordinates":[174,-41]}},
        {"type":"Feature","properties":{"speedLimitZoneValue":50},"geometry":null}""",
        )
        val result = GeoJSONZoneParser.parse(data)
        assertEquals(2, result.featureCount)
        assertTrue(result.zones.isEmpty())
    }

    @Test
    fun notGeoJSONThrows() {
        assertFails { GeoJSONZoneParser.parse("[]".toByteArray()) }
        assertFails { GeoJSONZoneParser.parse("nope".toByteArray()) }
    }
}
