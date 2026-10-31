package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertEquals

class ZoneDeduplicatorTest {
    private fun zone(id: String?, limit: Int = 50, lat: Double = -41.0): SpeedZone {
        val ring = Ring(
            listOf(
                Coordinate(latitude = lat, longitude = 174.0),
                Coordinate(latitude = lat, longitude = 174.1),
                Coordinate(latitude = lat + 0.1, longitude = 174.1),
                Coordinate(latitude = lat + 0.1, longitude = 174.0),
            ),
        )!!
        return SpeedZone(id = id, name = null, limit = limit, polygons = listOf(Polygon(outer = ring)))!!
    }

    @Test
    fun repeatedRecordsCollapse() {
        val zones = listOf(zone(id = "a"), zone(id = "a"), zone(id = "a"), zone(id = "b", lat = -42.0))
        assertEquals(listOf("a", "b"), ZoneDeduplicator.unique(zones).map { it.id })
    }

    @Test
    fun sameIdWithDifferentShapeIsKept() {
        val zones = listOf(zone(id = "a", lat = -41.0), zone(id = "a", lat = -43.0))
        assertEquals(2, ZoneDeduplicator.unique(zones).size)
    }

    @Test
    fun sameIdAndShapeWithDifferentLimitIsKept() {
        assertEquals(2, ZoneDeduplicator.unique(listOf(zone(id = "a", limit = 50), zone(id = "a", limit = 30))).size)
    }

    @Test
    fun zonesWithoutAnIdAreNeverDropped() {
        assertEquals(2, ZoneDeduplicator.unique(listOf(zone(id = null), zone(id = null))).size)
    }

    @Test
    fun orderIsPreserved() {
        val zones = listOf(zone(id = "b", lat = -42.0), zone(id = "a"), zone(id = "b", lat = -42.0))
        assertEquals(listOf("b", "a"), ZoneDeduplicator.unique(zones).map { it.id })
    }
}
