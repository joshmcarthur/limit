package com.joshmcarthur.limit.ui.setup

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material3.Button
import androidx.compose.material3.Icon
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.unit.dp
import com.joshmcarthur.limit.ui.theme.cautionInk

enum class SetupStepStatus { Todo, InProgress, Done, Blocked }

@Composable
fun SetupStepCard(
    title: String,
    supporting: String,
    status: SetupStepStatus,
    icon: ImageVector,
    caution: String? = null,
    progress: Float? = null,
    actionLabel: String? = null,
    onAction: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val done = status == SetupStepStatus.Done
    val blocked = status == SetupStepStatus.Blocked
    val well = when {
        done || blocked -> MaterialTheme.colorScheme.surfaceContainerHigh
        else -> MaterialTheme.colorScheme.primaryContainer
    }
    val glyphTint = when {
        blocked -> cautionInk()
        done -> MaterialTheme.colorScheme.onSurfaceVariant
        else -> MaterialTheme.colorScheme.onPrimaryContainer
    }
    Surface(
        modifier = modifier.fillMaxWidth(),
        shape = RoundedCornerShape(16.dp),
        color = MaterialTheme.colorScheme.surfaceContainerLow,
    ) {
        Row(Modifier.padding(16.dp)) {
            Icon(
                imageVector = if (done) Icons.Rounded.CheckCircle else icon,
                contentDescription = null,
                tint = glyphTint,
                modifier = Modifier
                    .size(40.dp)
                    .clip(CircleShape)
                    .background(well)
                    .padding(8.dp),
            )
            Column(Modifier.padding(start = 16.dp).weight(1f)) {
                Text(title, style = MaterialTheme.typography.titleMedium)
                Text(
                    supporting,
                    style = MaterialTheme.typography.bodyMedium,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(top = 2.dp),
                )
                if (caution != null) {
                    Text(
                        caution,
                        style = MaterialTheme.typography.bodyMedium,
                        color = cautionInk(),
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
                if (status == SetupStepStatus.InProgress) {
                    if (progress == null) {
                        LinearProgressIndicator(Modifier.fillMaxWidth().padding(top = 12.dp))
                    } else {
                        LinearProgressIndicator(
                            progress = { progress.coerceIn(0f, 1f) },
                            modifier = Modifier.fillMaxWidth().padding(top = 12.dp),
                        )
                    }
                } else if (actionLabel != null && onAction != null && !done) {
                    val buttonModifier = Modifier.padding(top = 12.dp).heightIn(min = 48.dp)
                    if (blocked) {
                        OutlinedButton(onClick = onAction, modifier = buttonModifier) { Text(actionLabel) }
                    } else {
                        Button(onClick = onAction, modifier = buttonModifier) { Text(actionLabel) }
                    }
                }
            }
        }
    }
}
