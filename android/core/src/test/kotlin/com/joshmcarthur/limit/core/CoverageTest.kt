package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class CoverageTest {
    private fun nz(lat: Double, lon: Double): Boolean =
        Coverage.isNewZealand(Coordinate(latitude = lat, longitude = lon))

    @Test
    fun placesInNewZealandAreCovered() {
        assertTrue(nz(-41.2865, 174.7762), "Wellington")
        assertTrue(nz(-36.8485, 174.7633), "Auckland")
        assertTrue(nz(-43.5314, 172.6358), "Christchurch")
        assertTrue(nz(-45.0312, 168.6626), "Queenstown")
        assertTrue(nz(-46.9, 168.1), "Stewart Island")
        assertTrue(nz(-34.4, 172.7), "Cape Reinga")
        assertTrue(nz(-43.95, -176.55), "Chatham Islands, across the date line")
    }

    @Test
    fun placesElsewhereAreNot() {
        assertFalse(nz(37.3349, -122.0090), "Cupertino")
        assertFalse(nz(-33.8688, 151.2093), "Sydney")
        assertFalse(nz(51.5074, -0.1278), "London")
        assertFalse(nz(-17.7134, 178.065), "Fiji")
        assertFalse(nz(0.0, 0.0), "a bad fix at null island")
    }
}
