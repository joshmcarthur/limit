package com.joshmcarthur.limit.core

import java.time.Duration
import java.time.Instant
import org.json.JSONObject

data class LocationSample(
    var coordinate: Coordinate,
    /** Metres per second; negative when the system has no valid speed. */
    var speedMetresPerSecond: Double,
    /** Metres; negative when the position is invalid. */
    var horizontalAccuracy: Double,
    var timestamp: Instant,
)

enum class GPSQuality {
    searching,
    weak,
    good,
    ;

    /** Status line copy for the top of the driving screen. */
    val label: String
        get() = when (this) {
            searching -> "Searching for GPS…"
            weak -> "GPS · weak"
            good -> "GPS · good"
        }
}

/** Everything a driving surface (app, Live Activity, widget) needs to draw one frame. */
data class DriveSnapshot(
    val sign: SignState = SignState.Unknown,
    val speed: Int? = null,
    val over: OverLimitState = OverLimitState.NotOver,
    val roadName: String? = null,
    /** Set when the limit shown is a seasonal or temporary one. */
    val limitNote: LimitNote? = null,
    /**
     * The position is outside New Zealand, where there is no data: the limit is unknown for good reason,
     * not because the road is still being found.
     */
    val isOutsideNewZealand: Boolean = false,
) {
    val limit: Int?
        get() = sign.limit

    fun encoded(): ByteArray = toJson().toString().toByteArray(Charsets.UTF_8)

    private fun toJson(): JSONObject {
        val json = JSONObject()
        json.put("sign", sign.toJson())
        if (speed != null) json.put("speed", speed)
        json.put("over", over.toJson())
        if (roadName != null) json.put("roadName", roadName)
        if (limitNote != null) json.put("limitNote", limitNote.name)
        json.put("isOutsideNewZealand", isOutsideNewZealand)
        return json
    }

    companion object {
        val searching: DriveSnapshot = DriveSnapshot()

        fun decode(data: ByteArray): DriveSnapshot {
            val json = JSONObject(String(data, Charsets.UTF_8))
            return DriveSnapshot(
                sign = json.getJSONObject("sign").toSignState(),
                speed = if (json.has("speed") && !json.isNull("speed")) json.getInt("speed") else null,
                over = json.getJSONObject("over").toOverLimitState(),
                roadName = if (json.has("roadName") && !json.isNull("roadName")) json.getString("roadName") else null,
                limitNote = if (json.has("limitNote") && !json.isNull("limitNote")) {
                    LimitNote.valueOf(json.getString("limitNote"))
                } else {
                    null
                },
                isOutsideNewZealand = if (json.has("isOutsideNewZealand")) json.getBoolean("isOutsideNewZealand") else false,
            )
        }
    }
}

data class DriveState(
    val snapshot: DriveSnapshot,
    val gps: GPSQuality,
) {
    companion object {
        val searching: DriveState = DriveState(snapshot = DriveSnapshot.searching, gps = GPSQuality.searching)
    }
}

/**
 * Turns location samples into drive state. A sample that is too old, or whose position is too poor,
 * shows as no speed and an unknown limit rather than a frozen last value.
 */
class DriveEngine(
    register: SpeedLimitRegister = SpeedLimitRegister.empty,
    var registerCheckedAt: Instant? = null,
    var freshness: FreshnessPolicy = FreshnessPolicy.standard,
    tolerance: Int = OverLimitEvaluator.defaultTolerance,
) {
    var register: SpeedLimitRegister = register
        set(value) {
            field = value
            zone.reset()
        }

    val evaluator: OverLimitEvaluator = OverLimitEvaluator(tolerance)

    /** A sample older than this at display time is treated as lost. */
    var maxSampleAge: Duration = Duration.ofSeconds(5)

    /** Worse than this (metres) and the position can't say which road you are on. */
    var maxUsableAccuracy: Double = 100.0

    var goodAccuracy: Double = 25.0

    /**
     * How many samples in a row must agree on a different zone before the sign changes. One stray fix
     * near a boundary (GPS wander of tens of metres) then can't flip the limit; 2 costs about a second.
     */
    var zoneChangeConfirmations: Int = 2

    private var lastSample: LocationSample? = null
    private val zone = ZoneConfirmer()

    fun ingest(sample: LocationSample, now: Instant = Instant.now()): DriveState {
        lastSample = sample
        if (sample.horizontalAccuracy >= 0 && sample.horizontalAccuracy <= maxUsableAccuracy) {
            zone.observe(
                register.lookup(sample.coordinate, at = now, preferring = zone.current),
                zoneChangeConfirmations,
            )
        }
        return state(now)
    }

    /** Recompute without a new sample, so a stalled GPS ages out of the display. */
    fun state(now: Instant = Instant.now()): DriveState {
        val sample = lastSample
        if (
            sample == null ||
            Duration.between(sample.timestamp, now) > maxSampleAge ||
            sample.horizontalAccuracy < 0 ||
            sample.horizontalAccuracy > maxUsableAccuracy
        ) {
            evaluator.evaluate(speed = null, limit = null)
            zone.reset()
            return DriveState.searching
        }

        val speed = Speed.displayed(Speed.kilometresPerHour(sample.speedMetresPerSecond))
        val match = zone.current
        val age = registerCheckedAt?.let { Duration.between(it, now) }
        val sign = SignState.make(
            limit = match?.limit,
            dataAge = age,
            isDefaultArea = match?.isDefaultArea ?: false,
            postedLimitUnknown = match?.postedLimitUnknown ?: false,
            policy = freshness,
        )
        val over = evaluator.evaluate(speed = speed, limit = sign.limit)

        var snapshot = DriveSnapshot(sign = sign, speed = speed, over = over)
        if (sign.isOpenRoad) {
            snapshot = snapshot.copy(roadName = "Open road")
        } else if (match == null && !Coverage.isNewZealand(sample.coordinate)) {
            snapshot = snapshot.copy(roadName = Coverage.outsideNewZealandName, isOutsideNewZealand = true)
        } else if (sign.limit != null || sign.isVariablePosted) {
            snapshot = snapshot.copy(
                roadName = RoadNameFormatter.display(match?.zoneName),
                limitNote = LimitNote(kind = match?.kind),
            )
        }
        val gps = if (sample.horizontalAccuracy <= goodAccuracy) GPSQuality.good else GPSQuality.weak
        return DriveState(snapshot = snapshot, gps = gps)
    }
}

private fun SignState.toJson(): JSONObject = when (this) {
    is SignState.Limit -> JSONObject().put("type", "limit").put("value", value).put("isStale", isStale)
    is SignState.OpenRoad -> JSONObject().put("type", "openRoad").put("isStale", isStale)
    is SignState.VariablePosted -> JSONObject().put("type", "variablePosted").put("isStale", isStale)
    SignState.Unknown -> JSONObject().put("type", "unknown")
}

private fun JSONObject.toSignState(): SignState = when (val type = getString("type")) {
    "limit" -> SignState.Limit(value = getInt("value"), isStale = getBoolean("isStale"))
    "openRoad" -> SignState.OpenRoad(isStale = getBoolean("isStale"))
    "variablePosted" -> SignState.VariablePosted(isStale = getBoolean("isStale"))
    "unknown" -> SignState.Unknown
    else -> error("Unknown sign type $type")
}

private fun OverLimitState.toJson(): JSONObject = when (this) {
    OverLimitState.NotOver -> JSONObject().put("type", "notOver")
    is OverLimitState.Over -> JSONObject().put("type", "over").put("by", by)
}

private fun JSONObject.toOverLimitState(): OverLimitState = when (val type = getString("type")) {
    "notOver" -> OverLimitState.NotOver
    "over" -> OverLimitState.Over(by = getInt("by"))
    else -> error("Unknown over-limit type $type")
}
