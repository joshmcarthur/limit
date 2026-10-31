package com.joshmcarthur.limit.ui.settings

import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.Download
import androidx.compose.material.icons.rounded.Sync
import androidx.compose.material.icons.rounded.Warning
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.joshmcarthur.limit.core.FreshnessText
import com.joshmcarthur.limit.core.SyncState
import com.joshmcarthur.limit.ui.theme.cautionInk
import java.time.Instant

@Composable
fun SyncStatusRow(
    state: SyncState,
    onRetry: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val row = FreshnessText.row(state, Instant.now())
    val updating = state is SyncState.Updating
    val warn = state is SyncState.Stale || state is SyncState.Failed
    val icon = when (state) {
        is SyncState.UpToDate -> Icons.Rounded.CheckCircle
        is SyncState.Updating -> Icons.Rounded.Sync
        is SyncState.Stale, is SyncState.Failed -> Icons.Rounded.Warning
        SyncState.NeverSynced -> Icons.Rounded.Download
    }
    val tint = when {
        warn -> cautionInk()
        updating -> MaterialTheme.colorScheme.primary
        else -> MaterialTheme.colorScheme.onSurfaceVariant
    }
    val retry = when (state) {
        is SyncState.Updating -> null
        is SyncState.UpToDate -> "Check now"
        else -> "Retry"
    }
    Row(modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.Top) {
        Icon(icon, contentDescription = null, tint = tint, modifier = Modifier.padding(top = 2.dp).size(24.dp))
        Column(Modifier.padding(start = 16.dp).weight(1f)) {
            Text(row.title, style = MaterialTheme.typography.titleMedium)
            Text(
                row.subtitle,
                style = MaterialTheme.typography.bodyMedium,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier.padding(top = 2.dp),
            )
            if (state is SyncState.Updating) {
                val progress = state.progress
                if (progress == null) {
                    LinearProgressIndicator(Modifier.fillMaxWidth().padding(top = 8.dp))
                } else {
                    LinearProgressIndicator(
                        progress = { progress.toFloat().coerceIn(0f, 1f) },
                        modifier = Modifier.fillMaxWidth().padding(top = 8.dp),
                    )
                }
            }
        }
        if (retry != null) {
            TextButton(onClick = onRetry, modifier = Modifier.heightIn(min = 48.dp)) { Text(retry) }
        }
    }
}
