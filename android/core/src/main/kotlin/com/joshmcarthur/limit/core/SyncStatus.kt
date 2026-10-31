package com.joshmcarthur.limit.core

import java.time.Instant

/**
 * What the register sync is doing and when the stored copy was last checked. The [SyncState] shown to the
 * driver is worked out from this each time it is read.
 */
class SyncStatus(checkedAt: Instant? = null) {
    sealed class Activity {
        data object Idle : Activity()

        /** [progress] is 0...1, or null when the total is unknown. */
        data class Updating(val progress: Double?) : Activity()
        data object Failed : Activity()
    }

    var checkedAt: Instant? = checkedAt
        private set

    var activity: Activity = Activity.Idle
        private set

    val isUpdating: Boolean
        get() = activity is Activity.Updating

    fun state(now: Instant, policy: FreshnessPolicy = FreshnessPolicy.standard): SyncState = when (val current = activity) {
        Activity.Idle -> SyncState.resting(checkedAt = checkedAt, now = now, policy = policy)
        is Activity.Updating -> SyncState.Updating(progress = current.progress)
        Activity.Failed -> SyncState.Failed(lastChecked = checkedAt)
    }

    /** An update is running; the first call starts it. */
    fun progressed(progress: Double?) {
        activity = Activity.Updating(progress)
    }

    /** The stored copy was checked at [date], whether or not it needed replacing. */
    fun finished(checkedAt: Instant) {
        this.checkedAt = checkedAt
        activity = Activity.Idle
    }

    /** The last check is kept, since the copy on the phone is still the one in use. */
    fun failed() {
        activity = Activity.Failed
    }
}
