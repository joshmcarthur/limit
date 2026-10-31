package com.joshmcarthur.limit.core

/**
 * Holds the zone the sign is showing and moves to a different one only once enough samples in a row agree
 * on it, so a stray fix near a boundary can't flip the limit. The first match after having none is taken
 * at once.
 */
class ZoneConfirmer {
    var current: SpeedLimitMatch? = null
        private set

    private var candidate: SpeedLimitMatch? = null
    private var agreeing = 0

    fun observe(raw: SpeedLimitMatch?, confirmations: Int) {
        val shown = current
        if (shown == null) {
            current = raw
            return
        }
        if (raw == shown) {
            dropCandidate()
            return
        }
        agreeing = if (raw == candidate) agreeing + 1 else 1
        candidate = raw
        if (agreeing >= maxOf(confirmations, 1)) {
            current = raw
            dropCandidate()
        }
    }

    /** Forgets everything, for when what was matched no longer means anything (a gap in GPS, a new register). */
    fun reset() {
        current = null
        dropCandidate()
    }

    private fun dropCandidate() {
        candidate = null
        agreeing = 0
    }
}
