package com.joshmcarthur.limit.core

import java.util.Locale

/** The register stores names in capitals (`GLOUCESTER STREET`, `WELLINGTON CITY UTA`). */
object RoadNameFormatter {
    private val keepUppercase = setOf("SH", "NZ")

    fun display(raw: String?): String? {
        var text = raw?.trimWhitespacesAndNewlines()?.takeIf { it.isNotEmpty() } ?: return null
        if (text.uppercase(Locale.ROOT).endsWith(" UTA")) text = text.dropLast(4)
        if (text.uppercase(Locale.ROOT) == "UTA") return null
        val words = text.split(" ").filter { it.isNotEmpty() }.map { word ->
            val upper = word.uppercase(Locale.ROOT)
            if (upper in keepUppercase || (upper.startsWith("SH") && upper.drop(2).all { it.isDigit() })) {
                upper
            } else {
                capitalise(word)
            }
        }
        val result = words.joinToString(" ")
        return result.ifEmpty { null }
    }

    /** Capitalises the first letter and any letter after `-` or `(`. */
    private fun capitalise(word: String): String {
        val out = StringBuilder()
        var capitaliseNext = true
        for (character in word) {
            val letter = character.toString()
            out.append(if (capitaliseNext) letter.uppercase(Locale.ROOT) else letter.lowercase(Locale.ROOT))
            capitaliseNext = character == '-' || character == '('
        }
        return out.toString()
    }
}
