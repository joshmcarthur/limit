package com.joshmcarthur.limit.core

import java.time.Duration

/**
 * How old register data may be before the sign warns, and before it stops showing a limit at all.
 * The thresholds are proposals to tune on device.
 */
data class FreshnessPolicy(
    var staleAfter: Duration = Duration.ofSeconds(30 * 86_400),
    var unknownAfter: Duration = Duration.ofSeconds(180 * 86_400),
) {
    enum class Level {
        Fresh,
        Stale,
        TooOld,
    }

    fun level(age: Duration): Level {
        if (age >= unknownAfter) return Level.TooOld
        if (age >= staleAfter) return Level.Stale
        return Level.Fresh
    }

    companion object {
        val standard: FreshnessPolicy = FreshnessPolicy()
    }
}

/** What the speed sign shows. */
sealed class SignState {
    data class Limit(val value: Int, val isStale: Boolean) : SignState()

    /**
     * The register has only its national default here, which says nothing about this road: it is what
     * covers any street no council has recorded a zone for. Shows no number, so the driver reads the signs.
     */
    data class OpenRoad(val isStale: Boolean) : SignState()

    /** No fix, off the register, or data too old to trust. Never shows the last known limit. */
    data object Unknown : SignState()

    val limit: Int?
        get() = (this as? Limit)?.value

    val isOpenRoad: Boolean
        get() = this is OpenRoad

    companion object {
        fun make(
            limit: Int?,
            dataAge: Duration?,
            isDefaultArea: Boolean = false,
            policy: FreshnessPolicy = FreshnessPolicy.standard,
        ): SignState {
            if (limit == null || dataAge == null) return Unknown
            return when (policy.level(dataAge)) {
                FreshnessPolicy.Level.Fresh ->
                    if (isDefaultArea) OpenRoad(isStale = false) else Limit(limit, isStale = false)
                FreshnessPolicy.Level.Stale ->
                    if (isDefaultArea) OpenRoad(isStale = true) else Limit(limit, isStale = true)
                FreshnessPolicy.Level.TooOld -> Unknown
            }
        }
    }
}

/** Proportions from the SpeedSign component guidelines. */
object SignMetrics {
    fun ringWidth(diameter: Double): Double = diameter * 0.11

    fun numeralSize(diameter: Double, limit: Int): Double =
        diameter * (if (limit >= 100) 0.36 else 0.42)

    /** The stale badge is dropped below 40 pt. */
    fun showsStaleBadge(diameter: Double): Boolean = diameter >= 40.0
}
