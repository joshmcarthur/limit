package com.joshmcarthur.limit.core

/**
 * A note shown when the limit is not a single permanent number. A permanent limit carries none.
 */
enum class LimitNote {
    seasonal,
    temporary,
    variable,
    ;

    val label: String
        get() = when (this) {
            seasonal -> "Seasonal limit, obey the posted signs"
            temporary -> "Temporary limit, obey the posted signs"
            variable -> "Variable limit, obey the posted signs"
        }

    /** For VoiceOver, after the limit itself. */
    val spoken: String
        get() = when (this) {
            seasonal -> "seasonal"
            temporary -> "temporary"
            variable -> "variable"
        }

    companion object {
        operator fun invoke(kind: ZoneKind?): LimitNote? = when (kind) {
            ZoneKind.seasonal -> seasonal
            ZoneKind.emergency -> temporary
            ZoneKind.variable -> variable
            ZoneKind.permanent, null -> null
        }
    }
}
