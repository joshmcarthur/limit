package com.joshmcarthur.limit.core

import java.io.ByteArrayOutputStream
import kotlin.math.ceil
import kotlin.math.floor

sealed class ZoneCodecError : Exception() {
    data object BadMagic : ZoneCodecError()
    data class UnsupportedVersion(val version: Int) : ZoneCodecError()
    data object Truncated : ZoneCodecError()
    data object Invalid : ZoneCodecError()
}

/**
 * A compact binary form of the register for on-device storage, so launching the app doesn't re-parse
 * GeoJSON. Coordinates are stored as Int32 millionths of a degree (about 0.1 m), which matches the
 * precision the download asks for.
 *
 * Layout, little endian: `LMTZ`, version u8, zone count u32, then per zone: limit u8, reduced limit u8
 * (0 = none) and, if present, window count u8 with start u16 and end u16 (minutes) for each, kind u8,
 * structure u8, period flags u8 (1 = start, 2 = end, 4 = repeats yearly) then start and end as i32 `yyyymmdd`
 * for those present, name length
 * u16 (0 = none) and UTF-8 bytes, polygon count u32; per polygon: ring count u32 (first is the outer ring);
 * per ring: point count u32 then lat i32, lon i32 for each point.
 */
object ZoneCodec {
    val magic: ByteArray = "LMTZ".toByteArray(Charsets.US_ASCII)
    const val version: Int = 3
    private const val scale = 1_000_000.0

    fun encode(zones: List<SpeedZone>): ByteArray {
        val out = ByteArrayOutputStream()
        out.write(magic)
        out.write(version)
        putU32(zones.size.toLong(), out)
        for (zone in zones) {
            out.write(zone.limit.coerceIn(0, 255))
            val reduced = zone.reduced
            if (reduced != null) {
                out.write(reduced.limit.coerceIn(0, 255))
                out.write(reduced.windows.size.coerceIn(0, 255))
                for (window in reduced.windows) {
                    putU16(window.startMinute, out)
                    putU16(window.endMinute, out)
                }
            } else {
                out.write(0)
            }
            out.write(zone.kind.rawValue)
            out.write(zone.structure.rawValue)
            val period = zone.period
            if (period != null) {
                var flags = 0
                if (period.start != null) flags = flags or 1
                if (period.end != null) flags = flags or 2
                if (period.repeatsYearly) flags = flags or 4
                out.write(flags)
                period.start?.let { putI32(ActivePeriod.pack(it), out) }
                period.end?.let { putI32(ActivePeriod.pack(it), out) }
            } else {
                out.write(0)
            }
            val name = (zone.name ?: "").toByteArray(Charsets.UTF_8).let { bytes ->
                if (bytes.size > 0xFFFF) bytes.copyOf(0xFFFF) else bytes
            }
            putU16(name.size, out)
            out.write(name)
            putU32(zone.polygons.size.toLong(), out)
            for (polygon in zone.polygons) {
                val rings = listOf(polygon.outer) + polygon.holes
                putU32(rings.size.toLong(), out)
                for (ring in rings) {
                    putU32(ring.points.size.toLong(), out)
                    for (point in ring.points) {
                        putI32(clampInt32(roundAwayFromZero(point.latitude * scale)), out)
                        putI32(clampInt32(roundAwayFromZero(point.longitude * scale)), out)
                    }
                }
            }
        }
        return out.toByteArray()
    }

    fun decode(data: ByteArray): List<SpeedZone> {
        val reader = Reader(data)
        if (!reader.bytes(4).contentEquals(magic)) throw ZoneCodecError.BadMagic
        val foundVersion = reader.u8()
        if (foundVersion != version) throw ZoneCodecError.UnsupportedVersion(foundVersion)

        val zoneCountLong = reader.u32()
        if (zoneCountLong > reader.remaining.toLong() / 14) throw ZoneCodecError.Truncated
        val zoneCount = zoneCountLong.toInt()
        val zones = ArrayList<SpeedZone>(zoneCount)
        repeat(zoneCount) {
            val limit = reader.u8()
            var reduced: ReducedLimit? = null
            val reducedLimit = reader.u8()
            if (reducedLimit != 0) {
                val windowCount = reader.u8()
                val windows = ArrayList<TimeWindow>(windowCount)
                repeat(windowCount) {
                    val window = TimeWindow(startMinute = reader.u16(), endMinute = reader.u16())
                        ?: throw ZoneCodecError.Invalid
                    windows.add(window)
                }
                reduced = ReducedLimit(limit = reducedLimit, windows = windows) ?: throw ZoneCodecError.Invalid
            }
            val kind = ZoneKind.fromRaw(reader.u8()) ?: throw ZoneCodecError.Invalid
            val structure = StructureType.fromRaw(reader.u8()) ?: throw ZoneCodecError.Invalid
            val flags = reader.u8()
            var period: ActivePeriod? = null
            if (flags != 0) {
                if ((flags and 7.inv()) != 0) throw ZoneCodecError.Invalid
                val start = if (flags and 1 != 0) ActivePeriod.unpack(reader.i32()) else null
                val end = if (flags and 2 != 0) ActivePeriod.unpack(reader.i32()) else null
                if ((flags and 1 != 0 && start == null) || (flags and 2 != 0 && end == null)) {
                    throw ZoneCodecError.Invalid
                }
                period = ActivePeriod(start = start, end = end, repeatsYearly = flags and 4 != 0)
                    ?: throw ZoneCodecError.Invalid
            }
            val nameLength = reader.u16()
            val name = if (nameLength == 0) {
                null
            } else {
                String(reader.bytes(nameLength), Charsets.UTF_8)
            }
            val polygonCountLong = reader.u32()
            if (polygonCountLong > reader.remaining.toLong() / 4) throw ZoneCodecError.Truncated
            val polygonCount = polygonCountLong.toInt()
            val polygons = ArrayList<Polygon>(polygonCount)
            repeat(polygonCount) {
                val ringCountLong = reader.u32()
                if (ringCountLong < 1 || ringCountLong > reader.remaining.toLong() / 4) throw ZoneCodecError.Invalid
                val ringCount = ringCountLong.toInt()
                val rings = ArrayList<Ring>(ringCount)
                repeat(ringCount) {
                    val pointCountLong = reader.u32()
                    if (pointCountLong > reader.remaining.toLong() / 8) throw ZoneCodecError.Truncated
                    val pointCount = pointCountLong.toInt()
                    val points = ArrayList<Coordinate>(pointCount)
                    repeat(pointCount) {
                        val lat = reader.i32().toDouble() / scale
                        val lon = reader.i32().toDouble() / scale
                        points.add(Coordinate(latitude = lat, longitude = lon))
                    }
                    rings.add(Ring(points) ?: throw ZoneCodecError.Invalid)
                }
                polygons.add(Polygon(outer = rings[0], holes = rings.drop(1)))
            }
            val zone = SpeedZone(
                name = name,
                limit = limit,
                reduced = reduced,
                kind = kind,
                structure = structure,
                period = period,
                polygons = polygons,
            ) ?: throw ZoneCodecError.Invalid
            zones.add(zone)
        }
        return zones
    }

    private fun roundAwayFromZero(value: Double): Long =
        if (value >= 0.0) floor(value + 0.5).toLong() else ceil(value - 0.5).toLong()

    private fun clampInt32(value: Long): Int = when {
        value > Int.MAX_VALUE -> Int.MAX_VALUE
        value < Int.MIN_VALUE -> Int.MIN_VALUE
        else -> value.toInt()
    }

    private fun putU16(value: Int, out: ByteArrayOutputStream) {
        out.write(value and 0xFF)
        out.write((value shr 8) and 0xFF)
    }

    private fun putU32(value: Long, out: ByteArrayOutputStream) {
        var shift = 0
        while (shift < 32) {
            out.write(((value shr shift) and 0xFF).toInt())
            shift += 8
        }
    }

    private fun putI32(value: Int, out: ByteArrayOutputStream) {
        putU32(value.toLong() and 0xFFFF_FFFFL, out)
    }

    private class Reader(private val storage: ByteArray) {
        private var offset = 0

        val remaining: Int
            get() = storage.size - offset

        fun bytes(count: Int): ByteArray {
            if (count < 0 || count > remaining) throw ZoneCodecError.Truncated
            val slice = storage.copyOfRange(offset, offset + count)
            offset += count
            return slice
        }

        fun u8(): Int = bytes(1)[0].toInt() and 0xFF

        fun u16(): Int {
            val b = bytes(2)
            return (b[0].toInt() and 0xFF) or ((b[1].toInt() and 0xFF) shl 8)
        }

        fun u32(): Long {
            val b = bytes(4)
            return (b[0].toLong() and 0xFF) or
                ((b[1].toLong() and 0xFF) shl 8) or
                ((b[2].toLong() and 0xFF) shl 16) or
                ((b[3].toLong() and 0xFF) shl 24)
        }

        fun i32(): Int = u32().toInt()
    }
}
