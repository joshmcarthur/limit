package com.joshmcarthur.limit.ui.setup

import android.Manifest
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.filled.LocationOn
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Sync
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.joshmcarthur.limit.DriveModel
import com.joshmcarthur.limit.core.LocationAccess
import com.joshmcarthur.limit.core.SyncState
import com.joshmcarthur.limit.ui.drive.SpeedSign
import com.joshmcarthur.limit.core.SignState

enum class SetupStepState { Todo, InProgress, Done, Blocked }

@Composable
fun SetupScreen(model: DriveModel) {
    val access by model.locationAccess.collectAsStateWithLifecycle()
    val notifications by model.notificationsGranted.collectAsStateWithLifecycle()
    val sync by model.syncState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val locationLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestMultiplePermissions()) {
        model.markLocationPrompted()
        model.refreshAccess()
        model.syncRegister()
    }
    val notificationLauncher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        model.refreshAccess()
    }

    val locationState = when (access) {
        LocationAccess.authorized -> SetupStepState.Done
        LocationAccess.notDetermined -> SetupStepState.Todo
        LocationAccess.reduced, LocationAccess.denied -> SetupStepState.Blocked
    }
    val notificationState = when {
        Build.VERSION.SDK_INT < 33 || notifications -> SetupStepState.Done
        else -> SetupStepState.Todo
    }
    val downloadState = when (sync) {
        is SyncState.Updating -> SetupStepState.InProgress
        is SyncState.UpToDate, is SyncState.Stale -> SetupStepState.Done
        is SyncState.Failed, SyncState.NeverSynced -> SetupStepState.Todo
    }

    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        SpeedSign(SignState.Limit(50, isStale = false), diameter = 40.dp)
        Spacer(Modifier.height(16.dp))
        Text("Set up Limit", style = MaterialTheme.typography.headlineMedium)
        Text(
            "See the speed limit for the road you’re on, anywhere in Aotearoa New Zealand.",
            style = MaterialTheme.typography.bodyLarge,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 8.dp, bottom = 24.dp),
        )
        SetupStepCard(
            icon = Icons.Filled.LocationOn,
            title = "Allow location",
            body = "Limit uses your location to find the road you’re on and to measure your speed. It never leaves your phone. Precise location is required.",
            state = locationState,
            actionLabel = if (locationState == SetupStepState.Blocked) "Open settings" else "Allow",
            onAction = {
                if (locationState == SetupStepState.Blocked) {
                    context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.fromParts("package", context.packageName, null)))
                } else {
                    locationLauncher.launch(arrayOf(Manifest.permission.ACCESS_FINE_LOCATION, Manifest.permission.ACCESS_COARSE_LOCATION))
                }
            },
            progress = null,
        )
        Spacer(Modifier.height(12.dp))
        SetupStepCard(
            icon = Icons.Filled.Notifications,
            title = "Allow notifications",
            body = "Needed so the drive can show on the Lock Screen. You can still drive without it.",
            state = notificationState,
            actionLabel = "Allow",
            onAction = {
                if (Build.VERSION.SDK_INT >= 33) {
                    notificationLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
                }
            },
            progress = null,
        )
        Spacer(Modifier.height(12.dp))
        SetupStepCard(
            icon = Icons.Filled.Sync,
            title = "Download speed limits",
            body = "About 24 MB from the NZTA National Speed Limit Register, kept on this phone.",
            state = downloadState,
            actionLabel = "Download",
            onAction = { model.retrySync() },
            progress = (sync as? SyncState.Updating)?.progress,
        )
        Spacer(Modifier.height(32.dp))
        Button(
            onClick = { model.finishOnboarding() },
            enabled = access.isUsable,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text("Done")
        }
        Text(
            "Always obey the posted speed limits and follow the NZ Road Code. Use this app as a guide only.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 16.dp),
        )
    }
}

@Composable
private fun SetupStepCard(
    icon: ImageVector,
    title: String,
    body: String,
    state: SetupStepState,
    actionLabel: String,
    onAction: () -> Unit,
    progress: Double?,
) {
    Card(
        shape = RoundedCornerShape(16.dp),
        colors = CardDefaults.cardColors(containerColor = MaterialTheme.colorScheme.surfaceContainerLow),
        modifier = Modifier.fillMaxWidth(),
    ) {
        Column(Modifier.padding(16.dp)) {
            val leading = if (state == SetupStepState.Done) Icons.Filled.CheckCircle else icon
            Icon(leading, contentDescription = null, tint = MaterialTheme.colorScheme.primary)
            Text(title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 8.dp))
            Text(body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp))
            if (state == SetupStepState.InProgress) {
                LinearProgressIndicator(
                    progress = { (progress ?: 0.0).toFloat().coerceIn(0f, 1f) },
                    modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                )
            } else if (state != SetupStepState.Done) {
                if (state == SetupStepState.Blocked) {
                    OutlinedButton(onClick = onAction, modifier = Modifier.padding(top = 12.dp)) { Text(actionLabel) }
                } else {
                    Button(onClick = onAction, modifier = Modifier.padding(top = 12.dp)) { Text(actionLabel) }
                }
            }
        }
    }
}
