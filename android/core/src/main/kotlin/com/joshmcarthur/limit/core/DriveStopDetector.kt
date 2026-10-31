package com.joshmcarthur.limit.core

import java.time.Duration
import java.time.Instant

/** How the phone is travelling, as far as the drive-stop check cares. */
enum class TravelMode {
    driving,

    /** Walking, running or cycling: the person has left the car, or never was in one. */
    onFoot,

    /** Stationary or unknown. A stopped car reads as this too, so it says nothing either way. */
    other,
}

/**
 * Decides when a drive has probably ended, so location isn't left running in a pocket.
 * Motion is not wired on Android v1; the GPS idle path still ends a drive.
 */
class DriveStopDetector {
    enum class Action { none, ping, end }

    var onFootFor: Duration = Duration.ofSeconds(60)
    var answerWithin: Duration = Duration.ofSeconds(600)
    var idleFor: Duration = Duration.ofSeconds(900)

    /** Below this (km/h) the car counts as not moving. */
    var idleBelow: Int = 3

    private var onFootSince: Instant? = null
    private var pingedAt: Instant? = null
    private var idleSince: Instant? = null

    /** "Keep driving" was chosen: no more pings until the phone is seen driving again. */
    private var keeping = false

    fun observe(mode: TravelMode, at: Instant) {
        when (mode) {
            TravelMode.driving -> {
                onFootSince = null
                pingedAt = null
                keeping = false
            }
            TravelMode.onFoot -> if (onFootSince == null) onFootSince = at
            TravelMode.other -> Unit
        }
    }

    /** Null (no GPS speed) counts as not moving, since the battery is being spent either way. */
    fun observe(speedKmh: Int?, at: Instant) {
        if (speedKmh != null && speedKmh >= idleBelow) {
            idleSince = null
        } else if (idleSince == null) {
            idleSince = at
        }
    }

    /**
     * The person said the drive isn't over: wait for another fifteen minutes of stillness, and don't ask
     * again until they've been seen driving.
     */
    fun keepDriving(at: Instant) {
        keeping = true
        onFootSince = null
        pingedAt = null
        idleSince = at
    }

    fun evaluate(at: Instant): Action {
        val pinged = pingedAt
        if (pinged != null && Duration.between(pinged, at) >= answerWithin) return Action.end
        val idle = idleSince
        if (idle != null && Duration.between(idle, at) >= idleFor) return Action.end
        val onFoot = onFootSince
        if (!keeping && pingedAt == null && onFoot != null && Duration.between(onFoot, at) >= onFootFor) {
            pingedAt = at
            return Action.ping
        }
        return Action.none
    }
}
