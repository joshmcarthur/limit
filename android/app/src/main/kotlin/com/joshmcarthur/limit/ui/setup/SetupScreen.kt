package com.joshmcarthur.limit.ui.setup

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Download
import androidx.compose.material.icons.rounded.LocationOff
import androidx.compose.material.icons.rounded.Navigation
import androidx.compose.material.icons.rounded.Notifications
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.joshmcarthur.limit.DriveModel
import com.joshmcarthur.limit.core.FreshnessText
import com.joshmcarthur.limit.core.LocationAccess
import com.joshmcarthur.limit.core.SyncState
import java.time.Instant
import kotlin.math.roundToInt

@Composable
fun SetupScreen(model: DriveModel) {
    val access by model.locationAccess.collectAsStateWithLifecycle()
    val notifications by model.notificationsGranted.collectAsStateWithLifecycle()
    val notificationsPrompted by model.notificationsPrompted.collectAsStateWithLifecycle()
    val sync by model.syncState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val activity = context.findActivity()
    val canAskLocation = activity?.shouldShowRequestPermissionRationale(Manifest.permission.ACCESS_FINE_LOCATION) == true
    val canAskNotifications = activity?.shouldShowRequestPermissionRationale(Manifest.permission.POST_NOTIFICATIONS) == true

    val locationLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        model.markLocationPrompted()
    }
    val notificationLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        model.markNotificationsPrompted()
    }

    val locationBlocked = when (access) {
        LocationAccess.authorized, LocationAccess.notDetermined -> false
        LocationAccess.reduced, LocationAccess.denied -> !canAskLocation
    }
    val locationStatus = when {
        access == LocationAccess.authorized -> SetupStepStatus.Done
        locationBlocked -> SetupStepStatus.Blocked
        else -> SetupStepStatus.Todo
    }
    val notificationStatus = when {
        notifications -> SetupStepStatus.Done
        notificationsPrompted && !canAskNotifications -> SetupStepStatus.Blocked
        else -> SetupStepStatus.Todo
    }
    val downloadStatus = when (sync) {
        is SyncState.Updating -> SetupStepStatus.InProgress
        is SyncState.UpToDate, is SyncState.Stale -> SetupStepStatus.Done
        is SyncState.Failed -> SetupStepStatus.Blocked
        SyncState.NeverSynced -> SetupStepStatus.Todo
    }

    Column(
        Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Text("Set up Limit", style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(top = 24.dp))
        Text(
            "Limit needs your location to find the road you’re on. Notifications are optional.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 8.dp, bottom = 32.dp),
        )
        LocationStep(
            access = access,
            status = locationStatus,
            onAllow = { locationLauncher.launch(Manifest.permission.ACCESS_FINE_LOCATION) },
            onSettings = { context.openApplicationSettings() },
        )
        if (Build.VERSION.SDK_INT >= 33) {
            Spacer(Modifier.height(12.dp))
            NotificationStep(
                status = notificationStatus,
                onAllow = { notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS) },
                onSettings = { context.openApplicationSettings() },
            )
        }
        Spacer(Modifier.height(12.dp))
        DownloadStep(sync = sync, status = downloadStatus, onRetry = { model.retrySync() })
        Spacer(Modifier.height(32.dp))
        Button(
            onClick = { model.finishOnboarding() },
            enabled = access.isUsable,
            modifier = Modifier.fillMaxWidth().heightIn(min = 48.dp),
            shape = RoundedCornerShape(percent = 50),
        ) {
            Text("Done")
        }
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun LocationStep(
    access: LocationAccess,
    status: SetupStepStatus,
    onAllow: () -> Unit,
    onSettings: () -> Unit,
) {
    val blocked = status == SetupStepStatus.Blocked
    val precise = access == LocationAccess.reduced
    SetupStepCard(
        title = when {
            precise -> "Precise location is off"
            blocked -> "Location is off for Limit"
            else -> "Location"
        },
        supporting = when {
            status == SetupStepStatus.Done -> "Precise location is on while you’re using Limit."
            precise && blocked -> "Turn on Precise location for Limit, then come back."
            blocked -> "Turn on Location in Limit’s settings, then come back."
            precise -> "Approximate location can’t say which road you’re on. Choose Precise."
            else -> "To find the road you’re on and measure your speed. Choose Precise and While using the app."
        },
        caution = when {
            !blocked -> null
            precise -> "Approximate location can’t say which road you’re on."
            else -> "Limit can’t show speed limits without it."
        },
        status = status,
        icon = if (blocked) Icons.Rounded.LocationOff else Icons.Rounded.Navigation,
        actionLabel = if (blocked) "Open settings" else "Allow",
        onAction = if (blocked) onSettings else onAllow,
    )
}

@Composable
private fun NotificationStep(status: SetupStepStatus, onAllow: () -> Unit, onSettings: () -> Unit) {
    val blocked = status == SetupStepStatus.Blocked
    SetupStepCard(
        title = "Notifications",
        supporting = when (status) {
            SetupStepStatus.Done -> "Allowed. Your drive will show on the Lock Screen."
            SetupStepStatus.Blocked -> "The drive still works. Turn on notifications in Limit’s settings if you want the Lock Screen card."
            else -> "So Limit can show the speed limit on the Lock Screen while you drive. The drive still works without this."
        },
        caution = if (blocked) "Without notifications, the Lock Screen surface is missing." else null,
        status = status,
        icon = Icons.Rounded.Notifications,
        actionLabel = if (blocked) "Open settings" else "Allow",
        onAction = if (blocked) onSettings else onAllow,
    )
}

@Composable
private fun DownloadStep(sync: SyncState, status: SetupStepStatus, onRetry: () -> Unit) {
    val progress = (sync as? SyncState.Updating)?.progress
    val percent = progress?.let { (it * 100).roundToInt() }
    val row = FreshnessText.row(sync, Instant.now())
    SetupStepCard(
        title = "Speed limits",
        supporting = when (status) {
            SetupStepStatus.InProgress -> if (percent != null) {
                "Downloading from the NZTA register · $percent%"
            } else {
                "Downloading from the NZTA register"
            }
            SetupStepStatus.Done -> "Downloaded from the NZTA National Speed Limit Register."
            SetupStepStatus.Blocked -> row.subtitle
            SetupStepStatus.Todo -> "Limits come from the NZTA National Speed Limit Register."
        },
        caution = if (sync is SyncState.Failed) row.title else null,
        status = status,
        icon = if (status == SetupStepStatus.InProgress) Icons.Rounded.Sync else Icons.Rounded.Download,
        progress = progress?.toFloat(),
        actionLabel = when (status) {
            SetupStepStatus.Done, SetupStepStatus.InProgress -> null
            SetupStepStatus.Todo -> "Download"
            SetupStepStatus.Blocked -> "Retry"
        },
        onAction = if (status == SetupStepStatus.Done || status == SetupStepStatus.InProgress) null else onRetry,
    )
}

internal fun Context.openApplicationSettings() {
    startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", packageName, null)))
}

internal fun Context.findActivity(): Activity? {
    var current: Context = this
    while (current is ContextWrapper) {
        if (current is Activity) return current
        current = current.baseContext
    }
    return null
}
