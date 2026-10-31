package com.joshmcarthur.limit.core

import java.time.Instant
import java.time.ZonedDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNotEquals
import kotlin.test.assertNull

class LookupRulesTest {
    private fun nz(y: Int, m: Int, d: Int, h: Int = 12): Instant =
        ZonedDateTime.of(y, m, d, h, 0, 0, 0, ReducedLimit.timeZone).toInstant()

    private fun zone(
        limit: Int,
        name: String,
        size: Double,
        kind: ZoneKind = ZoneKind.permanent,
        structure: StructureType = StructureType.none,
        period: ActivePeriod? = null,
    ): SpeedZone = SpeedZone(
        name = name,
        limit = limit,
        kind = kind,
        structure = structure,
        period = period,
        polygons = listOf(
            Polygon(
                outer = Ring(
                    listOf(
                        Coordinate(latitude = -41.0, longitude = 174.0),
                        Coordinate(latitude = -41.0, longitude = 174.0 + size),
                        Coordinate(latitude = -41.0 + size, longitude = 174.0 + size),
                        Coordinate(latitude = -41.0 + size, longitude = 174.0),
                    ),
                )!!,
            ),
        ),
    )!!

    private val inside = Coordinate(latitude = -40.95, longitude = 174.05)
    private val now: Instant = Instant.ofEpochSecond(1_792_600_000)

    @Test
    fun anEndedRecordNeverWins() {
        val ended = ActivePeriod(start = null, end = nz(2025, 6, 10))
        val register = SpeedLimitRegister(
            zones = listOf(
                zone(100, "AREA", size = 1.0),
                zone(60, "ENDED, SMALLER", size = 0.2, period = ended),
            ),
        )
        assertEquals(100, register.lookup(inside, at = now)?.limit)
        assertEquals(60, register.lookup(inside, at = nz(2025, 1, 1))?.limit)
    }

    @Test
    fun aRecordThatHasntStartedYetIsIgnored() {
        val future = ActivePeriod(start = nz(2027, 1, 1), end = null)
        val register = SpeedLimitRegister(
            zones = listOf(
                zone(100, "AREA", size = 1.0),
                zone(60, "LATER", size = 0.2, period = future),
            ),
        )
        assertEquals(100, register.lookup(inside, at = now)?.limit)
        assertEquals(60, register.lookup(inside, at = nz(2027, 2, 1))?.limit)
    }

    @Test
    fun nothingActiveMeansNoLimit() {
        val ended = ActivePeriod(start = null, end = nz(2025, 6, 10))
        assertNull(SpeedLimitRegister(zones = listOf(zone(60, "OVER", size = 1.0, period = ended))).lookup(inside, at = now))
    }

    private val summer: ActivePeriod
        get() = ActivePeriod(start = nz(2021, 12, 1), end = nz(2022, 4, 30), repeatsYearly = true)!!

    @Test
    fun aSeasonalLimitBeatsALargerPermanentOneInSeason() {
        val register = SpeedLimitRegister(
            zones = listOf(
                zone(100, "ROAD", size = 1.0),
                zone(30, "MOTOR CAMP", size = 0.2, kind = ZoneKind.seasonal, period = summer),
            ),
        )
        val match = register.lookup(inside, at = nz(2026, 12, 20))
        assertEquals(30, match?.limit)
        assertEquals(ZoneKind.seasonal, match?.kind)
    }

    @Test
    fun aSeasonalLimitBeatsASmallerPermanentOne() {
        val register = SpeedLimitRegister(
            zones = listOf(
                zone(50, "SMALL PERMANENT", size = 0.1),
                zone(30, "BIG SEASONAL", size = 1.0, kind = ZoneKind.seasonal, period = summer),
            ),
        )
        assertEquals(30, register.lookup(inside, at = nz(2026, 12, 20))?.limit)
    }

    @Test
    fun outOfSeasonTheSeasonalLimitIsIgnored() {
        val register = SpeedLimitRegister(
            zones = listOf(
                zone(100, "ROAD", size = 1.0),
                zone(30, "MOTOR CAMP", size = 0.2, kind = ZoneKind.seasonal, period = summer),
            ),
        )
        val match = register.lookup(inside, at = nz(2026, 7, 1))
        assertEquals(100, match?.limit)
        assertEquals(ZoneKind.permanent, match?.kind)
    }

    @Test
    fun anEmergencyLimitBeatsASeasonalOneWhileItLasts() {
        val emergency = ActivePeriod(start = nz(2026, 12, 15), end = nz(2027, 1, 15))
        val register = SpeedLimitRegister(
            zones = listOf(
                zone(100, "ROAD", size = 1.0),
                zone(30, "SEASONAL", size = 0.3, kind = ZoneKind.seasonal, period = summer),
                zone(50, "DIVERSION", size = 0.6, kind = ZoneKind.emergency, period = emergency),
            ),
        )
        assertEquals(50, register.lookup(inside, at = nz(2026, 12, 20))?.limit)
        assertEquals(30, register.lookup(inside, at = nz(2026, 12, 1))?.limit)
        assertEquals(30, register.lookup(inside, at = nz(2027, 1, 20))?.limit)
        assertEquals(100, register.lookup(inside, at = nz(2027, 6, 1))?.limit)
    }

    @Test
    fun anOverEmergencyLimitIsIgnored() {
        val over = ActivePeriod(start = nz(2023, 8, 18), end = nz(2024, 8, 17))
        val register = SpeedLimitRegister(
            zones = listOf(
                zone(80, "ROAD", size = 1.0),
                zone(50, "DIVERSION", size = 0.2, kind = ZoneKind.emergency, period = over),
            ),
        )
        assertEquals(80, register.lookup(inside, at = now)?.limit)
    }

    @Test
    fun equalKindsStillUseTheSmallestZone() {
        val register = SpeedLimitRegister(zones = listOf(zone(50, "BIG", size = 1.0), zone(30, "SMALL", size = 0.2)))
        assertEquals("SMALL", register.lookup(inside, at = now)?.zoneName)
    }

    private fun bridge(overpass: Int, underpass: Int): SpeedLimitRegister = SpeedLimitRegister(
        zones = listOf(
            zone(100, "AREA", size = 1.0),
            zone(overpass, "BRIDGE", size = 0.1, structure = StructureType.overpass),
            zone(underpass, "ROAD UNDER", size = 0.12, structure = StructureType.underpass),
        ),
    )

    @Test
    fun withNoPreviousZoneAMismatchedBridgeTakesTheLowerLimit() {
        assertEquals(50, bridge(overpass = 80, underpass = 50).lookup(inside, at = now)?.limit)
        assertEquals(50, bridge(overpass = 50, underpass = 80).lookup(inside, at = now)?.limit)
    }

    @Test
    fun youStayOnTheLevelYouWereOn() {
        val register = bridge(overpass = 80, underpass = 50)
        val onBridge = register.lookup(
            inside,
            at = now,
            preferring = SpeedLimitMatch(limit = 80, zoneName = "BRIDGE", kind = ZoneKind.permanent, zoneID = 1),
        )!!
        assertEquals(80, onBridge.limit)
        assertEquals("BRIDGE", onBridge.zoneName)
        val underneath = register.lookup(
            inside,
            at = now,
            preferring = SpeedLimitMatch(limit = 50, zoneName = "ROAD UNDER", kind = ZoneKind.permanent, zoneID = 2),
        )!!
        assertEquals(50, underneath.limit)
    }

    @Test
    fun aPreviousZoneThatIsntInvolvedDoesNotDecide() {
        val register = bridge(overpass = 80, underpass = 50)
        val unrelated = SpeedLimitMatch(limit = 100, zoneName = "AREA", kind = ZoneKind.permanent, zoneID = 0)
        assertEquals(50, register.lookup(inside, at = now, preferring = unrelated)?.limit)
    }

    @Test
    fun matchingBridgeLimitsAreNotAmbiguous() {
        assertEquals(50, bridge(overpass = 50, underpass = 50).lookup(inside, at = now)?.limit)
    }

    @Test
    fun aBridgeWithNoRoadUnderItJustUsesItsOwnLimit() {
        val register = SpeedLimitRegister(
            zones = listOf(
                zone(100, "AREA", size = 1.0),
                zone(80, "BRIDGE", size = 0.1, structure = StructureType.overpass),
            ),
        )
        assertEquals(80, register.lookup(inside, at = now)?.limit)
    }

    @Test
    fun offTheBridgeNothingSpecialHappens() {
        val away = Coordinate(latitude = -40.2, longitude = 174.8)
        assertEquals(100, bridge(overpass = 80, underpass = 50).lookup(away, at = now)?.limit)
    }

    @Test
    fun intersectionsAreOrdinaryZones() {
        val register = SpeedLimitRegister(
            zones = listOf(
                zone(80, "ROAD", size = 1.0),
                zone(50, "JUNCTION", size = 0.1, structure = StructureType.intersection),
            ),
        )
        assertEquals(50, register.lookup(inside, at = now)?.limit)
    }

    @Test
    fun matchesCompareByWhatTheDriverSees() {
        assertEquals(
            SpeedLimitMatch(limit = 50, zoneName = "A", kind = ZoneKind.permanent, zoneID = 1),
            SpeedLimitMatch(limit = 50, zoneName = "A", kind = ZoneKind.permanent, zoneID = 7),
        )
        assertNotEquals(
            SpeedLimitMatch(limit = 50, zoneName = "A", kind = ZoneKind.permanent),
            SpeedLimitMatch(limit = 50, zoneName = "A", kind = ZoneKind.seasonal),
        )
    }

    private fun sample(at: Coordinate, second: Long): Pair<LocationSample, Instant> {
        val t = now.plusSeconds(second)
        return LocationSample(
            coordinate = at,
            speedMetresPerSecond = 10.0,
            horizontalAccuracy = 5.0,
            timestamp = t,
        ) to t
    }

    @Test
    fun theEngineStaysOnTheRoadItArrivedOn() {
        val register = SpeedLimitRegister(
            zones = listOf(
                SpeedZone(
                    name = "ROAD UNDER",
                    limit = 50,
                    structure = StructureType.underpass,
                    polygons = listOf(
                        Polygon(
                            outer = Ring(
                                listOf(
                                    Coordinate(latitude = -41.0, longitude = 174.0),
                                    Coordinate(latitude = -41.0, longitude = 174.3),
                                    Coordinate(latitude = -40.9, longitude = 174.3),
                                    Coordinate(latitude = -40.9, longitude = 174.0),
                                ),
                            )!!,
                        ),
                    ),
                )!!,
                SpeedZone(
                    name = "BRIDGE",
                    limit = 80,
                    structure = StructureType.overpass,
                    polygons = listOf(
                        Polygon(
                            outer = Ring(
                                listOf(
                                    Coordinate(latitude = -41.2, longitude = 174.1),
                                    Coordinate(latitude = -41.2, longitude = 174.2),
                                    Coordinate(latitude = -40.7, longitude = 174.2),
                                    Coordinate(latitude = -40.7, longitude = 174.1),
                                ),
                            )!!,
                        ),
                    ),
                )!!,
            ),
        )
        val roadOnly = Coordinate(latitude = -40.95, longitude = 174.02)
        val bridgeOnly = Coordinate(latitude = -40.75, longitude = 174.15)
        val crossing = Coordinate(latitude = -40.95, longitude = 174.15)
        fun limit(from: Coordinate): Int? {
            val engine = DriveEngine(register = register, registerCheckedAt = now)
            var out: Int? = null
            for ((i, point) in listOf(from, from, crossing, crossing, crossing).withIndex()) {
                val (sample, t) = sample(point, i.toLong())
                out = engine.ingest(sample, now = t).snapshot.limit
            }
            return out
        }
        assertEquals(50, limit(roadOnly))
        assertEquals(80, limit(bridgeOnly))
    }

    @Test
    fun replacingTheRegisterForgetsThePreviousZone() {
        val engine = DriveEngine(
            register = SpeedLimitRegister(zones = listOf(zone(50, "A", size = 1.0))),
            registerCheckedAt = now,
        )
        val (sample, t) = sample(inside, 0)
        assertEquals(50, engine.ingest(sample, now = t).snapshot.limit)
        engine.register = SpeedLimitRegister(zones = listOf(zone(70, "B", size = 1.0)))
        val (sample2, t2) = sample(inside, 1)
        assertEquals(70, engine.ingest(sample2, now = t2).snapshot.limit)
    }
}
