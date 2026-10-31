package com.joshmcarthur.limit.core

import java.time.DayOfWeek
import java.time.Instant
import java.time.ZoneId

/** A span of the day, in minutes after midnight, with `start < end`. */
class TimeWindow private constructor(
    val startMinute: Int,
    val endMinute: Int,
) {
    fun contains(minute: Int): Boolean = minute >= startMinute && minute < endMinute

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is TimeWindow) return false
        return startMinute == other.startMinute && endMinute == other.endMinute
    }

    override fun hashCode(): Int = 31 * startMinute + endMinute

    companion object {
        operator fun invoke(startMinute: Int, endMinute: Int): TimeWindow? {
            if (startMinute < 0 || endMinute > 24 * 60 || startMinute >= endMinute) return null
            return TimeWindow(startMinute, endMinute)
        }
    }
}

/**
 * A lower limit that applies to a zone on school days during set windows (a school zone).
 * The register doesn't hold term dates, so every weekday counts as a school day.
 */
class ReducedLimit private constructor(
    val limit: Int,
    val windows: List<TimeWindow>,
) {
    fun isActive(at: Instant): Boolean {
        val parts = at.atZone(timeZone)
        val weekday = parts.dayOfWeek
        if (weekday == DayOfWeek.SATURDAY || weekday == DayOfWeek.SUNDAY) return false
        val minute = parts.hour * 60 + parts.minute
        return windows.any { it.contains(minute) }
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ReducedLimit) return false
        return limit == other.limit && windows == other.windows
    }

    override fun hashCode(): Int = 31 * limit + windows.hashCode()

    companion object {
        val timeZone: ZoneId = ZoneId.of("Pacific/Auckland")

        operator fun invoke(limit: Int, windows: List<TimeWindow>): ReducedLimit? {
            if (windows.isEmpty()) return null
            return ReducedLimit(limit, windows)
        }
    }
}

/**
 * Reads the clock times out of the register's free-text "periods of operation" (`speedLimitZoneVarPrdDesc`).
 *
 * The text has hundreds of wordings. Anything that doesn't yield one or two plain windows returns null, so
 * the zone just keeps its permanent limit rather than showing a guess.
 */
object SchoolPeriodParser {
    // Android ICU treats `[:` as a POSIX property class, so `[:.]` plus a later `:]`
    // is "Incorrect Unicode property". JVM java.util.regex does not. Put the colon
    // second (`[.:]`). ICU also rejects \\d/\\s in lookaround; use ASCII digits there.
    private val time = Regex(
        """(?<![0-9.])([0-9]{1,2})(?:[.:]([0-9]{2}))?(?![0-9:])\s*(am|pm|a\.m\.|p\.m\.)?""",
        RegexOption.IGNORE_CASE,
    )

    /**
     * Wording that singles out days ("Thursday only", "2.30pm on Wednesdays") means the times differ by
     * day, which one set of windows can't express.
     */
    private val dayNames = Regex(
        """\b(mon|tues|wednes|thurs|fri|satur|sun)day""",
        RegexOption.IGNORE_CASE,
    )

    private class Token(
        val hour: Int,
        val minute: Int,
        val isPM: Boolean?,
    )

    fun windows(from: String): List<TimeWindow>? {
        if (dayNames.containsMatchIn(from)) return null
        val tokens = mutableListOf<Token>()
        for (match in time.findAll(from)) {
            val hasMinutes = match.groups[2] != null
            val hasMeridiem = match.groups[3] != null
            if (!hasMinutes && !hasMeridiem) continue
            val hour = match.groups[1]?.value?.toIntOrNull() ?: continue
            val minute = if (hasMinutes) match.groups[2]?.value?.toIntOrNull() ?: 0 else 0
            val hourOk = hour in 1..12 || (hour in 13..23 && !hasMeridiem)
            if (!hourOk || minute >= 60) continue
            val meridiem = if (hasMeridiem) match.groups[3]!!.value.lowercase().startsWith("p") else null
            tokens.add(Token(hour, minute, meridiem))
        }
        if (tokens.size != 2 && tokens.size != 4) return null

        val windows = mutableListOf<TimeWindow>()
        var index = 0
        while (index < tokens.size) {
            val window = window(start = tokens[index], end = tokens[index + 1]) ?: return null
            windows.add(window)
            index += 2
        }
        for (i in 0 until windows.size - 1) {
            if (windows[i].endMinute > windows[i + 1].startMinute) return null
        }
        return windows
    }

    private fun window(start: Token, end: Token): TimeWindow? {
        val endPM = end.isPM ?: if (end.hour >= 13) true else return null
        val endMinute = minutes(end, endPM)
        var startMinute = minutes(start, start.isPM ?: endPM)
        if (start.isPM == null && startMinute >= endMinute) startMinute = minutes(start, !endPM)
        val result = TimeWindow(startMinute = startMinute, endMinute = endMinute) ?: return null
        if (result.endMinute - result.startMinute > 3 * 60) return null
        if (result.startMinute < 5 * 60 || result.endMinute > 19 * 60) return null
        return result
    }

    private fun minutes(token: Token, pm: Boolean): Int {
        if (token.hour >= 13) return token.hour * 60 + token.minute
        val hour = token.hour % 12 + if (pm) 12 else 0
        return hour * 60 + token.minute
    }
}
