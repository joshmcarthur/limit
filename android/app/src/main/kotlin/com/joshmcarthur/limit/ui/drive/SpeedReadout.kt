package com.joshmcarthur.limit.ui.drive

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.joshmcarthur.limit.core.AccessibilityLabels
import com.joshmcarthur.limit.core.OverLimitState
import com.joshmcarthur.limit.ui.theme.Caution
import com.joshmcarthur.limit.ui.theme.OnCaution
import com.joshmcarthur.limit.ui.theme.SpeedReadoutFont

@Composable
fun SpeedReadout(
    speed: Int?,
    over: OverLimitState,
    modifier: Modifier = Modifier,
) {
    val overAmount = (over as? OverLimitState.Over)?.by
    val shape = RoundedCornerShape(28.dp)
    Column(
        modifier
            .then(
                if (overAmount != null) {
                    Modifier.background(Caution, shape).padding(horizontal = 24.dp, vertical = 12.dp)
                } else {
                    Modifier
                },
            )
            .semantics { contentDescription = AccessibilityLabels.readout(speed, over) },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        val color = if (overAmount != null) OnCaution else MaterialTheme.colorScheme.onSurface
        Text(
            text = speed?.toString() ?: "–",
            fontFamily = SpeedReadoutFont,
            fontWeight = FontWeight.Black,
            fontSize = 96.sp,
            lineHeight = 96.sp,
            color = color,
        )
        Text(
            text = if (speed == null) "No GPS" else "km/h",
            style = MaterialTheme.typography.labelLarge,
            color = color,
        )
        if (overAmount != null) {
            Text(
                text = "+$overAmount over",
                style = MaterialTheme.typography.labelLarge,
                color = OnCaution,
            )
        }
    }
}
