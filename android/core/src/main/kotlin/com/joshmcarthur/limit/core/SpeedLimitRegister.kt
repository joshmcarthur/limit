package com.joshmcarthur.limit.core

import java.time.Instant
import java.util.Locale
import kotlin.math.floor

class SpeedLimitMatch(
    val limit: Int,
    val zoneName: String?,
    /** Seasonal and emergency limits end, so the driver is told which one they're looking at. */
    val kind: ZoneKind = ZoneKind.permanent,
    /** The sign on the road can show a lower number than [limit]. The circle is drawn empty. */
    val postedLimitUnknown: Boolean = false,
    /** Which zone in the register matched, so the next lookup can prefer staying in it. */
    val zoneID: Int = -1,
) {
    /**
     * The register's catch-all record (`DEFAULT SPEED LIMIT`, and its `- INTERSECTION n` variants), which
     * covers anywhere no zone is recorded.
     */
    val isDefaultArea: Boolean
        get() = zoneName?.trimWhitespaces()?.uppercase(Locale.ROOT)?.startsWith("DEFAULT SPEED LIMIT") == true

    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is SpeedLimitMatch) return false
        return limit == other.limit && zoneName == other.zoneName && kind == other.kind &&
            postedLimitUnknown == other.postedLimitUnknown
    }

    override fun hashCode(): Int {
        var result = limit
        result = 31 * result + (zoneName?.hashCode() ?: 0)
        result = 31 * result + kind.hashCode()
        result = 31 * result + if (postedLimitUnknown) 1 else 0
        return result
    }
}

/**
 * An in-memory register with a uniform grid index, so a lookup only tests the few zones near the point.
 */
class SpeedLimitRegister private constructor(
    val zoneCount: Int,
    private val cellSize: Double,
    private val zones: List<SpeedZone>,
    private val grid: Map<Cell, List<Int>>,
    private val wide: List<Int>,
) {
    /**
     * The limit at a point and time. Only records that apply at [at] count. Of those, an emergency limit
     * beats a seasonal one, which beats a permanent or variable one. Among equals the zone with the smallest
     * extent wins, and the lower limit wins a tie.
     *
     * Where a bridge and the road under it overlap with different limits, the zone in [preferring] wins if
     * it's one of the two, otherwise the lower limit does.
     */
    fun lookup(
        point: Coordinate,
        at: Instant = Instant.now(),
        preferring: SpeedLimitMatch? = null,
    ): SpeedLimitMatch? {
        val key = Cell(cell(point.latitude), cell(point.longitude))
        val candidates = mutableListOf<Int>()
        for (index in (grid[key] ?: emptyList()) + wide) {
            val zone = zones[index]
            if (zone.contains(point) && zone.isActive(at)) candidates.add(index)
        }
        val initial = candidates.firstOrNull() ?: return null
        var best = initial
        for (index in candidates.drop(1)) {
            if (outranks(index, best, at)) best = index
        }

        if (zones[best].structure.isGradeSeparated) {
            val opposite = if (zones[best].structure == StructureType.overpass) {
                StructureType.underpass
            } else {
                StructureType.overpass
            }
            val rivals = candidates.filter {
                zones[it].structure == opposite && zones[it].kind.priority == zones[best].kind.priority
            }
            val firstRival = rivals.firstOrNull()
            if (firstRival != null) {
                var other: Int = firstRival
                for (index in rivals.drop(1)) {
                    if (outranks(index, other, at)) other = index
                }
                if (zones[other].effectiveLimit(at) != zones[best].effectiveLimit(at)) {
                    if (preferring != null && (preferring.zoneID == best || preferring.zoneID == other)) {
                        best = preferring.zoneID
                    } else if (zones[other].effectiveLimit(at) < zones[best].effectiveLimit(at)) {
                        best = other
                    }
                }
            }
        }
        val zone = zones[best]
        return SpeedLimitMatch(
            limit = zone.effectiveLimit(at),
            zoneName = zone.name,
            kind = zone.kind,
            postedLimitUnknown = zone.postedLimitUnknown,
            zoneID = best,
        )
    }

    /** Whether zone [a] should be shown in preference to zone [b]. */
    private fun outranks(a: Int, b: Int, at: Instant): Boolean {
        val za = zones[a]
        val zb = zones[b]
        if (za.kind.priority != zb.kind.priority) return za.kind.priority > zb.kind.priority
        val areaA = za.bounds.area
        val areaB = zb.bounds.area
        if (areaA != areaB) return areaA < areaB
        return za.effectiveLimit(at) < zb.effectiveLimit(at)
    }

    private fun cell(degrees: Double): Int = floor(degrees / cellSize).toInt()

    private data class Cell(val row: Int, val column: Int)

    companion object {
        /**
         * Zones whose bounds span more cells than this go in a short list checked on every lookup,
         * rather than being inserted in thousands of cells.
         */
        private const val maxCellsPerZone = 2_500

        val empty: SpeedLimitRegister = SpeedLimitRegister(emptyList())

        operator fun invoke(zones: List<SpeedZone>, cellSize: Double = 0.05): SpeedLimitRegister {
            val grid = mutableMapOf<Cell, MutableList<Int>>()
            val wide = mutableListOf<Int>()
            for ((index, zone) in zones.withIndex()) {
                val b = zone.bounds
                val rowStart = cellOf(b.minLatitude, cellSize)
                val rowEnd = cellOf(b.maxLatitude, cellSize)
                val columnStart = cellOf(b.minLongitude, cellSize)
                val columnEnd = cellOf(b.maxLongitude, cellSize)
                val rows = (rowEnd - rowStart + 1).toLong()
                val columns = (columnEnd - columnStart + 1).toLong()
                if (rows * columns > maxCellsPerZone) {
                    wide.add(index)
                    continue
                }
                for (row in rowStart..rowEnd) {
                    for (column in columnStart..columnEnd) {
                        grid.getOrPut(Cell(row, column)) { mutableListOf() }.add(index)
                    }
                }
            }
            return SpeedLimitRegister(zones.size, cellSize, zones, grid, wide)
        }

        private fun cellOf(degrees: Double, cellSize: Double): Int = floor(degrees / cellSize).toInt()
    }
}
