package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class GeoTest {
    private fun square(lat: Double, lon: Double, size: Double): Ring {
        return Ring(
            listOf(
                Coordinate(latitude = lat, longitude = lon),
                Coordinate(latitude = lat, longitude = lon + size),
                Coordinate(latitude = lat + size, longitude = lon + size),
                Coordinate(latitude = lat + size, longitude = lon),
            ),
        )!!
    }

    @Test
    fun ringNeedsThreePoints() {
        assertNull(
            Ring(
                listOf(
                    Coordinate(latitude = 0.0, longitude = 0.0),
                    Coordinate(latitude = 1.0, longitude = 1.0),
                ),
            ),
        )
    }

    @Test
    fun ringContainment() {
        val ring = square(-41.0, 174.0, 1.0)
        assertTrue(ring.contains(Coordinate(latitude = -40.5, longitude = 174.5)))
        assertFalse(ring.contains(Coordinate(latitude = -41.5, longitude = 174.5)))
        assertFalse(ring.contains(Coordinate(latitude = -40.5, longitude = 175.5)))
    }

    @Test
    fun closedRingWithRepeatedFirstPoint() {
        val points = square(-41.0, 174.0, 1.0).points.toMutableList()
        points.add(points[0])
        val ring = Ring(points)!!
        assertTrue(ring.contains(Coordinate(latitude = -40.5, longitude = 174.5)))
    }

    @Test
    fun polygonHoleIsExcluded() {
        val polygon = Polygon(outer = square(-41.0, 174.0, 1.0), holes = listOf(square(-40.75, 174.25, 0.5)))
        assertTrue(polygon.contains(Coordinate(latitude = -40.9, longitude = 174.1)))
        assertFalse(polygon.contains(Coordinate(latitude = -40.5, longitude = 174.5)))
    }

    @Test
    fun concavePolygon() {
        val l = Ring(
            listOf(
                Coordinate(latitude = 0.0, longitude = 0.0),
                Coordinate(latitude = 0.0, longitude = 2.0),
                Coordinate(latitude = 1.0, longitude = 2.0),
                Coordinate(latitude = 1.0, longitude = 1.0),
                Coordinate(latitude = 2.0, longitude = 1.0),
                Coordinate(latitude = 2.0, longitude = 0.0),
            ),
        )!!
        assertTrue(l.contains(Coordinate(latitude = 1.5, longitude = 0.5)))
        assertFalse(l.contains(Coordinate(latitude = 1.5, longitude = 1.5)))
    }

    @Test
    fun boundsArea() {
        assertEquals(4.0, square(0.0, 0.0, 2.0).bounds.area, 1e-12)
    }
}
