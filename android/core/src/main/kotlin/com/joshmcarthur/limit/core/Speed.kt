package com.joshmcarthur.limit.core

import kotlin.math.roundToInt

object Speed {
    /** CoreLocation reports an invalid speed as a negative number; treat that, NaN and infinity as "no speed". */
    fun kilometresPerHour(fromMetresPerSecond: Double): Double? {
        if (!fromMetresPerSecond.isFinite() || fromMetresPerSecond < 0.0) return null
        return fromMetresPerSecond * 3.6
    }

    /** The whole-number speed shown to the driver. */
    fun displayed(kmh: Double?): Int? {
        if (kmh == null || !kmh.isFinite() || kmh < 0.0) return null
        return kmh.roundToInt()
    }
}
