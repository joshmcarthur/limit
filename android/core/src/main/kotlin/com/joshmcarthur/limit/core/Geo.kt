package com.joshmcarthur.limit.core

/** A WGS84 position in degrees. */
data class Coordinate(
    var latitude: Double,
    var longitude: Double,
)

data class BoundingBox(
    var minLatitude: Double,
    var maxLatitude: Double,
    var minLongitude: Double,
    var maxLongitude: Double,
) {
    fun contains(point: Coordinate): Boolean =
        point.latitude >= minLatitude && point.latitude <= maxLatitude &&
            point.longitude >= minLongitude && point.longitude <= maxLongitude

    /** Area in square degrees. Only used to rank overlapping zones, never as a real area. */
    val area: Double
        get() = (maxLatitude - minLatitude) * (maxLongitude - minLongitude)
}

/**
 * A closed ring of coordinates. The closing point may or may not repeat the first.
 * Returns null when there are fewer than three points.
 */
class Ring private constructor(
    val points: List<Coordinate>,
    val bounds: BoundingBox,
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is Ring) return false
        return points == other.points && bounds == other.bounds
    }

    override fun hashCode(): Int = 31 * points.hashCode() + bounds.hashCode()

    /** Even-odd ray casting. Points exactly on an edge may fall either way. */
    fun contains(point: Coordinate): Boolean {
        if (!bounds.contains(point)) return false
        var inside = false
        var j = points.size - 1
        for (i in points.indices) {
            val a = points[i]
            val b = points[j]
            if ((a.latitude > point.latitude) != (b.latitude > point.latitude)) {
                val t = (point.latitude - a.latitude) / (b.latitude - a.latitude)
                val crossingLongitude = a.longitude + t * (b.longitude - a.longitude)
                if (point.longitude < crossingLongitude) inside = !inside
            }
            j = i
        }
        return inside
    }

    companion object {
        operator fun invoke(points: List<Coordinate>): Ring? {
            if (points.size < 3) return null
            var minLat = Double.POSITIVE_INFINITY
            var maxLat = Double.NEGATIVE_INFINITY
            var minLon = Double.POSITIVE_INFINITY
            var maxLon = Double.NEGATIVE_INFINITY
            for (p in points) {
                minLat = minOf(minLat, p.latitude)
                maxLat = maxOf(maxLat, p.latitude)
                minLon = minOf(minLon, p.longitude)
                maxLon = maxOf(maxLon, p.longitude)
            }
            return Ring(
                points,
                BoundingBox(
                    minLatitude = minLat,
                    maxLatitude = maxLat,
                    minLongitude = minLon,
                    maxLongitude = maxLon,
                ),
            )
        }
    }
}

/** An outer ring with optional holes. */
data class Polygon(
    val outer: Ring,
    val holes: List<Ring> = emptyList(),
) {
    val bounds: BoundingBox
        get() = outer.bounds

    fun contains(point: Coordinate): Boolean {
        if (!outer.contains(point)) return false
        return holes.none { it.contains(point) }
    }
}
