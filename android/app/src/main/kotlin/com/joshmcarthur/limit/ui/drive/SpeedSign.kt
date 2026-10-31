package com.joshmcarthur.limit.ui.drive

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.nativeCanvas
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.core.content.res.ResourcesCompat
import com.joshmcarthur.limit.R
import com.joshmcarthur.limit.core.AccessibilityLabels
import com.joshmcarthur.limit.core.LimitNote
import com.joshmcarthur.limit.core.SignState
import com.joshmcarthur.limit.ui.sign.SignPainter

@Composable
fun SpeedSign(
    state: SignState,
    note: LimitNote? = null,
    diameter: Dp = 200.dp,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val typeface = ResourcesCompat.getFont(context, R.font.robotoflex) ?: android.graphics.Typeface.DEFAULT_BOLD
    val px = with(LocalDensity.current) { diameter.toPx() }
    Canvas(
        modifier
            .size(diameter)
            .semantics { contentDescription = AccessibilityLabels.sign(state, note) },
    ) {
        SignPainter.paint(drawContext.canvas.nativeCanvas, px, state, typeface)
    }
}
