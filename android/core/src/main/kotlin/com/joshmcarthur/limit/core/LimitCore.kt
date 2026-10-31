package com.joshmcarthur.limit.core

/**
 * Platform-independent logic for Limit: geometry, the speed limit register,
 * over-limit evaluation and the state shown by every driving surface.
 */
object LimitCore {
    const val registerName = "NZTA National Speed Limit Register"

    /** The credit shown on the drive screen and the ongoing notification. The About screen carries the full CC BY 4.0 credit. */
    const val attribution = "Data from Waka Kotahi’s National Speed Limit Register"

    /**
     * Sent with every request to the source, so its operators can see who is asking and get in touch.
     */
    fun userAgent(version: String = "dev"): String =
        "Limit-Android/$version (+https://github.com/joshmcarthur/limit)"
}
