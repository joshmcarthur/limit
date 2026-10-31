package com.joshmcarthur.limit.ui.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
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
import com.joshmcarthur.limit.core.FreshnessText
import com.joshmcarthur.limit.core.OverLimitEvaluator
import com.joshmcarthur.limit.core.SyncState
import java.time.Instant

@Composable
fun SettingsScreen(model: DriveModel, onAbout: () -> Unit, onDone: () -> Unit) {
    val settings by model.settings.collectAsStateWithLifecycle()
    val sync by model.syncState.collectAsStateWithLifecycle()
    val row = FreshnessText.row(sync, Instant.now())
    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text("Settings", style = MaterialTheme.typography.headlineMedium)
        Text(row.title, style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 24.dp))
        Text(row.subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        val retryLabel = if (sync is SyncState.Failed || sync is SyncState.NeverSynced) "Retry" else "Check now"
        TextButton(onClick = { model.retrySync() }) { Text(retryLabel) }
        Text("While driving", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp))
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 8.dp)) {
            Text("Show on Lock Screen", modifier = Modifier.weight(1f))
            Switch(checked = settings.showOnLockScreen, onCheckedChange = { value ->
                model.updateSettings { it.copy(showOnLockScreen = value) }
            })
        }
        Text("Show “over” from", style = MaterialTheme.typography.bodyLarge, modifier = Modifier.padding(top = 16.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedButton(onClick = {
                model.updateSettings { it.copy(overTolerance = (it.overTolerance - 1).coerceIn(OverLimitEvaluator.toleranceRange)) }
            }) { Text("−") }
            Text(settings.toleranceLabel, modifier = Modifier.padding(horizontal = 16.dp), style = MaterialTheme.typography.titleMedium)
            OutlinedButton(onClick = {
                model.updateSettings { it.copy(overTolerance = (it.overTolerance + 1).coerceIn(OverLimitEvaluator.toleranceRange)) }
            }) { Text("+") }
        }
        Text(
            "This absorbs GPS error. It is a display setting, not an allowance.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.padding(top = 8.dp),
        )
        Row(verticalAlignment = Alignment.CenterVertically, modifier = Modifier.padding(top = 16.dp)) {
            Text("Suggest ending my drive", modifier = Modifier.weight(1f))
            Switch(checked = settings.suggestEndingDrive, onCheckedChange = { value ->
                model.updateSettings { it.copy(suggestEndingDrive = value) }
            })
        }
        Text(
            "After 15 minutes without moving, Limit ends the drive so location isn’t left on.",
            style = MaterialTheme.typography.bodyMedium,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        TextButton(onClick = onAbout, modifier = Modifier.padding(top = 16.dp)) { Text("About the data") }
        Button(onClick = onDone, modifier = Modifier.padding(top = 24.dp)) { Text("Done") }
    }
}
