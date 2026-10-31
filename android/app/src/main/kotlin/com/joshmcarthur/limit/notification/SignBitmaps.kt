package com.joshmcarthur.limit.notification

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.PorterDuff
import android.graphics.PorterDuffXfermode
import android.graphics.Typeface
import androidx.core.content.res.ResourcesCompat
import com.joshmcarthur.limit.R
import com.joshmcarthur.limit.core.SignState
import com.joshmcarthur.limit.ui.sign.SignPainter

object SignBitmaps {
    fun largeIcon(context: Context, state: SignState, sizePx: Int): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val typeface = ResourcesCompat.getFont(context, R.font.robotoflex) ?: Typeface.DEFAULT_BOLD
        SignPainter.paint(canvas, sizePx.toFloat(), state, typeface)
        return bitmap
    }

    fun silhouette(sizePx: Int, state: SignState): Bitmap {
        val bitmap = Bitmap.createBitmap(sizePx, sizePx, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val ring = sizePx * 0.11f
        val cx = sizePx / 2f
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            style = Paint.Style.STROKE
            strokeWidth = ring
        }
        canvas.drawCircle(cx, cx, cx - ring / 2f, paint)
        val cut = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            color = 0xFFFFFFFF.toInt()
            textAlign = Paint.Align.CENTER
            textSize = sizePx * 0.42f
            typeface = Typeface.DEFAULT_BOLD
            xfermode = PorterDuffXfermode(PorterDuff.Mode.CLEAR)
        }
        val text = when (state) {
            is SignState.Limit -> state.value.toString()
            else -> "–"
        }
        val y = cx - (cut.descent() + cut.ascent()) / 2f
        canvas.drawText(text, cx, y, cut)
        return bitmap
    }
}
