package com.joshmcarthur.limit.core

import java.time.Duration
import java.time.ZoneId
import java.time.ZonedDateTime
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse

class SyncStateTest {
    private val zone: ZoneId = ZoneId.of("Pacific/Auckland")

    private fun date(y: Int, m: Int, d: Int, h: Int = 0, min: Int = 0) =
        ZonedDateTime.of(y, m, d, h, min, 0, 0, zone).toInstant()

    @Test
    fun today() {
        val now = date(2026, 10, 22, 15, 0)
        assertEquals("today, 6:40 am", FreshnessText.`when`(date(2026, 10, 22, 6, 40), now, zone))
        assertEquals("today, 12:05 pm", FreshnessText.`when`(date(2026, 10, 22, 12, 5), now, zone))
        assertEquals("today, 12:09 am", FreshnessText.`when`(date(2026, 10, 22, 0, 9), now, zone))
    }

    @Test
    fun yesterdayAndOlder() {
        val now = date(2026, 10, 22, 15, 0)
        assertEquals("yesterday", FreshnessText.`when`(date(2026, 10, 21, 23, 0), now, zone))
        assertEquals("3 Oct", FreshnessText.`when`(date(2026, 10, 3, 9, 0), now, zone))
    }

    @Test
    fun restingState() {
        val now = date(2026, 10, 22)
        assertEquals(SyncState.NeverSynced, SyncState.resting(checkedAt = null, now = now))
        val yesterday = now.minus(Duration.ofSeconds(86_400))
        assertEquals(SyncState.UpToDate(yesterday), SyncState.resting(checkedAt = yesterday, now = now))
        val old = now.minus(Duration.ofSeconds(40 * 86_400))
        assertEquals(SyncState.Stale(old), SyncState.resting(checkedAt = old, now = now))
    }

    @Test
    fun footerMatchesDesign() {
        val now = date(2026, 10, 22, 15, 0)
        val state = SyncState.UpToDate(checkedAt = date(2026, 10, 22, 6, 40))
        assertEquals("Speed limits checked today, 6:40 am", FreshnessText.footer(state, now, zone))
        assertEquals("Speed limits not downloaded yet", FreshnessText.footer(SyncState.NeverSynced, now, zone))
    }

    @Test
    fun rowCopy() {
        val now = date(2026, 10, 22, 15, 0)
        val row = FreshnessText.row(SyncState.Updating(progress = 0.42), now, zone)
        assertEquals("Updating speed limits\u2026", row.title)
        assertEquals("42% \u00B7 NZTA National Speed Limit Register", row.subtitle)
        val failed = FreshnessText.row(SyncState.Failed(lastChecked = date(2026, 10, 3)), now, zone)
        assertEquals("Still using speed limit data from 3 Oct.", failed.subtitle)
        assertEquals("Couldn\u2019t update the speed limit database", failed.title)
        assertFalse(failed.subtitle.lowercase().contains("error"))
        val nothingYet = FreshnessText.row(SyncState.Failed(lastChecked = null), now, zone)
        assertEquals("There's no speed limit data on this phone yet.", nothingYet.subtitle)
    }
}
