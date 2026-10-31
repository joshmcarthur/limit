package com.joshmcarthur.limit.core

import java.time.Duration
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SyncStatusTest {
    private val day: Duration = Duration.ofSeconds(86_400)
    private val now: Instant = Instant.ofEpochSecond(10_000_000)

    @Test
    fun nothingCheckedYetIsNeverSynced() {
        assertEquals(SyncState.NeverSynced, SyncStatus().state(now))
    }

    @Test
    fun aCheckedCopyIsUpToDateAndThenStaleAsTimePassesWithoutAnyEvent() {
        val status = SyncStatus()
        status.finished(now)
        assertEquals(SyncState.UpToDate(now), status.state(now.plus(day)))
        assertEquals(SyncState.Stale(now), status.state(now.plus(day.multipliedBy(31))))
    }

    @Test
    fun updatingShowsProgressAndTheFirstReportStartsIt() {
        val status = SyncStatus()
        assertFalse(status.isUpdating)
        status.progressed(null)
        assertTrue(status.isUpdating)
        assertEquals(SyncState.Updating(progress = null), status.state(now))
        status.progressed(0.4)
        assertEquals(SyncState.Updating(progress = 0.4), status.state(now))
    }

    @Test
    fun finishingClearsTheProgressAndRecordsTheCheck() {
        val status = SyncStatus()
        status.progressed(0.9)
        status.finished(now)
        assertFalse(status.isUpdating)
        assertEquals(SyncState.UpToDate(now), status.state(now))
    }

    @Test
    fun aFailureKeepsTheLastCheckBecauseThatCopyIsStillInUse() {
        val earlier = now.minus(day.multipliedBy(3))
        val status = SyncStatus(checkedAt = earlier)
        status.progressed(null)
        status.failed()
        assertFalse(status.isUpdating)
        assertEquals(SyncState.Failed(lastChecked = earlier), status.state(now))
    }

    @Test
    fun aFailureWithNothingStoredHasNoLastCheck() {
        val status = SyncStatus()
        status.failed()
        assertEquals(SyncState.Failed(lastChecked = null), status.state(now))
    }

    @Test
    fun aRetryAfterAFailureCanSucceed() {
        val status = SyncStatus()
        status.failed()
        status.progressed(null)
        assertEquals(SyncState.Updating(progress = null), status.state(now))
        status.finished(now)
        assertEquals(SyncState.UpToDate(now), status.state(now))
    }
}
