package com.joshmcarthur.limit.core

import java.time.Duration

/**
 * When to push content to the Live Activity. The card dims a speed a few seconds after it was sent so a
 * number that has stopped updating can't pass for a live one, which means steady driving (same limit,
 * same speed) has to be re-sent too, or the card dims while everything is fine.
 */
object LiveActivityRefresh {
    /** Seconds between sends when nothing has changed. Comfortably inside [dimAfter]. */
    val heartbeat: Duration = Duration.ofSeconds(3)

    /**
     * How long after a speed is received the card dims it, on its own, if nothing newer has arrived.
     * Longer than the heartbeat, or steady driving would dim between sends.
     */
    val dimAfter: Duration = Duration.ofSeconds(5)

    fun shouldSend(changed: Boolean, secondsSinceLastSend: Duration?): Boolean {
        if (changed) return true
        val elapsed = secondsSinceLastSend ?: return true
        return elapsed >= heartbeat
    }
}
