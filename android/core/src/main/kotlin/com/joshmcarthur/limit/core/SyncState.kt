package com.joshmcarthur.limit.core

import java.time.Duration
import java.time.Instant
import java.time.ZoneId
import kotlin.math.roundToInt

/** How fresh the register data is. Drives the SyncStatus row and the onboarding download card. */
sealed class SyncState {
    data object NeverSynced : SyncState()

    /** [progress] is 0...1, or null when the total is unknown. */
    data class Updating(val progress: Double?) : SyncState()
    data class UpToDate(val checkedAt: Instant) : SyncState()
    data class Stale(val checkedAt: Instant) : SyncState()
    data class Failed(val lastChecked: Instant?) : SyncState()

    companion object {
        fun resting(
            checkedAt: Instant?,
            now: Instant,
            policy: FreshnessPolicy = FreshnessPolicy.standard,
        ): SyncState {
            if (checkedAt == null) return NeverSynced
            return when (policy.level(Duration.between(checkedAt, now))) {
                FreshnessPolicy.Level.Fresh -> UpToDate(checkedAt)
                FreshnessPolicy.Level.Stale, FreshnessPolicy.Level.TooOld -> Stale(checkedAt)
            }
        }
    }
}

/** Copy for freshness: "today, 6:40 am", "yesterday", "3 Oct". Never raw error codes. */
object FreshnessText {
    private val months = listOf("Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec")

    fun `when`(date: Instant, now: Instant, zone: ZoneId = ZoneId.systemDefault()): String {
        val day = date.atZone(zone).toLocalDate()
        val today = now.atZone(zone).toLocalDate()
        if (day == today) {
            val time = date.atZone(zone)
            val hour = time.hour
            val minute = time.minute
            val h12 = if (hour % 12 == 0) 12 else hour % 12
            val padded = if (minute < 10) "0$minute" else minute.toString()
            val suffix = if (hour < 12) "am" else "pm"
            return "today, $h12:$padded $suffix"
        }
        if (day == today.minusDays(1)) return "yesterday"
        val local = date.atZone(zone)
        return "${local.dayOfMonth} ${months[(local.monthValue - 1) % 12]}"
    }

    /** Footer on the driving screen. */
    fun footer(state: SyncState, now: Instant, zone: ZoneId = ZoneId.systemDefault()): String = when (state) {
        is SyncState.UpToDate -> "Speed limits checked ${`when`(state.checkedAt, now, zone)}"
        is SyncState.Stale -> "Speed limits checked ${`when`(state.checkedAt, now, zone)}"
        is SyncState.Updating -> "Updating speed limits\u2026"
        is SyncState.Failed -> {
            val last = state.lastChecked
            if (last != null) "Speed limits last checked ${`when`(last, now, zone)}" else "Speed limits not downloaded yet"
        }
        SyncState.NeverSynced -> "Speed limits not downloaded yet"
    }

    data class Row(val title: String, val subtitle: String)

    /** Title says the state; subtitle says when and from where. */
    fun row(state: SyncState, now: Instant, zone: ZoneId = ZoneId.systemDefault()): Row {
        val source = LimitCore.registerName
        return when (state) {
            is SyncState.UpToDate -> Row(
                title = "Speed limits up to date",
                subtitle = "Checked ${`when`(state.checkedAt, now, zone)} \u00B7 $source",
            )
            is SyncState.Updating -> {
                val detail = state.progress?.let { "${(it * 100).roundToInt()}% \u00B7 " } ?: ""
                Row(title = "Updating speed limits\u2026", subtitle = "$detail$source")
            }
            is SyncState.Stale -> Row(
                title = "Speed limits may be out of date",
                subtitle = "Last updated ${`when`(state.checkedAt, now, zone)} \u00B7 $source",
            )
            is SyncState.Failed -> {
                val last = state.lastChecked
                val using = if (last != null) {
                    "Still using speed limit data from ${`when`(last, now, zone)}."
                } else {
                    "There's no speed limit data on this phone yet."
                }
                Row(title = "Couldn\u2019t update the speed limit database", subtitle = using)
            }
            SyncState.NeverSynced -> Row(title = "Speed limits not downloaded", subtitle = source)
        }
    }
}
