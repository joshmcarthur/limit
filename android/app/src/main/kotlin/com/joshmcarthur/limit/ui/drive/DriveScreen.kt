package com.joshmcarthur.limit.ui.drive

import android.app.Activity
import android.view.WindowManager
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.SnackbarHost
import androidx.compose.material3.SnackbarHostState
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.joshmcarthur.limit.DriveModel
import com.joshmcarthur.limit.core.DriveScreenText
import com.joshmcarthur.limit.core.FreshnessText
import com.joshmcarthur.limit.core.LimitCore
import java.time.Instant

@Composable
fun DriveScreen(model: DriveModel, onSettings: () -> Unit) {
    val driveState by model.driveState.collectAsStateWithLifecycle()
    val isDriving by model.isDriving.collectAsStateWithLifecycle()
    val access by model.locationAccess.collectAsStateWithLifecycle()
    val sync by model.syncState.collectAsStateWithLifecycle()
    val snackbar by model.snackbar.collectAsStateWithLifecycle()
    val snapshot = driveState.snapshot
    val snackbarHost = remember { SnackbarHostState() }
    val activity = LocalContext.current as? Activity

    DisposableEffect(isDriving, activity) {
        val window = activity?.window
        if (isDriving) {
            window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        onDispose { window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
    }

    LaunchedEffect(snackbar) {
        val message = snackbar ?: return@LaunchedEffect
        snackbarHost.showSnackbar(message)
        model.consumeSnackbar()
    }

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val landscape = maxWidth > maxHeight
        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .padding(horizontal = 16.dp, vertical = 8.dp),
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(driveState.gps.label, style = MaterialTheme.typography.labelLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.weight(1f))
                IconButton(onClick = onSettings) {
                    Icon(Icons.Filled.Tune, contentDescription = "Settings")
                }
            }
            val headline = DriveScreenText.headline(isDriving, access, snapshot)
            val sub = DriveScreenText.subheadline(isDriving, access, snapshot)
            if (landscape) {
                Row(
                    Modifier.weight(1f).fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.SpaceEvenly,
                ) {
                    SpeedSign(snapshot.sign, snapshot.limitNote, diameter = 160.dp)
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        SpeedReadout(snapshot.speed, snapshot.over)
                        snapshot.limitNote?.let {
                            Text(it.label, style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(top = 8.dp))
                        }
                        Text(headline, style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 12.dp))
                        sub?.let { Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant) }
                    }
                }
            } else {
                Column(
                    Modifier.weight(1f).fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    SpeedSign(snapshot.sign, snapshot.limitNote)
                    snapshot.limitNote?.let {
                        Text(it.label, style = MaterialTheme.typography.labelMedium, modifier = Modifier.padding(top = 12.dp))
                    }
                    Text(headline, style = MaterialTheme.typography.titleLarge, modifier = Modifier.padding(top = 16.dp))
                    sub?.let {
                        Text(it, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, modifier = Modifier.padding(top = 4.dp))
                    }
                    SpeedReadout(snapshot.speed, snapshot.over, modifier = Modifier.padding(top = 24.dp))
                }
            }
            Text(LimitCore.attribution, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
            Text(FreshnessText.footer(sync, Instant.now()), style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        DriveFab(
            isDriving = isDriving,
            landscape = landscape,
            onClick = { if (isDriving) model.endDrive(true) else model.beginDrive() },
            modifier = Modifier.align(Alignment.BottomEnd),
        )
        SnackbarHost(snackbarHost, modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 88.dp))
    }
}
