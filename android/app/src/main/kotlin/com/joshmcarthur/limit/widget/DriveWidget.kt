package com.joshmcarthur.limit.widget

import android.content.Context
import androidx.compose.runtime.Composable
import androidx.compose.ui.unit.DpSize
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.glance.GlanceId
import androidx.glance.GlanceModifier
import androidx.glance.LocalSize
import androidx.glance.material3.GlanceTheme
import androidx.glance.action.ActionParameters
import androidx.glance.action.clickable
import androidx.glance.appwidget.GlanceAppWidget
import androidx.glance.appwidget.GlanceAppWidgetReceiver
import androidx.glance.appwidget.SizeMode
import androidx.glance.appwidget.action.ActionCallback
import androidx.glance.appwidget.action.actionRunCallback
import androidx.glance.appwidget.provideContent
import androidx.glance.appwidget.updateAll
import androidx.glance.background
import androidx.glance.layout.Alignment
import androidx.glance.layout.Column
import androidx.glance.layout.Row
import androidx.glance.layout.fillMaxSize
import androidx.glance.layout.padding
import androidx.glance.text.FontWeight
import androidx.glance.text.Text
import androidx.glance.text.TextStyle
import com.joshmcarthur.limit.LimitApp
import com.joshmcarthur.limit.core.FreshnessText
import com.joshmcarthur.limit.core.SignState
import com.joshmcarthur.limit.notification.DriveNotification
import java.time.Instant

class DriveWidget : GlanceAppWidget() {
    override val sizeMode = SizeMode.Responsive(
        setOf(DpSize(110.dp, 110.dp), DpSize(250.dp, 110.dp)),
    )

    override suspend fun provideGlance(context: Context, id: GlanceId) {
        val app = context.applicationContext as LimitApp
        provideContent {
            GlanceTheme {
                Content(app)
            }
        }
    }

    companion object {
        suspend fun refresh(context: Context) {
            DriveWidget().updateAll(context)
        }
    }
}

@Composable
private fun Content(app: LimitApp) {
    val model = app.driveModel
    val snapshot = model.driveState.value.snapshot
    val driving = model.isDriving.value
    val wide = LocalSize.current.width >= 180.dp
    val limitText = when (val sign = snapshot.sign) {
        is SignState.Limit -> sign.value.toString()
        is SignState.OpenRoad -> "Open"
        is SignState.Unknown -> "–"
    }
    val action = actionRunCallback<ToggleDriveAction>()
    if (wide) {
        Row(
            GlanceModifier.fillMaxSize().background(GlanceTheme.colors.surface).padding(12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(limitText, style = TextStyle(fontSize = 28.sp, fontWeight = FontWeight.Bold), modifier = GlanceModifier.padding(end = 12.dp))
            Column(GlanceModifier.padding(end = 8.dp)) {
                Text(DriveNotification.title(snapshot), style = TextStyle(fontSize = 14.sp))
                Text(
                    if (driving) DriveNotification.text(snapshot) else FreshnessText.footer(model.syncState.value, Instant.now()),
                    style = TextStyle(fontSize = 12.sp),
                )
            }
            Text(if (driving) "End" else "Start", modifier = GlanceModifier.clickable(action).padding(8.dp))
        }
    } else {
        Column(
            GlanceModifier.fillMaxSize().background(GlanceTheme.colors.surface).padding(12.dp).clickable(action),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(limitText, style = TextStyle(fontSize = 32.sp, fontWeight = FontWeight.Bold))
            Text(if (driving) "${snapshot.speed ?: "–"} km/h" else "Start drive", style = TextStyle(fontSize = 12.sp))
        }
    }
}

class DriveWidgetReceiver : GlanceAppWidgetReceiver() {
    override val glanceAppWidget = DriveWidget()
}

class ToggleDriveAction : ActionCallback {
    override suspend fun onAction(context: Context, glanceId: GlanceId, parameters: ActionParameters) {
        val model = (context.applicationContext as LimitApp).driveModel
        if (model.isDriving.value) model.endDrive(true) else model.beginDrive()
        DriveWidget.refresh(context)
    }
}
