package com.joshmcarthur.limit.core

import java.time.Instant

/** A region of the register with one posted limit. */
class SpeedZone private constructor(
    /** The register's identifier for the zone. Only used to drop repeated records; not stored on disk. */
    val id: String?,
    val name: String?,
    /** The permanent limit. */
    val limit: Int,
    /** A lower limit that applies at set times (a school zone), if the register gives one we can read. */
    val reduced: ReducedLimit?,
    val kind: ZoneKind,
    val structure: StructureType,
    /** When the record applies; null means always. */
    val period: ActivePeriod?,
    val polygons: List<Polygon>,
    val bounds: BoundingBox,
) {
    /** Whether the record applies at [date]: an ended, not yet started or out-of-season record doesn't. */
    fun isActive(at: Instant): Boolean = period?.isActive(at) ?: true

    /** The limit in force at [date]: the reduced one inside its windows, otherwise the permanent one. */
    fun effectiveLimit(at: Instant): Int {
        val reducedLimit = reduced
        if (reducedLimit != null && reducedLimit.limit < limit && reducedLimit.isActive(at)) return reducedLimit.limit
        return limit
    }

    fun contains(point: Coordinate): Boolean {
        if (!bounds.contains(point)) return false
        return polygons.any { it.contains(point) }
    }

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is SpeedZone) return false
        return id == other.id && name == other.name && limit == other.limit && reduced == other.reduced &&
            kind == other.kind && structure == other.structure && period == other.period &&
            polygons == other.polygons && bounds == other.bounds
    }

    override fun hashCode(): Int {
        var result = id?.hashCode() ?: 0
        result = 31 * result + (name?.hashCode() ?: 0)
        result = 31 * result + limit
        result = 31 * result + (reduced?.hashCode() ?: 0)
        result = 31 * result + kind.hashCode()
        result = 31 * result + structure.hashCode()
        result = 31 * result + (period?.hashCode() ?: 0)
        result = 31 * result + polygons.hashCode()
        result = 31 * result + bounds.hashCode()
        return result
    }

    companion object {
        operator fun invoke(
            id: String? = null,
            name: String?,
            limit: Int,
            reduced: ReducedLimit? = null,
            kind: ZoneKind = ZoneKind.permanent,
            structure: StructureType = StructureType.none,
            period: ActivePeriod? = null,
            polygons: List<Polygon>,
        ): SpeedZone? {
            val first = polygons.firstOrNull() ?: return null
            val box = first.bounds.copy()
            for (polygon in polygons.drop(1)) {
                val b = polygon.bounds
                box.minLatitude = minOf(box.minLatitude, b.minLatitude)
                box.maxLatitude = maxOf(box.maxLatitude, b.maxLatitude)
                box.minLongitude = minOf(box.minLongitude, b.minLongitude)
                box.maxLongitude = maxOf(box.maxLongitude, b.maxLongitude)
            }
            return SpeedZone(
                id = id,
                name = name,
                limit = limit,
                reduced = reduced,
                kind = kind,
                structure = structure,
                period = period,
                polygons = polygons,
                bounds = box,
            )
        }
    }
}
