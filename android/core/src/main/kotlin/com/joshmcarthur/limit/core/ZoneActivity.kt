package com.joshmcarthur.limit.core

import java.time.DateTimeException
import java.time.Instant
import java.time.ZoneId
import java.time.ZonedDateTime

/** What sort of limit a record is, from the register's `speedCategoryName`. */
enum class ZoneKind(val rawValue: Int) {
    permanent(0),

    /** Changes under set conditions (school zones, highway variable-speed signs). */
    variable(1),

    /** Applies on certain dates, for example a holiday period. */
    seasonal(2),

    /** The register calls these "Temporary"; they are emergency limits such as a diversion after a closure. */
    emergency(3),
    ;

    /**
     * Which limit wins where records overlap: the register allows an emergency limit over a seasonal one
     * and a seasonal one over a permanent or variable one, never permanent over variable.
     */
    val priority: Int
        get() = when (this) {
            emergency -> 3
            seasonal -> 2
            permanent, variable -> 1
        }

    /** Limits that apply for a while and then stop, so it's worth telling the driver which one this is. */
    val isTemporaryByNature: Boolean
        get() = this == seasonal || this == emergency

    companion object {
        /** Null, or anything we don't recognise, counts as permanent: the limit is shown rather than hidden. */
        operator fun invoke(category: String?): ZoneKind =
            when (category?.trimWhitespaces()?.lowercase()) {
                "variable" -> variable
                "seasonal" -> seasonal
                "temporary", "emergency" -> emergency
                else -> permanent
            }

        fun fromRaw(raw: Int): ZoneKind? = entries.firstOrNull { it.rawValue == raw }
    }
}

/** Where a record sits relative to the road, from `speedLimitZoneStructureTypeName`. */
enum class StructureType(val rawValue: Int) {
    none(0),
    overpass(1),
    underpass(2),
    intersection(3),
    ;

    /** A bridge and the road under it cover the same point, and a position can't say which level you're on. */
    val isGradeSeparated: Boolean
        get() = this == overpass || this == underpass

    companion object {
        operator fun invoke(name: String?): StructureType =
            when (name?.trimWhitespaces()?.lowercase()) {
                "overpass" -> overpass
                "underpass" -> underpass
                "intersection" -> intersection
                else -> none
            }

        fun fromRaw(raw: Int): StructureType? = entries.firstOrNull { it.rawValue == raw }
    }
}

/** The dates a record applies. Days are NZ calendar days and both ends are inclusive. */
class ActivePeriod private constructor(
    /** First day it applies; null means from the beginning. */
    val start: Instant?,
    /** Last day it applies; null means no end. */
    val end: Instant?,
    /**
     * A recurring seasonal limit: the same month-and-day window applies every year, whatever year the
     * record's dates are in.
     */
    val repeatsYearly: Boolean,
) {
    fun isActive(at: Instant): Boolean {
        val start = this.start
        val end = this.end
        if (repeatsYearly && start != null && end != null) {
            val s = monthDay(start)
            val e = monthDay(end)
            val d = monthDay(at)
            return if (s <= e) d in s..e else d >= s || d <= e
        }
        if (start != null && at < startOfDay(start)) return false
        if (end != null) {
            val after = startOfDay(end).atZone(zone).toLocalDate().plusDays(1).atStartOfDay(zone).toInstant()
            if (at >= after) return false
        }
        return true
    }

    private fun monthDay(date: Instant): Int {
        val parts = date.atZone(zone)
        return parts.monthValue * 100 + parts.dayOfMonth
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is ActivePeriod) return false
        return start == other.start && end == other.end && repeatsYearly == other.repeatsYearly
    }

    override fun hashCode(): Int {
        var result = start?.hashCode() ?: 0
        result = 31 * result + (end?.hashCode() ?: 0)
        result = 31 * result + repeatsYearly.hashCode()
        return result
    }

    companion object {
        private val zone: ZoneId = ReducedLimit.timeZone

        operator fun invoke(start: Instant?, end: Instant?, repeatsYearly: Boolean = false): ActivePeriod? {
            if (start == null && end == null) return null
            if (start != null && end != null && end < start) return null
            if (repeatsYearly && (start == null || end == null)) return null
            return ActivePeriod(start?.let(::noon), end?.let(::noon), repeatsYearly)
        }

        /** A day as `yyyymmdd` (for example 20211201), the form kept on disk. */
        fun pack(date: Instant): Int {
            val parts = date.atZone(zone)
            return parts.year * 10_000 + parts.monthValue * 100 + parts.dayOfMonth
        }

        fun unpack(packed: Int): Instant? {
            val year = packed / 10_000
            val month = packed / 100 % 100
            val day = packed % 100
            if (year !in 1..9999 || month !in 1..12 || day !in 1..31) return null
            return try {
                ZonedDateTime.of(year, month, day, 12, 0, 0, 0, zone).toInstant()
            } catch (_: DateTimeException) {
                null
            }
        }

        private fun noon(date: Instant): Instant {
            val parts = date.atZone(zone)
            return ZonedDateTime.of(parts.year, parts.monthValue, parts.dayOfMonth, 12, 0, 0, 0, zone).toInstant()
        }

        private fun startOfDay(date: Instant): Instant =
            date.atZone(zone).toLocalDate().atStartOfDay(zone).toInstant()
    }
}

internal fun String.trimWhitespaces(): String = trim { it.isHorizontalWhitespace() }

internal fun String.trimWhitespacesAndNewlines(): String = trim { it.isWhitespace() }

private fun Char.isHorizontalWhitespace(): Boolean =
    this == '\t' || (isWhitespace() && this != '\n' && this != '\r' && this != '\u000B' && this != '\u000C' &&
        this != '\u0085' && this != '\u2028' && this != '\u2029')
