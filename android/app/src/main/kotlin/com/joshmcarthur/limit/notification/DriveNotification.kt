package com.joshmcarthur.limit.notification

import com.joshmcarthur.limit.core.DriveSnapshot
import com.joshmcarthur.limit.core.OverLimitState
import com.joshmcarthur.limit.core.SignState

object DriveNotification {
    const val DRIVE_CHANNEL = "drive"
    const val STOP_CHANNEL = "drive-stop"
    const val DRIVE_ID = 1
    const val STOP_ID = 2

    fun title(snapshot: DriveSnapshot): String {
        val road = snapshot.roadName
        return when (val sign = snapshot.sign) {
            is SignState.Limit -> if (road != null) "${sign.value} km/h · $road" else "${sign.value} km/h"
            is SignState.OpenRoad -> if (road != null) "Open road · $road" else "Open road"
            is SignState.VariablePosted -> if (road != null) "Variable limit · $road" else "Variable limit"
            SignState.Unknown -> if (snapshot.roadName != null) "Limit unknown · ${snapshot.roadName}" else "Limit unknown · finding your road"
        }
    }

    fun text(snapshot: DriveSnapshot): String {
        val speed = snapshot.speed ?: return "Your speed isn't available"
        val over = snapshot.over
        return if (over is OverLimitState.Over) {
            "Your speed $speed km/h · ${over.by} over"
        } else {
            "Your speed $speed km/h"
        }
    }
}
