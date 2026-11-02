package com.joshmcarthur.limit.core

import java.time.Duration
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SignStateTest {
    private val day: Duration = Duration.ofSeconds(86_400)

    @Test
    fun freshLimit() {
        assertEquals(SignState.Limit(50, isStale = false), SignState.make(limit = 50, dataAge = day))
    }

    @Test
    fun staleLimitStillShows() {
        assertEquals(SignState.Limit(50, isStale = true), SignState.make(limit = 50, dataAge = day.multipliedBy(31)))
    }

    @Test
    fun tooOldIsUnknown() {
        assertEquals(SignState.Unknown, SignState.make(limit = 50, dataAge = day.multipliedBy(200)))
    }

    @Test
    fun noLimitOrNoDataIsUnknown() {
        assertEquals(SignState.Unknown, SignState.make(limit = null, dataAge = day))
        assertEquals(SignState.Unknown, SignState.make(limit = 50, dataAge = null))
    }

    @Test
    fun defaultAreaIsOpenRoadNotAHundred() {
        assertEquals(SignState.OpenRoad(isStale = false), SignState.make(limit = 100, dataAge = day, isDefaultArea = true))
        assertEquals(
            SignState.OpenRoad(isStale = true),
            SignState.make(limit = 100, dataAge = day.multipliedBy(31), isDefaultArea = true),
        )
        assertEquals(SignState.Unknown, SignState.make(limit = 100, dataAge = day.multipliedBy(200), isDefaultArea = true))
        assertEquals(SignState.Limit(100, isStale = false), SignState.make(limit = 100, dataAge = day))
        assertNull(SignState.OpenRoad(isStale = false).limit)
    }

    @Test
    fun aListedVariableSpeedDrawsNoNumber() {
        val day = Duration.ofSeconds(86_400)
        assertEquals(
            SignState.VariablePosted(isStale = false),
            SignState.make(limit = 100, dataAge = day, postedLimitUnknown = true),
        )
        assertEquals(
            SignState.VariablePosted(isStale = true),
            SignState.make(limit = 100, dataAge = day.multipliedBy(31), postedLimitUnknown = true),
        )
        assertEquals(
            SignState.Unknown,
            SignState.make(limit = 100, dataAge = day.multipliedBy(200), postedLimitUnknown = true),
        )
        assertNull(SignState.VariablePosted(isStale = false).limit)
        assertFalse(SignState.VariablePosted(isStale = false).isOpenRoad)
    }

    @Test
    fun boundaries() {
        val p = FreshnessPolicy(staleAfter = Duration.ofSeconds(10), unknownAfter = Duration.ofSeconds(20))
        assertEquals(FreshnessPolicy.Level.Fresh, p.level(Duration.ofMillis(9900)))
        assertEquals(FreshnessPolicy.Level.Stale, p.level(Duration.ofSeconds(10)))
        assertEquals(FreshnessPolicy.Level.TooOld, p.level(Duration.ofSeconds(20)))
    }

    @Test
    fun metricsMatchGuidelines() {
        assertEquals(24.2, SignMetrics.ringWidth(diameter = 220.0), 1e-9)
        assertEquals(84.0, SignMetrics.numeralSize(diameter = 200.0, limit = 50), 1e-9)
        assertEquals(72.0, SignMetrics.numeralSize(diameter = 200.0, limit = 100), 1e-9)
        assertTrue(SignMetrics.showsStaleBadge(diameter = 72.0))
        assertFalse(SignMetrics.showsStaleBadge(diameter = 24.0))
    }
}
