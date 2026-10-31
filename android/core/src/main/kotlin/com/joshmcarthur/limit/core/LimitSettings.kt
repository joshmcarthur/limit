package com.joshmcarthur.limit.core

import org.json.JSONObject

/** User settings, as shown under "While driving" in onboarding and Settings. */
data class LimitSettings(
    var showOnLockScreen: Boolean = true,
    /** Show "over" from this many km/h above the limit. */
    var overTolerance: Int = OverLimitEvaluator.defaultTolerance,
    var hasCompletedOnboarding: Boolean = false,
    /**
     * Notice when the drive looks to be over (the person has got out and is walking, or has been still for
     * a long while) and offer to end it, so location isn't left running in a pocket.
     */
    var suggestEndingDrive: Boolean = true,
) {
    /** "+3 km/h" */
    val toleranceLabel: String
        get() = "+$overTolerance km/h"

    fun encoded(): ByteArray {
        val json = JSONObject()
        json.put("showOnLockScreen", showOnLockScreen)
        json.put("overTolerance", overTolerance)
        json.put("hasCompletedOnboarding", hasCompletedOnboarding)
        json.put("suggestEndingDrive", suggestEndingDrive)
        return json.toString().toByteArray(Charsets.UTF_8)
    }

    companion object {
        /** Missing or unreadable data gives defaults; a newer app's extra keys are ignored. */
        fun decode(data: ByteArray?): LimitSettings {
            if (data == null) return LimitSettings()
            val json = try {
                JSONObject(String(data, Charsets.UTF_8))
            } catch (_: Exception) {
                return LimitSettings()
            }
            val defaults = LimitSettings()
            return LimitSettings(
                showOnLockScreen = if (json.has("showOnLockScreen") && !json.isNull("showOnLockScreen")) {
                    json.getBoolean("showOnLockScreen")
                } else {
                    defaults.showOnLockScreen
                },
                overTolerance = if (json.has("overTolerance") && !json.isNull("overTolerance")) {
                    json.getInt("overTolerance")
                } else {
                    defaults.overTolerance
                },
                hasCompletedOnboarding = if (json.has("hasCompletedOnboarding") && !json.isNull("hasCompletedOnboarding")) {
                    json.getBoolean("hasCompletedOnboarding")
                } else {
                    defaults.hasCompletedOnboarding
                },
                suggestEndingDrive = if (json.has("suggestEndingDrive") && !json.isNull("suggestEndingDrive")) {
                    json.getBoolean("suggestEndingDrive")
                } else {
                    defaults.suggestEndingDrive
                },
            )
        }
    }
}
