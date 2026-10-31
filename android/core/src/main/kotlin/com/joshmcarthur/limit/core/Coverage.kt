package com.joshmcarthur.limit.core

/**
 * Where the register has data. It is New Zealand's, so anywhere else a missing limit means "we don't cover
 * this country", not "still looking", and the screen says so.
 */
object Coverage {
    private data class Box(
        val south: Double,
        val north: Double,
        val west: Double,
        val east: Double,
    ) {
        fun contains(c: Coordinate): Boolean =
            c.latitude in south..north && c.longitude in west..east
    }

    /**
     * Rough boxes with a margin of a few tens of kilometres, so a coastal road or the sea just off it isn't
     * called foreign. Not borders: they only decide which words to show when no zone matches.
     */
    private val boxes = listOf(
        // North, South and Stewart Islands.
        Box(south = -47.8, north = -34.0, west = 165.8, east = 179.3),
        // Chatham Islands, across the date line from the rest.
        Box(south = -44.8, north = -43.4, west = -177.4, east = -175.3),
    )

    fun isNewZealand(point: Coordinate): Boolean = boxes.any { it.contains(point) }

    const val outsideNewZealandName = "Outside New Zealand"
    const val outsideNewZealandDetail = "Limit only has New Zealand speed limits. Your speed is still shown."
}
