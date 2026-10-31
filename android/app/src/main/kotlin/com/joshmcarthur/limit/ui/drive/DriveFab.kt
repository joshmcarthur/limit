package com.joshmcarthur.limit.ui.drive

import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DirectionsCar
import androidx.compose.material.icons.filled.StopCircle
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
    val fabModifier = modifier
        .navigationBarsPadding()
        .padding(PaddingValues(end = 16.dp, bottom = 16.dp))
    if (landscape) {
        FloatingActionButton(
            onClick = onClick,
            modifier = fabModifier,
            containerColor = if (isDriving) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.primaryContainer,
            contentColor = if (isDriving) MaterialTheme.colorScheme.onSecondaryContainer else MaterialTheme.colorScheme.onPrimaryContainer,
        ) {
            Icon(
                imageVector = if (isDriving) Icons.Filled.StopCircle else Icons.Filled.DirectionsCar,
                contentDescription = if (isDriving) "End drive" else "Start drive",
            )
        }
    } else {
        ExtendedFloatingActionButton(
            onClick = onClick,
            modifier = fabModifier,
            text = { Text(if (isDriving) "End drive" else "Start drive") },
            icon = {
                Icon(
                    imageVector = if (isDriving) Icons.Filled.StopCircle else Icons.Filled.DirectionsCar,
                    contentDescription = null,
                )
            },
            containerColor = if (isDriving) MaterialTheme.colorScheme.secondaryContainer else MaterialTheme.colorScheme.primaryContainer,
            contentColor = if (isDriving) MaterialTheme.colorScheme.onSecondaryContainer else MaterialTheme.colorScheme.onPrimaryContainer,
        )
    }
}
