package com.joshmcarthur.limit.ui.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.joshmcarthur.limit.DriveModel
import com.joshmcarthur.limit.core.OverLimitEvaluator
import kotlin.math.roundToInt

@Composable
fun SettingsScreen(model: DriveModel, onAbout: () -> Unit) {
    val settings by model.settings.collectAsStateWithLifecycle()
    val sync by model.syncState.collectAsStateWithLifecycle()
    Column(
        Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Text("Settings", style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(top = 24.dp, bottom = 8.dp))
        SyncStatusRow(state = sync, onRetry = { model.retrySync() })
        Text("While driving", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 24.dp, bottom = 4.dp))
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.heightIn(min = 48.dp)) {
            Text("Show on Lock Screen", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
            Switch(
                checked = settings.showOnLockScreen,
                onCheckedChange = { value -> model.updateSettings { it.copy(showOnLockScreen = value) } },
            )
        }
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 16.dp)) {
            Text("Show \u201cover\u201d from", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
            Text(settings.toleranceLabel, style = MaterialTheme.typography.bodyLarge, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Slider(
            value = settings.overTolerance.toFloat(),
            onValueChange = { value ->
                model.updateSettings {
                    it.copy(overTolerance = value.roundToInt().coerceIn(OverLimitEvaluator.toleranceRange))
                }
            },
            valueRange = OverLimitEvaluator.toleranceRange.first.toFloat()..OverLimitEvaluator.toleranceRange.last.toFloat(),
            steps = 8,
        )
        Text(
            "GPS speed can be a few km/h out, so \u201cover\u201d only shows once you\u2019re past this. It isn\u2019t a speed you can drive at: the limit is the limit.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp).heightIn(min = 48.dp)) {
            Text("Suggest ending my drive", modifier = Modifier.weight(1f), style = MaterialTheme.typography.bodyLarge)
            Switch(
                checked = settings.suggestEndingDrive,
                onCheckedChange = { value -> model.updateSettings { it.copy(suggestEndingDrive = value) } },
            )
        }
        Text(
            "When you get out and walk off, Limit asks whether the drive is over. After 15 minutes without moving it ends the drive by itself, so location isn\u2019t left on.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 4.dp),
        )
        TextButton(onClick = onAbout, modifier = Modifier.padding(top = 16.dp).heightIn(min = 48.dp)) {
            Text("About the data")
        }
    }
}
