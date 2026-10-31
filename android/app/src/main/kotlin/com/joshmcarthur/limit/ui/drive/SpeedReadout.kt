package com.joshmcarthur.limit.ui.drive

import android.provider.Settings
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.togetherWith
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.clearAndSetSemantics
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.joshmcarthur.limit.core.AccessibilityLabels
import com.joshmcarthur.limit.core.OverLimitState
import com.joshmcarthur.limit.ui.theme.Caution
import com.joshmcarthur.limit.ui.theme.OnCaution
import com.joshmcarthur.limit.ui.theme.SpeedReadoutFont
import com.joshmcarthur.limit.ui.theme.cautionInk

/**
 * Measured GPS speed. The number does not follow font scale. TalkBack reads the content description
 * once; this is not a live region, so speed changes are not announced.
 */
@Composable
fun SpeedReadout(
    speed: Int?,
    over: OverLimitState,
    modifier: Modifier = Modifier,
) {
    val overBy = (over as? OverLimitState.Over)?.by
    val motion = motionDurationMillis()
    val shown by animateFloatAsState(
        targetValue = if (overBy != null) 1f else 0f,
        animationSpec = tween(durationMillis = motion, easing = FastOutSlowInEasing),
        label = "over-limit",
    )
    val numberColor = when {
        overBy != null -> OnCaution
        speed == null -> MaterialTheme.colorScheme.onSurfaceVariant
        else -> MaterialTheme.colorScheme.onSurface
    }
    val caption = when {
        overBy != null -> "+$overBy over"
        speed == null -> "No GPS"
        else -> "km/h"
    }
    val captionColor = if (overBy != null) cautionInk() else MaterialTheme.colorScheme.onSurfaceVariant
    val numberStyle = TextStyle(
        fontFamily = SpeedReadoutFont,
        fontWeight = FontWeight.Black,
        fontSize = fixedSp(96f),
        lineHeight = fixedSp(96f),
        fontFeatureSettings = "tnum",
        textAlign = TextAlign.Center,
        color = numberColor,
    )
    Column(
        modifier.clearAndSetSemantics {
            contentDescription = AccessibilityLabels.readout(speed, over)
        },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(contentAlignment = Alignment.Center) {
            Box(
                Modifier
                    .matchParentSize()
                    .graphicsLayer {
                        alpha = shown
                        val scale = 0.92f + 0.08f * shown
                        scaleX = scale
                        scaleY = scale
                    }
                    .clip(RoundedCornerShape(28.dp))
                    .background(Caution),
            )
            AnimatedContent(
                targetState = speed,
                transitionSpec = {
                    if (motion == 0) {
                        fadeIn(tween(0)) togetherWith fadeOut(tween(0))
                    } else {
                        (fadeIn(tween(motion, easing = FastOutSlowInEasing)) +
                            scaleIn(initialScale = 0.92f, animationSpec = tween(motion, easing = FastOutSlowInEasing)))
                            .togetherWith(fadeOut(tween(motion / 2, easing = FastOutSlowInEasing)))
                    }
                },
                label = "speed",
            ) { value ->
                Text(
                    text = value?.toString() ?: "\u2013",
                    style = numberStyle,
                    modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp),
                )
            }
        }
        Text(
            text = caption,
            style = MaterialTheme.typography.labelLarge,
            color = captionColor,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

@Composable
private fun fixedSp(dp: Float) = (dp / LocalDensity.current.fontScale).sp

@Composable
private fun motionDurationMillis(): Int {
    val scale = Settings.Global.getFloat(
        LocalContext.current.contentResolver,
        Settings.Global.ANIMATOR_DURATION_SCALE,
        1f,
    )
    return if (scale == 0f) 0 else 200
}
