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
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Navigation
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.Warning
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
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.joshmcarthur.limit.DriveModel
import com.joshmcarthur.limit.core.AccessibilityLabels
import com.joshmcarthur.limit.core.DriveScreenText
import com.joshmcarthur.limit.core.FreshnessText
import com.joshmcarthur.limit.core.LimitCore
import com.joshmcarthur.limit.core.LimitNote
import com.joshmcarthur.limit.core.SignState
import com.joshmcarthur.limit.core.SyncState
import com.joshmcarthur.limit.ui.theme.cautionInk
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
    val view = LocalView.current

    DisposableEffect(isDriving, activity) {
        val window = activity?.window
        if (isDriving) window?.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        else window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        onDispose { window?.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON) }
    }

    LaunchedEffect(snackbar) {
        val message = snackbar ?: return@LaunchedEffect
        snackbarHost.showSnackbar(message)
        model.consumeSnackbar()
    }

    var announced by remember { mutableStateOf<SignState?>(null) }
    LaunchedEffect(snapshot.sign, isDriving) {
        val previous = announced
        announced = snapshot.sign
        if (previous != null && previous != snapshot.sign && isDriving) {
            view.announceForAccessibility(AccessibilityLabels.sign(snapshot.sign, snapshot.limitNote))
        }
    }

    BoxWithConstraints(Modifier.fillMaxSize()) {
        val landscape = maxWidth > maxHeight
        Column(
            Modifier
                .fillMaxSize()
                .statusBarsPadding()
                .navigationBarsPadding()
                .padding(horizontal = if (landscape) 24.dp else 16.dp)
                .padding(top = 8.dp, bottom = 8.dp),
        ) {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Icon(
                    Icons.Rounded.Navigation,
                    contentDescription = null,
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.size(20.dp),
                )
                Text(
                    driveState.gps.label,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(start = 8.dp),
                )
                Spacer(Modifier.weight(1f))
                IconButton(onClick = onSettings, modifier = Modifier.size(48.dp)) {
                    Icon(Icons.Rounded.Tune, contentDescription = "Settings")
                }
            }
            val headline = DriveScreenText.headline(isDriving, access, snapshot)
            val sub = DriveScreenText.subheadline(isDriving, access, snapshot)
            if (landscape) {
                Row(
                    Modifier.weight(1f).fillMaxWidth(),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    SignBlock(headline, sub, snapshot.sign, snapshot.limitNote, Modifier.weight(1f))
                    SpeedReadout(snapshot.speed, snapshot.over, Modifier.weight(1f))
                }
            } else {
                Column(
                    Modifier.weight(1f).fillMaxWidth(),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    SignBlock(headline, sub, snapshot.sign, snapshot.limitNote)
                    SpeedReadout(snapshot.speed, snapshot.over, Modifier.padding(top = 24.dp))
                }
            }
            Footer(sync, Modifier.padding(bottom = 72.dp, top = 8.dp))
        }
        DriveFab(
            isDriving = isDriving,
            landscape = landscape,
            onClick = { if (isDriving) model.endDrive(true) else model.beginDrive() },
            modifier = Modifier.align(Alignment.BottomEnd),
        )
        SnackbarHost(snackbarHost, Modifier.align(Alignment.BottomCenter).padding(bottom = 88.dp))
    }
}

@Composable
private fun SignBlock(
    headline: String,
    sub: String?,
    sign: SignState,
    note: LimitNote?,
    modifier: Modifier = Modifier,
) {
    Column(modifier, horizontalAlignment = Alignment.CenterHorizontally) {
        SpeedSign(sign, note, diameter = 200.dp)
        note?.let {
            Text(
                it.label,
                style = MaterialTheme.typography.bodyMedium,
                color = cautionInk(),
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 12.dp),
            )
        }
        Text(
            headline,
            style = MaterialTheme.typography.titleLarge,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(top = 16.dp),
        )
        sub?.let {
            Text(
                it,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

@Composable
private fun Footer(sync: SyncState, modifier: Modifier = Modifier) {
    val warn = sync is SyncState.Stale || sync is SyncState.Failed || sync is SyncState.NeverSynced
    val updating = sync is SyncState.Updating
    val color = if (warn) cautionInk() else MaterialTheme.colorScheme.onSurfaceVariant
    Column(modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            LimitCore.attribution,
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
        )
        Row(
            Modifier.padding(top = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.Center,
        ) {
            if (warn || updating) {
                Icon(
                    if (updating) Icons.Rounded.Sync else Icons.Rounded.Warning,
                    contentDescription = null,
                    tint = color,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(Modifier.size(6.dp))
            }
            Text(
                FreshnessText.footer(sync, Instant.now()),
                style = MaterialTheme.typography.bodyMedium,
                color = color,
                textAlign = TextAlign.Center,
            )
        }
    }
}
