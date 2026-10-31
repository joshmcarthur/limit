package com.joshmcarthur.limit.ui.sign

import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Typeface
import com.joshmcarthur.limit.core.SignMetrics
import com.joshmcarthur.limit.core.SignState

object SignPainter {
    const val FACE = 0xFFFFFFFF.toInt()
    const val RING = 0xFFC8102E.toInt()
    const val INK = 0xFF111111.toInt()
    const val UNKNOWN = 0xFF8E9099.toInt()
    const val CAUTION = 0xFFFF9F0A.toInt()
    const val ON_CAUTION = 0xFF000000.toInt()

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
        val known = state is SignState.Limit
        fill.color = FACE
        stroke.color = if (known) RING else UNKNOWN
        canvas.drawCircle(cx, cy, radius, fill)
        canvas.drawCircle(cx, cy, radius, stroke)
        when (state) {
            is SignState.Unknown -> drawNumeral(canvas, cx, cy, "\u2013", size, null, UNKNOWN, typeface)
            is SignState.OpenRoad -> drawOpenRoad(canvas, cx, cy, size, ring)
            is SignState.Limit -> drawNumeral(canvas, cx, cy, state.value.toString(), size, state.value, INK, typeface)
        }
        val stale = when (state) {
            is SignState.Limit -> state.isStale
            is SignState.OpenRoad -> state.isStale
            SignState.Unknown -> false
        }
        if (stale && SignMetrics.showsStaleBadge(size.toDouble())) drawStaleBadge(canvas, size)
    }

    /** Diagonal in the unknown colour, so an open road never reads as a posted limit. */
    private fun drawOpenRoad(canvas: Canvas, cx: Float, cy: Float, size: Float, ring: Float) {
        val slash = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = UNKNOWN
            strokeWidth = ring * 0.6f
            strokeCap = Paint.Cap.BUTT
        }
        canvas.save()
        canvas.clipPath(Path().apply {
            addCircle(cx, cy, size / 2f - ring, Path.Direction.CW)
        })
        canvas.rotate(45f, cx, cy)
        val bar = size - ring
        canvas.drawLine(cx, cy - bar / 2f, cx, cy + bar / 2f, slash)
        canvas.restore()
    }

    private fun drawNumeral(
        canvas: Canvas,
        cx: Float,
        cy: Float,
        text: String,
        diameter: Float,
        limit: Int?,
        color: Int,
        typeface: Typeface,
    ) {
        val textSize = SignMetrics.numeralSize(diameter.toDouble(), limit ?: 0).toFloat()
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            this.typeface = typeface
            this.textSize = textSize
            textAlign = Paint.Align.CENTER
            letterSpacing = -0.01f
            fontFeatureSettings = "tnum"
            fontVariationSettings = "'wght' 700, 'wdth' 80"
        }
        val y = cy - (paint.descent() + paint.ascent()) / 2f
        canvas.drawText(text, cx, y, paint)
    }

    /** Caution disc with a clock, sitting on the lower end of the ring. */
    private fun drawStaleBadge(canvas: Canvas, size: Float) {
        val badge = size * 0.32f
        val radius = badge / 2f
        val cx = size - radius * 0.85f
        val cy = size - radius * 0.85f
        canvas.drawCircle(cx, cy, radius, Paint(Paint.ANTI_ALIAS_FLAG).apply { color = CAUTION })
        val ink = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = ON_CAUTION
            style = Paint.Style.STROKE
            strokeWidth = radius * 0.16f
            strokeCap = Paint.Cap.ROUND
        }
        canvas.drawCircle(cx, cy, radius * 0.52f, ink)
        canvas.drawLine(cx, cy, cx, cy - radius * 0.32f, ink)
        canvas.drawLine(cx, cy, cx + radius * 0.26f, cy, ink)
    }
}
