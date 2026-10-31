package com.joshmcarthur.limit.core

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals

class DriveStopDetectorTest {
    private val t0: Instant = Instant.ofEpochSecond(1_000_000)
    private fun at(seconds: Long): Instant = t0.plusSeconds(seconds)

    @Test
    fun nothingHappensWhileDriving() {
        val d = DriveStopDetector()
        d.observe(TravelMode.driving, at = at(0))
        d.observe(speedKmh = 60, at = at(0))
        assertEquals(DriveStopDetector.Action.none, d.evaluate(at(3_600)))
    }

    @Test
    fun walkingForAMinutePingsOnce() {
        val d = DriveStopDetector()
        d.observe(TravelMode.driving, at = at(0))
        d.observe(TravelMode.onFoot, at = at(100))
        d.observe(speedKmh = 4, at = at(100))
        assertEquals(DriveStopDetector.Action.none, d.evaluate(at(159)))
        assertEquals(DriveStopDetector.Action.ping, d.evaluate(at(160)))
        assertEquals(DriveStopDetector.Action.none, d.evaluate(at(170)))
    }

    @Test
    fun sittingBackInTheCarBeforeTheMinuteCancelsIt() {
        val d = DriveStopDetector()
        d.observe(TravelMode.onFoot, at = at(0))
        d.observe(TravelMode.driving, at = at(30))
        assertEquals(DriveStopDetector.Action.none, d.evaluate(at(200)))
    }

    @Test
    fun aStoppedCarReadingAsOtherDoesNothing() {
        val d = DriveStopDetector()
        d.observe(TravelMode.driving, at = at(0))
        d.observe(TravelMode.other, at = at(10))
        d.observe(speedKmh = 4, at = at(10))
        assertEquals(DriveStopDetector.Action.none, d.evaluate(at(400)))
    }

    @Test
    fun stillOnFootAfterOtherStillCounts() {
        val d = DriveStopDetector()
        d.observe(TravelMode.onFoot, at = at(0))
        d.observe(TravelMode.other, at = at(20))
        assertEquals(DriveStopDetector.Action.ping, d.evaluate(at(60)))
    }

    @Test
    fun anUnansweredPingEndsTheDriveAfterTenMinutes() {
        val d = DriveStopDetector()
        d.observe(TravelMode.onFoot, at = at(0))
        assertEquals(DriveStopDetector.Action.ping, d.evaluate(at(60)))
        assertEquals(DriveStopDetector.Action.none, d.evaluate(at(60 + 599)))
        assertEquals(DriveStopDetector.Action.end, d.evaluate(at(60 + 600)))
    }

    @Test
    fun keepDrivingStopsTheEndAndFurtherPings() {
        val d = DriveStopDetector()
        d.observe(TravelMode.onFoot, at = at(0))
        assertEquals(DriveStopDetector.Action.ping, d.evaluate(at(60)))
        d.keepDriving(at = at(100))
        d.observe(speedKmh = 30, at = at(101))
        assertEquals(DriveStopDetector.Action.none, d.evaluate(at(1_000)))
        d.observe(TravelMode.onFoot, at = at(1_000))
        assertEquals(DriveStopDetector.Action.none, d.evaluate(at(1_100)))
        d.observe(TravelMode.driving, at = at(1_200))
        d.observe(TravelMode.onFoot, at = at(1_300))
        assertEquals(DriveStopDetector.Action.ping, d.evaluate(at(1_360)))
    }

    @Test
    fun fifteenMinutesStillEndsTheDriveWithNoMotionData() {
        val d = DriveStopDetector()
        d.observe(speedKmh = 0, at = at(0))
        d.observe(speedKmh = 1, at = at(500))
        assertEquals(DriveStopDetector.Action.none, d.evaluate(at(899)))
        assertEquals(DriveStopDetector.Action.end, d.evaluate(at(900)))
    }

    @Test
    fun movingResetsTheIdleClock() {
        val d = DriveStopDetector()
        d.observe(speedKmh = 0, at = at(0))
        d.observe(speedKmh = 25, at = at(800))
        d.observe(speedKmh = 0, at = at(801))
        assertEquals(DriveStopDetector.Action.none, d.evaluate(at(1_500)))
        assertEquals(DriveStopDetector.Action.end, d.evaluate(at(801 + 900)))
    }

    @Test
    fun noGPSSpeedCountsAsNotMoving() {
        val d = DriveStopDetector()
        d.observe(speedKmh = null, at = at(0))
        assertEquals(DriveStopDetector.Action.end, d.evaluate(at(900)))
    }

    @Test
    fun keepDrivingGivesAnotherFifteenMinutesOfStillness() {
        val d = DriveStopDetector()
        d.observe(speedKmh = 0, at = at(0))
        d.keepDriving(at = at(800))
        d.observe(speedKmh = 0, at = at(801))
        assertEquals(DriveStopDetector.Action.none, d.evaluate(at(1_500)))
        assertEquals(DriveStopDetector.Action.end, d.evaluate(at(800 + 900)))
    }
}
