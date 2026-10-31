package com.joshmcarthur.limit.core

sealed class OverLimitState {
    data object NotOver : OverLimitState()

    /** Whole km/h above the limit. */
    data class Over(val by: Int) : OverLimitState()

    val isOver: Boolean
        get() = this is Over
}

/**
 * Decides when to show "over". Triggers once the driver is `tolerance` km/h or more above the limit and
 * clears with hysteresis, so the readout doesn't flicker at the boundary.
 */
class OverLimitEvaluator(tolerance: Int = defaultTolerance) {
    var tolerance: Int = clamp(tolerance)
        private set

    private var isOver = false

    fun setTolerance(value: Int) {
        tolerance = clamp(value)
    }

    /** Both inputs are whole km/h as displayed. A missing speed or limit always clears the state. */
    fun evaluate(speed: Int?, limit: Int?): OverLimitState {
        if (speed == null || limit == null) {
            isOver = false
            return OverLimitState.NotOver
        }
        val delta = speed - limit
        val clearAt = maxOf(tolerance - 2, 0)
        if (isOver) {
            if (delta <= clearAt) isOver = false
        } else if (delta >= tolerance) {
            isOver = true
        }
        return if (isOver) OverLimitState.Over(by = maxOf(delta, 0)) else OverLimitState.NotOver
    }

    companion object {
        val toleranceRange: IntRange = 1..10
        const val defaultTolerance: Int = 3

        private fun clamp(value: Int): Int = value.coerceIn(toleranceRange)
    }
}
