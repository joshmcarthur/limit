package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class ZoneConfirmerTest {
    private val a = SpeedLimitMatch(limit = 50, zoneName = "A")
    private val b = SpeedLimitMatch(limit = 70, zoneName = "B")
    private val c = SpeedLimitMatch(limit = 100, zoneName = "C")

    @Test
    fun theFirstMatchIsTakenAtOnce() {
        val zone = ZoneConfirmer()
        zone.observe(a, confirmations = 3)
        assertEquals(a, zone.current)
    }

    @Test
    fun aDifferentZoneNeedsEnoughSamplesInARow() {
        val zone = ZoneConfirmer()
        zone.observe(a, confirmations = 2)
        zone.observe(b, confirmations = 2)
        assertEquals(a, zone.current)
        zone.observe(b, confirmations = 2)
        assertEquals(b, zone.current)
    }

    @Test
    fun anInterruptedRunStartsAgain() {
        val zone = ZoneConfirmer()
        zone.observe(a, confirmations = 2)
        zone.observe(b, confirmations = 2)
        zone.observe(a, confirmations = 2)
        zone.observe(b, confirmations = 2)
        assertEquals(a, zone.current)
        zone.observe(c, confirmations = 2)
        zone.observe(b, confirmations = 2)
        assertEquals(a, zone.current)
    }

    @Test
    fun leavingTheRegisterIsAlsoAChangeThatNeedsConfirming() {
        val zone = ZoneConfirmer()
        zone.observe(a, confirmations = 2)
        zone.observe(null, confirmations = 2)
        assertEquals(a, zone.current)
        zone.observe(null, confirmations = 2)
        assertNull(zone.current)
    }

    @Test
    fun fewerThanOneConfirmationStillNeedsOne() {
        val zone = ZoneConfirmer()
        zone.observe(a, confirmations = 0)
        zone.observe(b, confirmations = 0)
        assertEquals(b, zone.current)
    }

    @Test
    fun resetForgetsTheZoneAndTheCandidate() {
        val zone = ZoneConfirmer()
        zone.observe(a, confirmations = 2)
        zone.observe(b, confirmations = 2)
        zone.reset()
        assertNull(zone.current)
        zone.observe(c, confirmations = 2)
        assertEquals(c, zone.current)
    }
}
