@file:OptIn(ExperimentalTextApi::class)

package com.joshmcarthur.limit.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.ExperimentalTextApi
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import com.joshmcarthur.limit.R

val SignNumeralFont = FontFamily(
    Font(
        R.font.robotoflex,
        variationSettings = FontVariation.Settings(
            FontVariation.weight(700),
            FontVariation.Setting("wdth", 80f),
        ),
    ),
)

val SpeedReadoutFont = FontFamily(
    Font(
        R.font.robotoflex,
        variationSettings = FontVariation.Settings(
            FontVariation.weight(900),
            FontVariation.Setting("wdth", 112f),
        ),
    ),
)

val LimitTypography = Typography()
