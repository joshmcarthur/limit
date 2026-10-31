package com.joshmcarthur.limit.core

/** Whether the app may use the phone's location to find the road you're on. */
enum class LocationAccess {
    notDetermined,
    denied,

    /** Approximate location can't say which road you're on, so limits would show as unknown. */
    reduced,
    authorized,
    ;

    val isUsable: Boolean
        get() = this == authorized
}

/**
 * The lines under the sign on the driving screen. The register credit isn't one of them: it sits at the
 * bottom, beside when the data was last checked.
 */
object DriveScreenText {
    fun headline(isDriving: Boolean, access: LocationAccess, snapshot: DriveSnapshot): String {
        if (!access.isUsable) return "Location needed"
        if (!isDriving) return "Drive ended"
        val road = snapshot.roadName
        if (road != null) return road
        return if (snapshot.limit == null) "Finding your road…" else "Speed limit"
    }

    /** Null when a limit is showing: the road name stands on its own. */
    fun subheadline(isDriving: Boolean, access: LocationAccess, snapshot: DriveSnapshot): String? {
        if (access.isUsable && !isDriving) return "Location and the Lock Screen card are off."
        return when (access) {
            LocationAccess.denied -> "Turn on location for Limit in Settings"
            LocationAccess.reduced -> "Turn on Precise Location so Limit can find your road"
            LocationAccess.notDetermined -> "Allow location to see the limit"
            LocationAccess.authorized -> when {
                snapshot.isOutsideNewZealand -> Coverage.outsideNewZealandDetail
                snapshot.limit == null -> "Obey the posted speed limit signs"
                else -> null
            }
        }
    }
}
