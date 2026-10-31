package com.joshmcarthur.limit.core

import java.time.Duration
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals

class SyncScheduleTest {
    private val schedule = SyncSchedule.standard
    private val now: Instant = Instant.ofEpochSecond(10_000_000)
    private val week: Duration = Duration.ofSeconds(7 * 86_400)

    private fun decide(
        attempts: SyncAttempts = SyncAttempts(),
        success: Instant? = null,
        manual: Boolean = false,
    ): SyncSchedule.Decision = schedule.decision(attempts, success, now, manual)

    @Test
    fun nothingStoredAndNothingTriedGoesNow() {
        assertEquals(SyncSchedule.Decision.Now, decide())
    }

    @Test
    fun aFreshCopyWaitsUntilAWeekAfterItsLastCheck() {
        val checked = now.minusSeconds(86_400)
        assertEquals(SyncSchedule.Decision.Wait(checked.plus(week)), decide(success = checked))
        assertEquals(SyncSchedule.Decision.Now, decide(success = now.minus(week)))
    }

    @Test
    fun backOffStepsAndRepeatsTheLast() {
        val last = now.minusSeconds(1)
        val steps = listOf(15 * 60L, 3_600L, 6 * 3_600L, 86_400L, 86_400L, 86_400L)
        for ((i, step) in steps.withIndex()) {
            val attempts = SyncAttempts(lastAttemptAt = last, consecutiveFailures = i + 1)
            assertEquals(SyncSchedule.Decision.Wait(last.plusSeconds(step)), decide(attempts))
        }
    }

    @Test
    fun backOffEndsAndTheNextAttemptIsAllowed() {
        val attempts = SyncAttempts(lastAttemptAt = now.minusSeconds(15 * 60), consecutiveFailures = 1)
        assertEquals(SyncSchedule.Decision.Now, decide(attempts))
    }

    @Test
    fun theLaterOfTheWeekAndTheBackOffWins() {
        val checked = now.minusSeconds(6 * 86_400)
        val attempts = SyncAttempts(lastAttemptAt = now.minusSeconds(60), consecutiveFailures = 1)
        assertEquals(SyncSchedule.Decision.Wait(checked.plus(week)), decide(attempts, success = checked))
    }

    @Test
    fun manualChecksIgnoreTheWeekAndTheBackOff() {
        val attempts = SyncAttempts(lastAttemptAt = now.minusSeconds(10 * 60), consecutiveFailures = 4)
        assertEquals(SyncSchedule.Decision.Now, decide(attempts, success = now.minusSeconds(3_600), manual = true))
    }

    @Test
    fun manualChecksKeepTheFloor() {
        val last = now.minusSeconds(60)
        assertEquals(
            SyncSchedule.Decision.Wait(last.plusSeconds(5 * 60)),
            decide(SyncAttempts(lastAttemptAt = last, consecutiveFailures = 0), manual = true),
        )
    }

    @Test
    fun aClockSetBackwardsCannotLockTheAppOutForLong() {
        val future = now.plusSeconds(30 * 86_400)
        assertEquals(
            SyncSchedule.Decision.Wait(now.plus(week)),
            decide(SyncAttempts(lastAttemptAt = future, consecutiveFailures = 1), success = future),
        )
    }
}
