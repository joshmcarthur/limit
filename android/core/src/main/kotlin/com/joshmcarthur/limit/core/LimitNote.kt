package com.joshmcarthur.limit.core

/**
 * A note shown with the limit when it's one that comes and goes, so the driver doesn't take it for
 * the permanent limit. Permanent limits and school zones carry none.
 */
enum class LimitNote {
    seasonal,
    temporary,
    ;

    val label: String
        get() = when (this) {
            seasonal -> "Seasonal limit, obey the posted signs"
            temporary -> "Temporary limit, obey the posted signs"
        }

    /** For VoiceOver, after the limit itself. */
    val spoken: String
        get() = when (this) {
            seasonal -> "seasonal"
            temporary -> "temporary"
        }

    companion object {
        operator fun invoke(kind: ZoneKind?): LimitNote? = when (kind) {
            ZoneKind.seasonal -> seasonal
            ZoneKind.emergency -> temporary
            ZoneKind.permanent, ZoneKind.variable, null -> null
        }
    }
}
