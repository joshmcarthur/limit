package com.joshmcarthur.limit.core

/**
 * The register lists a zone once per record, and the same zone (same id, same shape) often appears
 * several times. Keeping one of each roughly halves what's stored and searched.
 */
object ZoneDeduplicator {
    /**
     * Drops a zone that repeats an earlier one with the same id, limits and geometry. Zones that share an
     * id but differ in shape (separate parts of one zone) and zones with no id are all kept, in order.
     */
    fun unique(zones: List<SpeedZone>): List<SpeedZone> {
        val seen = mutableMapOf<String, MutableList<SpeedZone>>()
        val result = ArrayList<SpeedZone>(zones.size)
        for (zone in zones) {
            val id = zone.id
            if (id == null) {
                result.add(zone)
                continue
            }
            val prior = seen[id]
            if (prior != null && prior.any { repeats(it, zone) }) continue
            seen.getOrPut(id) { mutableListOf() }.add(zone)
            result.add(zone)
        }
        return result
    }

    private fun repeats(earlier: SpeedZone, zone: SpeedZone): Boolean =
        earlier.limit == zone.limit && earlier.reduced == zone.reduced && earlier.kind == zone.kind &&
            earlier.postedLimitUnknown == zone.postedLimitUnknown &&
            earlier.structure == zone.structure && earlier.period == zone.period && earlier.polygons == zone.polygons
}
