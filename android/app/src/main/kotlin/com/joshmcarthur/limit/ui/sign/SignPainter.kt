package com.joshmcarthur.limit.ui.sign

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Typeface
import android.os.Build
import com.joshmcarthur.limit.core.SignMetrics
import com.joshmcarthur.limit.core.SignState

object SignPainter {
    const val FACE = 0xFFFFFFFF.toInt()
    const val RING = 0xFFC8102E.toInt()
    const val INK = 0xFF111111.toInt()
    const val UNKNOWN = 0xFF8E9099.toInt()
    const val CAUTION = 0xFFFF9F0A.toInt()

    fun paint(canvas: Canvas, size: Float, state: SignState, typeface: Typeface) {
        val cx = size / 2f
        val cy = size / 2f
        val ring = SignMetrics.ringWidth(size.toDouble()).toFloat()
        val radius = size / 2f - ring / 2f
        val fill = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL }
        val stroke = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            style = Paint.Style.STROKE
            strokeWidth = ring
        }
        when (state) {
            is SignState.Unknown -> {
                fill.color = FACE
                stroke.color = UNKNOWN
                canvas.drawCircle(cx, cy, radius, fill)
                canvas.drawCircle(cx, cy, radius, stroke)
                drawText(canvas, cx, cy, "–", size * 0.42f, UNKNOWN, typeface)
            }
            is SignState.OpenRoad -> {
                fill.color = FACE
                stroke.color = RING
                canvas.drawCircle(cx, cy, radius, fill)
                canvas.drawCircle(cx, cy, radius, stroke)
                val slash = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                    color = RING
                    strokeWidth = ring
                    strokeCap = Paint.Cap.ROUND
                }
                val inset = ring * 2
                canvas.drawLine(inset, size - inset, size - inset, inset, slash)
            }
            is SignState.Limit -> {
                fill.color = FACE
                stroke.color = RING
                canvas.drawCircle(cx, cy, radius, fill)
                canvas.drawCircle(cx, cy, radius, stroke)
                val numeral = SignMetrics.numeralSize(size.toDouble(), state.value).toFloat()
                drawText(canvas, cx, cy, state.value.toString(), numeral, INK, typeface)
                if (state.isStale && SignMetrics.showsStaleBadge(size.toDouble())) {
                    val badge = size * 0.18f
                    val bx = size - badge
                    val by = badge
                    val badgePaint = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = CAUTION }
                    canvas.drawCircle(bx, by, badge / 2f, badgePaint)
                }
            }
        }
    }

    private fun drawText(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        text: String,
        size: Float,
        color: Int,
        typeface: Typeface,
    ) {
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            this.typeface = typeface
            textSize = size
            textAlign = Paint.Align.CENTER
            if (Build.VERSION.SDK_INT >= 21) isElegantTextHeight = true
        }
        val y = cy - (paint.descent() + paint.ascent()) / 2f
        canvas.drawText(text, cx, y, paint)
    }
}
