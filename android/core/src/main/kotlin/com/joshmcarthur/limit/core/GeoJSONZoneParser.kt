package com.joshmcarthur.limit.core

import java.time.Instant
import kotlin.math.round
import org.json.JSONArray
import org.json.JSONObject

sealed class ZoneParseError : Exception() {
    data object NotAFeatureCollection : ZoneParseError()
}

data class ZoneParseResult(
    var zones: MutableList<SpeedZone> = mutableListOf(),
    var featureCount: Int = 0,
    /** Features with no usable numeric limit. If every feature lands here, the source has no limit field. */
    var skippedWithoutLimit: Int = 0,
    /** ArcGIS sets this when more pages exist. */
    var exceededTransferLimit: Boolean = false,
)

/**
 * Reads speed limit zones from a GeoJSON FeatureCollection (the `pgeojson` output of the register's
 * ArcGIS feature service).
 *
 * Fields are read by their names in the live layer (`speedLimitZoneValue`, `speedLimitZoneName`,
 * `speedLimitZoneId` and the rest), not guessed at. If the layer renames the limit field, every feature
 * lands in `skippedWithoutLimit` and the download fails with `noLimitsInSource` rather than showing wrong limits.
 */
object GeoJSONZoneParser {
    /** NZ limits run from 10 to 110 km/h in steps of 5 or 10. */
    private val validLimits = 10..110

    fun parse(data: ByteArray): ZoneParseResult {
        val root = try {
            JSONObject(String(data, Charsets.UTF_8))
        } catch (_: Exception) {
            throw ZoneParseError.NotAFeatureCollection
        }
        val features = root.optJSONArray("features") ?: throw ZoneParseError.NotAFeatureCollection

        val result = ZoneParseResult()
        val props = root.optJSONObject("properties")
        if (props != null && props.has("exceededTransferLimit") && !props.isNull("exceededTransferLimit")) {
            val exceeded = props.opt("exceededTransferLimit")
            if (exceeded is Boolean) result.exceededTransferLimit = exceeded
        }

        for (index in 0 until features.length()) {
            val feature = features.optJSONObject(index) ?: continue
            result.featureCount += 1
            val properties = feature.optJSONObject("properties") ?: JSONObject()
            val limit = if (properties.has("speedLimitZoneValue") && !properties.isNull("speedLimitZoneValue")) {
                limitValue(properties.get("speedLimitZoneValue"))
            } else {
                null
            }
            if (limit == null) {
                result.skippedWithoutLimit += 1
                continue
            }
            val polygons = polygons(feature.optJSONObject("geometry"))
            val kind = ZoneKind(category = optionalString(properties, "speedCategoryName"))
            val zone = SpeedZone(
                id = text(optional(properties, "speedLimitZoneId")),
                name = text(optional(properties, "speedLimitZoneName")),
                limit = limit,
                reduced = reducedLimit(properties, limit),
                kind = kind,
                structure = StructureType(name = optionalString(properties, "speedLimitZoneStructureTypeName")),
                period = period(properties, kind),
                polygons = polygons,
            ) ?: continue
            result.zones.add(zone)
        }
        return result
    }

    /**
     * `speedLimitZoneVariableSpeed` is the lower limit as text ("40 km/h"), or a list for highway
     * variable-speed signs; only a single, lower value with readable periods is used.
     */
    internal fun reducedLimit(properties: JSONObject, permanent: Int): ReducedLimit? {
        val speed = optionalString(properties, "speedLimitZoneVariableSpeed") ?: return null
        if (speed.contains(",")) return null
        val limit = limitValue(speed) ?: return null
        if (limit >= permanent) return null
        val periods = optionalString(properties, "speedLimitZoneVarPrdDesc") ?: return null
        val windows = SchoolPeriodParser.windows(periods) ?: return null
        return ReducedLimit(limit = limit, windows = windows)
    }

    /**
     * The dates a record applies. The layer uses 1899 and 1900 start dates to mean "always", which are dropped;
     * only a seasonal record flagged as recurring repeats every year.
     */
    internal fun period(properties: JSONObject, kind: ZoneKind): ActivePeriod? {
        val start = date(optional(properties, "speedLimitZoneStartDate"))
        val end = date(optional(properties, "speedLimitZoneEndDate"))
        val recurs = kind == ZoneKind.seasonal && double(optional(properties, "speedLimitZoneSeasonalRecur")) == 1.0
        return ActivePeriod(start = start, end = end, repeatsYearly = recurs)
            ?: ActivePeriod(start = start, end = end)
    }

    /** Dates arrive as milliseconds since 1970; zero or negative is a placeholder. */
    private fun date(value: Any?): Instant? {
        val millis = double(value) ?: return null
        if (millis <= 0.0) return null
        return Instant.ofEpochMilli(millis.toLong())
    }

    /** A trimmed, non-empty string, or null. */
    private fun text(value: Any?): String? {
        val text = (value as? String)?.trimWhitespacesAndNewlines() ?: return null
        return text.ifEmpty { null }
    }

    private fun limitValue(value: Any): Int? {
        val number = if (value is String) {
            val digits = value.trimWhitespaces().takeWhile { it.isDigit() }
            digits.toDoubleOrNull()
        } else {
            double(value)
        }
        if (number == null || number != round(number)) return null
        val limit = number.toInt()
        if (limit !in validLimits || limit % 5 != 0) return null
        return limit
    }

    private fun polygons(geometry: JSONObject?): List<Polygon> {
        if (geometry == null) return emptyList()
        val type = optionalString(geometry, "type") ?: return emptyList()
        val coordinates = geometry.optJSONArray("coordinates") ?: return emptyList()
        return when (type) {
            "Polygon" -> polygon(coordinates)?.let { listOf(it) } ?: emptyList()
            "MultiPolygon" -> {
                val parsed = mutableListOf<Polygon>()
                for (i in 0 until coordinates.length()) {
                    val rings = coordinates.optJSONArray(i) ?: continue
                    val one = polygon(rings) ?: continue
                    parsed.add(one)
                }
                parsed
            }
            else -> emptyList()
        }
    }

    private fun polygon(rings: JSONArray): Polygon? {
        val parsed = mutableListOf<Ring>()
        for (i in 0 until rings.length()) {
            val positions = rings.optJSONArray(i) ?: return null
            parsed.add(ring(positions) ?: return null)
        }
        val outer = parsed.firstOrNull() ?: return null
        if (parsed.size != rings.length()) return null
        return Polygon(outer = outer, holes = parsed.drop(1))
    }

    private fun ring(positions: JSONArray): Ring? {
        val points = ArrayList<Coordinate>(positions.length())
        for (i in 0 until positions.length()) {
            val position = positions.optJSONArray(i) ?: return null
            if (position.length() < 2) return null
            val lon = double(position.opt(0)) ?: return null
            val lat = double(position.opt(1)) ?: return null
            points.add(Coordinate(latitude = lat, longitude = lon))
        }
        return Ring(points)
    }

    private fun optional(object_: JSONObject, key: String): Any? {
        if (!object_.has(key) || object_.isNull(key)) return null
        return object_.get(key)
    }

    private fun optionalString(object_: JSONObject, key: String): String? = optional(object_, key) as? String

    private fun double(value: Any?): Double? = when (value) {
        is Double -> value
        is Float -> value.toDouble()
        is Int -> value.toDouble()
        is Long -> value.toDouble()
        is Number -> value.toDouble()
        else -> null
    }
}
