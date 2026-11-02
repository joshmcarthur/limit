package com.joshmcarthur.limit.core

import java.time.Instant
import java.time.ZonedDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNull

class LimitNoteTest {
    @Test
    fun onlySeasonalAndEmergencyRecordsGetANote() {
        assertEquals(LimitNote.seasonal, LimitNote(kind = ZoneKind.seasonal))
        assertEquals(LimitNote.temporary, LimitNote(kind = ZoneKind.emergency))
        assertNull(LimitNote(kind = ZoneKind.permanent))
        assertEquals(LimitNote.variable, LimitNote(kind = ZoneKind.variable))
        assertNull(LimitNote(kind = null))
    }

    @Test
    fun theWording() {
        assertEquals("Seasonal limit, obey the posted signs", LimitNote.seasonal.label)
        assertEquals("Temporary limit, obey the posted signs", LimitNote.temporary.label)
        assertEquals("Variable limit, obey the posted signs", LimitNote.variable.label)
    }

    @Test
    fun voiceOverReadsTheNoteAfterTheLimit() {
        assertEquals(
            "Speed limit 30 kilometres per hour, seasonal",
            AccessibilityLabels.sign(SignState.Limit(30, isStale = false), note = LimitNote.seasonal),
        )
        assertEquals(
            "Speed limit 50 kilometres per hour, temporary",
            AccessibilityLabels.sign(SignState.Limit(50, isStale = false), note = LimitNote.temporary),
        )
        assertEquals(
            "Speed limit 50 kilometres per hour",
            AccessibilityLabels.sign(SignState.Limit(50, isStale = false), note = null),
        )
        assertEquals("Speed limit unknown", AccessibilityLabels.sign(SignState.Unknown, note = LimitNote.seasonal))
    }

    @Test
    fun theNoteSurvivesTheTripToTheLiveActivity() {
        val snapshot = DriveSnapshot(
            sign = SignState.Limit(30, isStale = false),
            speed = 28,
            roadName = "Motor Camp",
            limitNote = LimitNote.seasonal,
        )
        val decoded = DriveSnapshot.decode(snapshot.encoded())
        assertEquals(LimitNote.seasonal, decoded.limitNote)
        assertNotEquals(
            snapshot,
            DriveSnapshot(sign = SignState.Limit(30, isStale = false), speed = 28, roadName = "Motor Camp"),
        )
    }

    private fun ring(): Ring = Ring(
        listOf(
            Coordinate(latitude = -41.0, longitude = 174.0),
            Coordinate(latitude = -41.0, longitude = 175.0),
            Coordinate(latitude = -40.0, longitude = 175.0),
            Coordinate(latitude = -40.0, longitude = 174.0),
        ),
    )!!

    private fun nz(y: Int, m: Int, d: Int): Instant =
        ZonedDateTime.of(y, m, d, 12, 0, 0, 0, ReducedLimit.timeZone).toInstant()

    private fun snapshot(zone: SpeedZone, at: Instant): DriveSnapshot {
        val engine = DriveEngine(register = SpeedLimitRegister(zones = listOf(zone)), registerCheckedAt = at)
        val sample = LocationSample(
            coordinate = Coordinate(latitude = -40.5, longitude = 174.5),
            speedMetresPerSecond = 8.0,
            horizontalAccuracy = 5.0,
            timestamp = at,
        )
        return engine.ingest(sample, now = at).snapshot
    }

    @Test
    fun theDriveScreenGetsTheNoteWhileASeasonalLimitIsInForce() {
        val summer = ActivePeriod(start = nz(2021, 12, 1), end = nz(2022, 4, 30), repeatsYearly = true)
        val zone = SpeedZone(
            name = "MOTOR CAMP",
            limit = 30,
            kind = ZoneKind.seasonal,
            period = summer,
            polygons = listOf(Polygon(outer = ring())),
        )!!
        assertEquals(LimitNote.seasonal, snapshot(zone, at = nz(2026, 12, 20)).limitNote)
        assertEquals(30, snapshot(zone, at = nz(2026, 12, 20)).limit)
        assertNull(snapshot(zone, at = nz(2026, 7, 1)).limit)
    }

    @Test
    fun aPermanentLimitHasNoNote() {
        val zone = SpeedZone(name = "ROAD", limit = 50, polygons = listOf(Polygon(outer = ring())))!!
        assertNull(snapshot(zone, at = nz(2026, 10, 22)).limitNote)
    }

    @Test
    fun anEmergencyLimitIsLabelledTemporary() {
        val zone = SpeedZone(
            name = "DIVERSION",
            limit = 50,
            kind = ZoneKind.emergency,
            period = ActivePeriod(start = nz(2026, 10, 1), end = nz(2026, 12, 31)),
            polygons = listOf(Polygon(outer = ring())),
        )!!
        assertEquals(LimitNote.temporary, snapshot(zone, at = nz(2026, 10, 22)).limitNote)
    }
}
