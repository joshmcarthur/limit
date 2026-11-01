package com.joshmcarthur.limit.core

import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class DriveEngineTest {
    private val now: Instant = Instant.ofEpochSecond(1_800_000_000)
    private val inside = Coordinate(latitude = -41.0, longitude = 174.0)

    private fun engine(limit: Int = 50, checkedAgo: Long = 3_600, tolerance: Int = 3): DriveEngine {
        val ring = Ring(
            listOf(
                Coordinate(latitude = -41.1, longitude = 173.9),
                Coordinate(latitude = -41.1, longitude = 174.1),
                Coordinate(latitude = -40.9, longitude = 174.1),
                Coordinate(latitude = -40.9, longitude = 173.9),
            ),
        )!!
        val zone = SpeedZone(name = "GLOUCESTER STREET", limit = limit, polygons = listOf(Polygon(outer = ring)))!!
        return DriveEngine(
            register = SpeedLimitRegister(zones = listOf(zone)),
            registerCheckedAt = now.minusSeconds(checkedAgo),
            tolerance = tolerance,
        )
    }

    private fun sample(kmh: Double, accuracy: Double = 5.0, at: Coordinate? = null, age: Long = 0): LocationSample =
        LocationSample(
            coordinate = at ?: inside,
            speedMetresPerSecond = kmh / 3.6,
            horizontalAccuracy = accuracy,
            timestamp = now.minusSeconds(age),
        )

    @Test
    fun aVariableListShowsTheNameAndNoNumber() {
        val ring = Ring(
            listOf(
                Coordinate(latitude = -41.1, longitude = 173.9),
                Coordinate(latitude = -41.1, longitude = 174.1),
                Coordinate(latitude = -40.9, longitude = 174.1),
                Coordinate(latitude = -40.9, longitude = 173.9),
            ),
        )!!
        val zone = SpeedZone(
            name = "HOROKIWI TO NGAURANGA, SH 2",
            limit = 100,
            postedLimitUnknown = true,
            kind = ZoneKind.variable,
            polygons = listOf(Polygon(outer = ring)),
        )!!
        val e = DriveEngine(register = SpeedLimitRegister(zones = listOf(zone)), registerCheckedAt = now.minusSeconds(3_600))
        val state = e.ingest(sample(kmh = 110.0), now = now)
        assertEquals(SignState.VariablePosted(isStale = false), state.snapshot.sign)
        assertNull(state.snapshot.limit)
        assertEquals("Horokiwi To Ngauranga, SH 2", state.snapshot.roadName)
        assertEquals(LimitNote.variable, state.snapshot.limitNote)
        assertEquals(OverLimitState.NotOver, state.snapshot.over)
    }

    @Test
    fun normalDriving() {
        val e = engine()
        val state = e.ingest(sample(kmh = 47.0), now = now)
        assertEquals(GPSQuality.good, state.gps)
        assertEquals(50, state.snapshot.limit)
        assertEquals(47, state.snapshot.speed)
        assertEquals("Gloucester Street", state.snapshot.roadName)
        assertEquals(OverLimitState.NotOver, state.snapshot.over)
        assertEquals(SignState.Limit(50, isStale = false), state.snapshot.sign)
    }

    @Test
    fun overTheLimit() {
        val e = engine(limit = 30)
        val state = e.ingest(sample(kmh = 38.0), now = now)
        assertEquals(OverLimitState.Over(by = 8), state.snapshot.over)
    }

    @Test
    fun offTheRegisterShowsUnknownLimitButKeepsSpeed() {
        val e = engine()
        val state = e.ingest(sample(kmh = 60.0, at = Coordinate(latitude = -35.0, longitude = 174.0)), now = now)
        assertEquals(SignState.Unknown, state.snapshot.sign)
        assertNull(state.snapshot.roadName)
        assertEquals(60, state.snapshot.speed)
        assertEquals(OverLimitState.NotOver, state.snapshot.over)
    }

    @Test
    fun defaultAreaShowsOpenRoadAndNeverOver() {
        val ring = Ring(
            listOf(
                Coordinate(latitude = -41.1, longitude = 173.9),
                Coordinate(latitude = -41.1, longitude = 174.1),
                Coordinate(latitude = -40.9, longitude = 174.1),
                Coordinate(latitude = -40.9, longitude = 173.9),
            ),
        )!!
        val zone = SpeedZone(name = "DEFAULT SPEED LIMIT", limit = 100, polygons = listOf(Polygon(outer = ring)))!!
        val e = DriveEngine(
            register = SpeedLimitRegister(zones = listOf(zone)),
            registerCheckedAt = now.minusSeconds(3_600),
            tolerance = 3,
        )
        val state = e.ingest(sample(kmh = 140.0), now = now)
        assertEquals(SignState.OpenRoad(isStale = false), state.snapshot.sign)
        assertNull(state.snapshot.limit)
        assertEquals("Open road", state.snapshot.roadName)
        assertEquals(OverLimitState.NotOver, state.snapshot.over)
        assertEquals(140, state.snapshot.speed)
    }

    @Test
    fun outsideNewZealandSaysSoAndKeepsSpeed() {
        val e = engine()
        val cupertino = Coordinate(latitude = 37.3349, longitude = -122.0090)
        val state = e.ingest(sample(kmh = 60.0, at = cupertino), now = now)
        assertEquals(SignState.Unknown, state.snapshot.sign)
        assertTrue(state.snapshot.isOutsideNewZealand)
        assertEquals("Outside New Zealand", state.snapshot.roadName)
        assertEquals(60, state.snapshot.speed)
        assertEquals(OverLimitState.NotOver, state.snapshot.over)
    }

    @Test
    fun aGapInTheRegisterInsideNewZealandIsNotCalledOutside() {
        val e = engine()
        val state = e.ingest(sample(kmh = 60.0, at = Coordinate(latitude = -35.0, longitude = 174.0)), now = now)
        assertFalse(state.snapshot.isOutsideNewZealand)
        assertNull(state.snapshot.roadName)
    }

    @Test
    fun staleSampleIsLostNotFrozen() {
        val e = engine()
        e.ingest(sample(kmh = 47.0), now = now)
        assertEquals(DriveState.searching, e.state(now = now.plusSeconds(6)))
    }

    @Test
    fun poorAccuracyIsTreatedAsNoFix() {
        val e = engine()
        assertEquals(DriveState.searching, e.ingest(sample(kmh = 47.0, accuracy = 500.0), now = now))
        assertEquals(DriveState.searching, e.ingest(sample(kmh = 47.0, accuracy = -1.0), now = now))
    }

    @Test
    fun weakButUsableAccuracy() {
        val e = engine()
        val state = e.ingest(sample(kmh = 47.0, accuracy = 60.0), now = now)
        assertEquals(GPSQuality.weak, state.gps)
        assertEquals(50, state.snapshot.limit)
    }

    @Test
    fun invalidSpeedShowsDashButLimit() {
        val e = engine()
        val bad = LocationSample(coordinate = inside, speedMetresPerSecond = -1.0, horizontalAccuracy = 5.0, timestamp = now)
        val state = e.ingest(bad, now = now)
        assertNull(state.snapshot.speed)
        assertEquals(50, state.snapshot.limit)
    }

    @Test
    fun staleRegisterBadgesAndOldRegisterHidesLimit() {
        val stale = engine(checkedAgo = 40 * 86_400)
        assertEquals(SignState.Limit(50, isStale = true), stale.ingest(sample(kmh = 47.0), now = now).snapshot.sign)
        val old = engine(checkedAgo = 400 * 86_400)
        assertEquals(SignState.Unknown, old.ingest(sample(kmh = 47.0), now = now).snapshot.sign)
    }

    @Test
    fun neverCheckedRegisterIsUnknown() {
        val e = engine()
        e.registerCheckedAt = null
        assertEquals(SignState.Unknown, e.ingest(sample(kmh = 47.0), now = now).snapshot.sign)
    }

    @Test
    fun overStateClearsWhenFixIsLost() {
        val e = engine(limit = 30)
        assertTrue(e.ingest(sample(kmh = 40.0), now = now).snapshot.over.isOver)
        e.state(now = now.plusSeconds(10))
        val later = now.plusSeconds(10)
        assertFalse(e.ingest(sample(kmh = 32.0, age = -10), now = later).snapshot.over.isOver)
    }
}

class ZoneChangeConfirmationTest {
    private fun box(limit: Int, lon: Double): SpeedZone {
        val ring = Ring(
            listOf(
                Coordinate(latitude = -41.0, longitude = lon),
                Coordinate(latitude = -41.0, longitude = lon + 1),
                Coordinate(latitude = -40.0, longitude = lon + 1),
                Coordinate(latitude = -40.0, longitude = lon),
            ),
        )!!
        return SpeedZone(name = "Z$limit", limit = limit, polygons = listOf(Polygon(outer = ring)))!!
    }

    private val west = Coordinate(latitude = -40.5, longitude = 174.5)
    private val east = Coordinate(latitude = -40.5, longitude = 175.5)
    private val now: Instant = Instant.ofEpochSecond(1_000_000)

    private fun engine(): DriveEngine = DriveEngine(
        register = SpeedLimitRegister(zones = listOf(box(50, lon = 174.0), box(100, lon = 175.0))),
        registerCheckedAt = now,
    )

    private fun limit(e: DriveEngine, at: Coordinate, second: Long, accuracy: Double = 5.0): Int? {
        val t = now.plusSeconds(second)
        return e.ingest(
            LocationSample(coordinate = at, speedMetresPerSecond = 10.0, horizontalAccuracy = accuracy, timestamp = t),
            now = t,
        ).snapshot.limit
    }

    @Test
    fun aZoneIsShownAtOnceWhenNothingWasShownBefore() {
        val e = engine()
        assertEquals(50, limit(e, west, second = 0))
    }

    @Test
    fun oneStrayFixDoesNotChangeTheLimit() {
        val e = engine()
        limit(e, west, second = 0)
        assertEquals(50, limit(e, east, second = 1))
        assertEquals(50, limit(e, west, second = 2))
        assertEquals(50, limit(e, east, second = 3))
    }

    @Test
    fun twoFixesInARowChangeIt() {
        val e = engine()
        limit(e, west, second = 0)
        limit(e, east, second = 1)
        assertEquals(100, limit(e, east, second = 2))
    }

    @Test
    fun theConfirmationCountCanBeChanged() {
        val e = engine()
        e.zoneChangeConfirmations = 1
        limit(e, west, second = 0)
        assertEquals(100, limit(e, east, second = 1))
    }

    @Test
    fun aLostFixForgetsTheZone() {
        val e = engine()
        limit(e, west, second = 0)
        assertNull(limit(e, west, second = 1, accuracy = 500.0))
        assertEquals(100, limit(e, east, second = 2))
    }

    @Test
    fun snapshotsRoundTripThroughJSON() {
        val snapshots = listOf(
            DriveSnapshot.searching,
            DriveSnapshot(
                sign = SignState.Limit(50, isStale = true),
                speed = 58,
                over = OverLimitState.Over(by = 8),
                roadName = "Cuba Street",
            ),
            DriveSnapshot(
                sign = SignState.Limit(30, isStale = false),
                speed = 28,
                limitNote = LimitNote.temporary,
            ),
        )
        for (snapshot in snapshots) {
            assertEquals(snapshot, DriveSnapshot.decode(snapshot.encoded()))
        }
    }
}
