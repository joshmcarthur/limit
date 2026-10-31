package com.joshmcarthur.limit.ui.drive

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.DirectionsCar
import androidx.compose.material.icons.rounded.StopCircle
import androidx.compose.material3.ExtendedFloatingActionButton
import androidx.compose.material3.FloatingActionButton
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun DriveFab(
    isDriving: Boolean,
    landscape: Boolean,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val label = if (isDriving) "End drive" else "Start drive"
    val icon = if (isDriving) Icons.Rounded.StopCircle else Icons.Rounded.DirectionsCar
    val container = if (isDriving) {
        MaterialTheme.colorScheme.secondaryContainer
    } else {
        MaterialTheme.colorScheme.primaryContainer
    }
    val content = if (isDriving) {
        MaterialTheme.colorScheme.onSecondaryContainer
    } else {
        MaterialTheme.colorScheme.onPrimaryContainer
    }
    val fabModifier = modifier
        .navigationBarsPadding()
        .padding(PaddingValues(end = 16.dp, bottom = 16.dp))
    if (landscape) {
        FloatingActionButton(
            onClick = onClick,
            modifier = fabModifier.size(56.dp),
            containerColor = container,
            contentColor = content,
            shape = RoundedCornerShape(16.dp),
        ) {
            Icon(imageVector = icon, contentDescription = label)
        }
    } else {
        ExtendedFloatingActionButton(
            onClick = onClick,
            modifier = fabModifier,
            text = { Text(label) },
            icon = { Icon(imageVector = icon, contentDescription = null) },
            containerColor = container,
            contentColor = content,
            shape = RoundedCornerShape(16.dp),
        )
    }
}
