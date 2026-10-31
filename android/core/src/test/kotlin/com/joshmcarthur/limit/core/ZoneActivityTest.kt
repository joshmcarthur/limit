package com.joshmcarthur.limit.core

import java.time.Instant
import java.time.OffsetDateTime
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class ZoneActivityTest {
    private val zone: ZoneId = ReducedLimit.timeZone

    private fun nz(y: Int, m: Int, d: Int, h: Int = 12, min: Int = 0): Instant =
        ZonedDateTime.of(y, m, d, h, min, 0, 0, zone).toInstant()

    @Test
    fun categoryNamesMapToKinds() {
        assertEquals(ZoneKind.permanent, ZoneKind(category = "Permanent"))
        assertEquals(ZoneKind.variable, ZoneKind(category = "Variable"))
        assertEquals(ZoneKind.seasonal, ZoneKind(category = "Seasonal"))
        assertEquals(ZoneKind.emergency, ZoneKind(category = "Temporary"))
        assertEquals(ZoneKind.seasonal, ZoneKind(category = " seasonal "))
    }

    @Test
    fun unknownOrMissingCategoryIsPermanentSoTheLimitStillShows() {
        assertEquals(ZoneKind.permanent, ZoneKind(category = null))
        assertEquals(ZoneKind.permanent, ZoneKind(category = ""))
        assertEquals(ZoneKind.permanent, ZoneKind(category = "Something new"))
    }

    @Test
    fun priorityFollowsTheRegistersOverlapRules() {
        assertTrue(ZoneKind.emergency.priority > ZoneKind.seasonal.priority)
        assertTrue(ZoneKind.seasonal.priority > ZoneKind.permanent.priority)
        assertEquals(ZoneKind.permanent.priority, ZoneKind.variable.priority)
    }

    @Test
    fun onlySeasonalAndEmergencyAreTemporaryByNature() {
        assertEquals(
            listOf(false, false, true, true),
            listOf(ZoneKind.permanent, ZoneKind.variable, ZoneKind.seasonal, ZoneKind.emergency).map { it.isTemporaryByNature },
        )
    }

    @Test
    fun structureTypes() {
        assertEquals(StructureType.overpass, StructureType(name = "Overpass"))
        assertEquals(StructureType.underpass, StructureType(name = "Underpass"))
        assertEquals(StructureType.intersection, StructureType(name = "Intersection"))
        assertEquals(StructureType.none, StructureType(name = null))
        assertEquals(StructureType.none, StructureType(name = "Roundabout"))
        assertTrue(StructureType.overpass.isGradeSeparated)
        assertTrue(StructureType.underpass.isGradeSeparated)
        assertFalse(StructureType.intersection.isGradeSeparated)
        assertFalse(StructureType.none.isGradeSeparated)
    }

    @Test
    fun aDatedPeriodIncludesBothEndDays() {
        val period = ActivePeriod(start = nz(2023, 8, 18, 0, 0), end = nz(2024, 8, 17, 0, 0))!!
        assertFalse(period.isActive(nz(2023, 8, 17, 23, 59)))
        assertTrue(period.isActive(nz(2023, 8, 18, 0, 0)))
        assertTrue(period.isActive(nz(2024, 8, 17, 23, 59)))
        assertFalse(period.isActive(nz(2024, 8, 18, 0, 0)))
    }

    @Test
    fun anEndedPeriodStaysEnded() {
        val period = ActivePeriod(start = nz(2023, 8, 18), end = nz(2024, 8, 17))!!
        assertFalse(period.isActive(nz(2026, 10, 22)))
    }

    @Test
    fun anOpenEndedPeriodNeverEnds() {
        val period = ActivePeriod(start = nz(2022, 5, 26), end = null)!!
        assertFalse(period.isActive(nz(2022, 5, 25)))
        assertTrue(period.isActive(nz(2040, 1, 1)))
    }

    @Test
    fun aPeriodWithNoStartHasAlwaysBegun() {
        val period = ActivePeriod(start = null, end = nz(2025, 6, 10))!!
        assertTrue(period.isActive(nz(1990, 1, 1)))
        assertTrue(period.isActive(nz(2025, 6, 10, 23, 0)))
        assertFalse(period.isActive(nz(2025, 6, 11, 0, 0)))
    }

    @Test
    fun daysAreNZDaysAcrossDaylightSavingChanges() {
        val ends = ActivePeriod(start = nz(2026, 3, 1), end = nz(2026, 4, 5))!!
        assertTrue(ends.isActive(nz(2026, 4, 5, 23, 59)))
        assertFalse(ends.isActive(nz(2026, 4, 6, 0, 0)))
        val starts = ActivePeriod(start = nz(2026, 9, 27), end = nz(2026, 10, 10))!!
        assertFalse(starts.isActive(nz(2026, 9, 26, 23, 59)))
        assertTrue(starts.isActive(nz(2026, 9, 27, 0, 0)))
    }

    @Test
    fun theSameInstantIsJudgedInNZNotUTC() {
        val period = ActivePeriod(start = nz(2026, 12, 1), end = nz(2026, 12, 31))!!
        val utc = OffsetDateTime.parse("2026-11-30T11:30:00Z").toInstant()
        assertTrue(period.isActive(utc))
    }

    @Test
    fun aYearlyWindowRepeatsInEveryYear() {
        val period = ActivePeriod(start = nz(2021, 12, 1), end = nz(2022, 4, 30), repeatsYearly = true)!!
        assertTrue(period.isActive(nz(2026, 12, 1)))
        assertTrue(period.isActive(nz(2027, 1, 15)))
        assertTrue(period.isActive(nz(2027, 4, 30, 23, 59)))
        assertFalse(period.isActive(nz(2027, 5, 1)))
        assertFalse(period.isActive(nz(2026, 7, 1)))
        assertFalse(period.isActive(nz(2026, 11, 30, 23, 59)))
    }

    @Test
    fun aYearlyWindowInsideOneCalendarYear() {
        val period = ActivePeriod(start = nz(2022, 7, 9), end = nz(2022, 7, 24), repeatsYearly = true)!!
        assertTrue(period.isActive(nz(2026, 7, 9)))
        assertTrue(period.isActive(nz(2026, 7, 24, 23, 59)))
        assertFalse(period.isActive(nz(2026, 7, 8, 23, 59)))
        assertFalse(period.isActive(nz(2026, 7, 25)))
        assertFalse(period.isActive(nz(2026, 1, 1)))
    }

    @Test
    fun aYearlyWindowStartingOnLeapDayStillWorksInOtherYears() {
        val period = ActivePeriod(start = nz(2024, 2, 29), end = nz(2024, 3, 10), repeatsYearly = true)!!
        assertTrue(period.isActive(nz(2026, 3, 1)))
        assertFalse(period.isActive(nz(2026, 2, 27)))
    }

    @Test
    fun aYearlyWindowNeedsBothEnds() {
        assertNull(ActivePeriod(start = nz(2022, 1, 1), end = null, repeatsYearly = true))
        assertNull(ActivePeriod(start = null, end = nz(2022, 1, 1), repeatsYearly = true))
    }

    @Test
    fun noDatesMeansNoPeriod() {
        assertNull(ActivePeriod(start = null, end = null))
        assertNull(ActivePeriod(start = null, end = null, repeatsYearly = true))
    }

    @Test
    fun anEndBeforeTheStartIsRejected() {
        assertNull(ActivePeriod(start = nz(2024, 5, 1), end = nz(2024, 4, 1)))
    }
}
