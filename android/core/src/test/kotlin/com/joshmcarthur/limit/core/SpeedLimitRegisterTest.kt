package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class SpeedLimitRegisterTest {
    private fun zone(limit: Int, name: String? = null, lat: Double, lon: Double, size: Double): SpeedZone {
        val ring = Ring(
            listOf(
                Coordinate(latitude = lat, longitude = lon),
                Coordinate(latitude = lat, longitude = lon + size),
                Coordinate(latitude = lat + size, longitude = lon + size),
                Coordinate(latitude = lat + size, longitude = lon),
            ),
        )!!
        return SpeedZone(name = name, limit = limit, polygons = listOf(Polygon(outer = ring)))!!
    }

    @Test
    fun lookupFindsContainingZone() {
        val register = SpeedLimitRegister(
            zones = listOf(
                zone(50, name = "A", lat = -41.0, lon = 174.0, size = 0.1),
                zone(100, name = "B", lat = -42.0, lon = 175.0, size = 0.1),
            ),
        )
        assertEquals(
            SpeedLimitMatch(limit = 50, zoneName = "A"),
            register.lookup(Coordinate(latitude = -40.95, longitude = 174.05)),
        )
        assertEquals(100, register.lookup(Coordinate(latitude = -41.95, longitude = 175.05))?.limit)
    }

    @Test
    fun offTheRegisterIsNil() {
        val register = SpeedLimitRegister(zones = listOf(zone(50, lat = -41.0, lon = 174.0, size = 0.1)))
        assertNull(register.lookup(Coordinate(latitude = -35.0, longitude = 174.0)))
        assertNull(SpeedLimitRegister.empty.lookup(Coordinate(latitude = -41.0, longitude = 174.0)))
    }

    @Test
    fun smallestOverlappingZoneWins() {
        val register = SpeedLimitRegister(
            zones = listOf(
                zone(100, lat = -41.0, lon = 174.0, size = 1.0),
                zone(50, lat = -40.6, lon = 174.4, size = 0.1),
            ),
        )
        assertEquals(50, register.lookup(Coordinate(latitude = -40.55, longitude = 174.45))?.limit)
        assertEquals(100, register.lookup(Coordinate(latitude = -40.9, longitude = 174.1))?.limit)
    }

    @Test
    fun equalOverlapPrefersLowerLimit() {
        val register = SpeedLimitRegister(
            zones = listOf(
                zone(80, lat = -41.0, lon = 174.0, size = 0.1),
                zone(60, lat = -41.0, lon = 174.0, size = 0.1),
            ),
        )
        assertEquals(60, register.lookup(Coordinate(latitude = -40.95, longitude = 174.05))?.limit)
    }

    @Test
    fun veryLargeZoneIsStillFound() {
        val register = SpeedLimitRegister(zones = listOf(zone(100, lat = -46.0, lon = 167.0, size = 11.0)))
        assertEquals(100, register.lookup(Coordinate(latitude = -40.0, longitude = 174.0))?.limit)
    }

    @Test
    fun zoneAcrossCellBoundary() {
        val register = SpeedLimitRegister(
            zones = listOf(zone(30, lat = -41.01, lon = 174.01, size = 0.08)),
            cellSize = 0.05,
        )
        assertEquals(30, register.lookup(Coordinate(latitude = -40.95, longitude = 174.08))?.limit)
        assertEquals(1, register.zoneCount)
    }
}

class DefaultAreaNameTest {
    @Test
    fun defaultRecordsAreRecognised() {
        for (name in listOf("DEFAULT SPEED LIMIT", "Default Speed Limit", "DEFAULT SPEED LIMIT- INTERSECTION 2")) {
            assertEquals(true, SpeedLimitMatch(limit = 100, zoneName = name).isDefaultArea, name)
        }
    }

    @Test
    fun ordinaryZonesAreNot() {
        for (name in listOf("PORIRUA CITY UTA", "STATE HIGHWAY 1", "CLYDE-CLYDE LOOKOUT ROAD-DEFAULT LIMIT TO SUNDERLAND STREET", null)) {
            assertEquals(false, SpeedLimitMatch(limit = 100, zoneName = name).isDefaultArea, name ?: "nil")
        }
    }
}
