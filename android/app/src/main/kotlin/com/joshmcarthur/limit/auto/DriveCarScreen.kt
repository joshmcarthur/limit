package com.joshmcarthur.limit.auto

import androidx.car.app.CarContext
import androidx.car.app.Screen
import androidx.car.app.model.Action
import androidx.car.app.model.CarIcon
import androidx.car.app.model.Header
import androidx.car.app.model.Pane
import androidx.car.app.model.PaneTemplate
import androidx.car.app.model.Row
import androidx.car.app.model.Template
import androidx.core.graphics.drawable.IconCompat
import com.joshmcarthur.limit.LimitApp
import com.joshmcarthur.limit.notification.DriveNotification
import com.joshmcarthur.limit.notification.SignBitmaps

class DriveCarScreen(carContext: CarContext) : Screen(carContext) {
    override fun onGetTemplate(): Template {
        val model = (carContext.applicationContext as LimitApp).driveModel
        val snapshot = model.driveState.value.snapshot
        val isDriving = model.isDriving.value
        val icon = CarIcon.Builder(
            IconCompat.createWithBitmap(SignBitmaps.largeIcon(carContext, snapshot.sign, 192)),
        ).build()
        val pane = Pane.Builder()
            .addRow(
                Row.Builder()
                    .setTitle(DriveNotification.title(snapshot))
                    .addText(DriveNotification.text(snapshot))
                    .setImage(icon)
                    .build(),
            )
            .addAction(
                Action.Builder()
                    .setTitle(if (isDriving) "End drive" else "Start drive")
                    .setOnClickListener {
                        if (isDriving) model.endDrive(true) else model.beginDrive()
                        invalidate()
                    }
                    .build(),
            )
            .build()
        return PaneTemplate.Builder(pane)
            .setHeader(
                Header.Builder()
                    .setTitle("Limit")
                    .setStartHeaderAction(Action.APP_ICON)
                    .build(),
            )
            .build()
    }
}
