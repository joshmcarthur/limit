package com.joshmcarthur.limit.core

import java.time.Duration
import java.time.Instant

/** What the store remembers about trying to sync, so the limits below hold across launches. */
data class SyncAttempts(
    var lastAttemptAt: Instant? = null,
    /** Attempts since the last success. Counted when an attempt starts. */
    var consecutiveFailures: Int = 0,
)

/**
 * How often the app may ask the source for anything. Opening the app never causes more requests than this
 * allows; only the person tapping Retry goes faster, and not faster than [manualFloor].
 */
data class SyncSchedule(
    /** Between automatic checks when a stored copy exists. */
    var checkInterval: Duration = Duration.ofSeconds(7 * 86_400),
    /** Wait after the 1st, 2nd, 3rd... failure in a row; the last value repeats. */
    var backoff: List<Duration> = listOf(
        Duration.ofSeconds(15 * 60),
        Duration.ofSeconds(3_600),
        Duration.ofSeconds(6 * 3_600),
        Duration.ofSeconds(86_400),
    ),
    /** The shortest gap between attempts when the person asked for the check. */
    var manualFloor: Duration = Duration.ofSeconds(5 * 60),
) {
    sealed class Decision {
        data object Now : Decision()
        data class Wait(val until: Instant) : Decision()
    }

    /**
     * [lastSuccessAt] is when the stored copy was last checked or downloaded; null if there's no copy.
     */
    fun decision(
        attempts: SyncAttempts,
        lastSuccessAt: Instant?,
        now: Instant,
        userInitiated: Boolean,
    ): Decision {
        val lastAttempt = attempts.lastAttemptAt?.let { if (it < now) it else now }
        if (userInitiated) {
            if (lastAttempt != null && lastAttempt.plus(manualFloor) > now) {
                return Decision.Wait(until = lastAttempt.plus(manualFloor))
            }
            return Decision.Now
        }
        var due = Instant.EPOCH
        if (lastSuccessAt != null) {
            val success = if (lastSuccessAt < now) lastSuccessAt else now
            due = success.plus(checkInterval)
        }
        if (attempts.consecutiveFailures > 0 && lastAttempt != null) {
            val step = if (backoff.isEmpty()) {
                Duration.ZERO
            } else {
                backoff[minOf(attempts.consecutiveFailures - 1, backoff.size - 1)]
            }
            val backedOff = lastAttempt.plus(step)
            if (backedOff > due) due = backedOff
        }
        return if (due > now) Decision.Wait(until = due) else Decision.Now
    }

    companion object {
        val standard: SyncSchedule = SyncSchedule()
    }
}
