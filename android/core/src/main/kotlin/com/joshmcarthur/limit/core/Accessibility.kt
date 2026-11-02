package com.joshmcarthur.limit.core

/** VoiceOver strings, taken from the component guidelines. */
object AccessibilityLabels {
    fun sign(state: SignState, note: LimitNote? = null): String {
        if (state.isOpenRoad) return "No limit recorded for this road, follow the posted signs"
        if (state.isVariablePosted) return "Variable speed limit, obey the posted signs"
        val limit = state.limit ?: return "Speed limit unknown"
        val spoken = "Speed limit $limit kilometres per hour"
        return if (note == null) spoken else "$spoken, ${note.spoken}"
    }

    fun readout(speed: Int?, over: OverLimitState): String {
        if (speed == null) return "Your speed isn't available, there's no GPS"
        return when (over) {
            is OverLimitState.Over -> "Your speed is $speed kilometres per hour, ${over.by} over the limit"
            OverLimitState.NotOver -> "Your speed is $speed kilometres per hour"
        }
    }
}
