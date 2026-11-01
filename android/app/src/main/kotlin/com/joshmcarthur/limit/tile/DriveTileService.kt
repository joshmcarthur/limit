package com.joshmcarthur.limit.tile

import android.content.Intent
import android.os.Build
import android.service.quicksettings.Tile
import android.service.quicksettings.TileService
import com.joshmcarthur.limit.LimitApp
import com.joshmcarthur.limit.MainActivity
import com.joshmcarthur.limit.core.SignState

class DriveTileService : TileService() {
    override fun onStartListening() {
        refresh()
    }

    override fun onClick() {
        val model = (application as LimitApp).driveModel
        if (!model.settings.value.hasCompletedOnboarding || !model.locationAccess.value.isUsable) {
            val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            if (Build.VERSION.SDK_INT >= 34) {
                startActivityAndCollapse(android.app.PendingIntent.getActivity(this, 0, intent, android.app.PendingIntent.FLAG_IMMUTABLE))
            } else {
                @Suppress("DEPRECATION")
                startActivityAndCollapse(intent)
            }
            return
        }
        if (model.isDriving.value) model.endDrive(true) else model.beginDrive()
        refresh()
    }

    private fun refresh() {
        val model = (application as LimitApp).driveModel
        val driving = model.isDriving.value
        qsTile?.apply {
            state = if (driving) Tile.STATE_ACTIVE else Tile.STATE_INACTIVE
            label = "Drive"
            if (Build.VERSION.SDK_INT >= 29) {
                subtitle = if (driving) {
                    when (val sign = model.driveState.value.snapshot.sign) {
                        is SignState.Limit -> "${sign.value} km/h limit"
                        is SignState.OpenRoad -> "Open road"
                        is SignState.VariablePosted -> "Variable limit"
                        is SignState.Unknown -> "Driving"
                    }
                } else {
                    "Start drive"
                }
            }
            updateTile()
        }
    }
}
