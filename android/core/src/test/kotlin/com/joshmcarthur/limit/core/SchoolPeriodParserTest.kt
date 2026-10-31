package com.joshmcarthur.limit.core

import java.io.File
import java.time.OffsetDateTime
import org.json.JSONObject
import org.junit.jupiter.api.Assumptions
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class SchoolPeriodParserTest {
    private fun w(sh: Int, sm: Int, eh: Int, em: Int): TimeWindow =
        TimeWindow(startMinute = sh * 60 + sm, endMinute = eh * 60 + em)!!

    @Test
    fun wordingsFromTheRegister() {
        val cases = listOf(
            "Periods of Operation 08:30 – 9:15am and 2:45 – 3:30pm" to listOf(w(8, 30, 9, 15), w(14, 45, 15, 30)),
            "School Days 8.30 to 9.30 am and 2.30 to 3.30 pm" to listOf(w(8, 30, 9, 30), w(14, 30, 15, 30)),
            "School Days 8.30am to 9.30am and 2.30pm to 3.30pm   " to listOf(w(8, 30, 9, 30), w(14, 30, 15, 30)),
            "7.45am to 9.15am & \n2.30pm to 4.00pm, \nSchool Days Only" to listOf(w(7, 45, 9, 15), w(14, 30, 16, 0)),
            "8.15-9am, 2.45-3.30pm" to listOf(w(8, 15, 9, 0), w(14, 45, 15, 30)),
            "8.20am - 9.20am,\n2.20pm - 3.20pm" to listOf(w(8, 20, 9, 20), w(14, 20, 15, 20)),
            "8:00-9:30am\n2:30-3:30pm\n10 minutes at any other time when children cross the road or enter or leave vehicles at the roadside." to
                listOf(w(8, 0, 9, 30), w(14, 30, 15, 30)),
            "School morning period starts at 8.25am and ends at 9.00am;\nSchool afternoon period starts at 2.55pm and ends at 3.15pm;\n10 minutes at any other time when children cross the road or enter or leave vehicles at the roadside." to
                listOf(w(8, 25, 9, 0), w(14, 55, 15, 15)),
            "40km/h variable speed limit between the hours of 8:00am - 9:30am and 2:30pm - 3:30pm on any school day, and for up to ten minutes at any other time when children cross the road or enter or leave vehicles at the side of the road." to
                listOf(w(8, 0, 9, 30), w(14, 30, 15, 30)),
        )
        for ((text, expected) in cases) {
            assertEquals(expected, SchoolPeriodParser.windows(text), text)
        }
    }

    @Test
    fun relativeToTheBellHasNoClockTimes() {
        val relative = listOf(
            "35 minutes before the start of school until the start of school;\n20 minutes at the end of school, beginning no earlier than 5 minutes before the end of school;\n10 minutes at any other time when children cross the road or enter or leave vehicles at the roadside.",
            "45 minutes before the start of school and ending no later than 45 minutes after the start; 45 minutes after the end of school, beginning no earlier than 45 minutes before the end of school.",
            "Periods of Operation The 30km/h speed limit may operate for a maximum period of:(a) 35 minutes before the start of school until the start of school;(b) 20 minutes at the end of school, beginning no earlier than 5 minutes before the end of school;(c) 10 minutes at any other time when children cross the road or enter or leave vehicles at the roadside.",
        )
        for (text in relative) assertNull(SchoolPeriodParser.windows(text), text)
    }

    @Test
    fun highwayVariableSpeedNoticesAreNotWindows() {
        assertNull(SchoolPeriodParser.windows("A variable speed limit of 50 60 70 80 90 or 100 km/h.A speed limit applies from the point on the State highway at which a variable speed limit sign facing the road user is installed."))
        assertNull(SchoolPeriodParser.windows("Waka Kotahi may set a 30/40/50/60/70/80 or 100km/h variable speed limit on the sections of State Highway 1."))
    }

    @Test
    fun timesThatDifferByDayAreNotGuessed() {
        assertNull(SchoolPeriodParser.windows("30km/h variable speed limit between the hours of 8:25am - 9:15am and 2:30pm - 3:20pm on any school day (Monday, Tuesday, Wednesday, and Thursday only)"))
        assertNull(SchoolPeriodParser.windows("8.10-8.45am and 3.10-3.30pm (2.30-2.50pm on Wednesdays)"))
    }

    @Test
    fun listsOfSeveralSchoolsAreNotGuessed() {
        assertNull(SchoolPeriodParser.windows("Schools:\n\nPapakōwhai School\n8:15 a.m. - 9:30 a.m.\n2:30 p.m. - 3:30 p.m.\n\nRangikura School\n8:15 a.m. - 9:30 a.m.\n2:30 p.m. - 3:30 p.m."))
    }

    @Test
    fun dottedAMPM() {
        assertEquals(
            listOf(w(8, 15, 9, 30), w(13, 30, 15, 30)),
            SchoolPeriodParser.windows("8:15 a.m. - 9:30 a.m.\n1:30 p.m. - 3:30 p.m."),
        )
    }

    @Test
    fun singleWindowIsAccepted() {
        assertEquals(listOf(w(8, 30, 9, 15)), SchoolPeriodParser.windows("8.30am to 9.15am"))
    }

    @Test
    fun startInTheMorningWhenOnlyTheEndSaysPM() {
        assertEquals(listOf(w(11, 30, 12, 15)), SchoolPeriodParser.windows("11.30 to 12.15 pm"))
    }

    @Test
    fun implausibleWindowsAreRejected() {
        assertNull(SchoolPeriodParser.windows("9.30am to 8.30am"), "ends before it starts")
        assertNull(SchoolPeriodParser.windows("8.00am to 2.00pm"), "longer than a school period")
        assertNull(SchoolPeriodParser.windows("1.00am to 2.00am"), "middle of the night")
        assertNull(SchoolPeriodParser.windows("8.00am to 9.00am and 8.30am to 9.30am"), "overlapping")
        assertNull(SchoolPeriodParser.windows("8.00am to 9.00am and 2.00pm"), "odd number of times")
        assertNull(SchoolPeriodParser.windows(""))
    }

    private fun date(iso: String) = OffsetDateTime.parse(iso).toInstant()

    @Test
    fun activeOnlyOnWeekdaysInsideTheWindowsInNZTime() {
        val reduced = ReducedLimit(limit = 40, windows = listOf(w(8, 30, 9, 15), w(14, 45, 15, 30)))!!
        assertTrue(reduced.isActive(date("2026-10-22T08:30:00+13:00")), "window start is inclusive")
        assertTrue(reduced.isActive(date("2026-10-22T15:29:00+13:00")))
        assertFalse(reduced.isActive(date("2026-10-22T09:15:00+13:00")), "window end is exclusive")
        assertFalse(reduced.isActive(date("2026-10-22T12:00:00+13:00")))
        assertTrue(reduced.isActive(date("2026-10-21T19:40:00Z")), "08:40 NZDT")
        assertFalse(reduced.isActive(date("2026-10-24T08:45:00+13:00")))
        assertFalse(reduced.isActive(date("2026-10-25T08:45:00+13:00")))
        assertTrue(reduced.isActive(date("2026-10-19T08:45:00+13:00")))
        assertTrue(reduced.isActive(date("2026-10-23T08:45:00+13:00")))
    }

    @Test
    fun noWindowsMeansNoReducedLimit() {
        assertNull(ReducedLimit(limit = 40, windows = emptyList()))
    }

    @Test
    fun coverageOnASavedCopyOfTheRegister() {
        val dir = listOf(File("data"), File("../data"), File("../../data")).firstOrNull { it.isDirectory } ?: File("data")
        val texts = mutableListOf<String>()
        for (name in listOf("var0.json", "var2000.json", "var4000.json")) {
            val file = File(dir, name)
            if (!file.isFile) continue
            val root = JSONObject(file.readText())
            val features = root.optJSONArray("features") ?: continue
            for (i in 0 until features.length()) {
                val attributes = features.optJSONObject(i)?.optJSONObject("attributes") ?: continue
                if (attributes.isNull("speedLimitZoneVarPrdDesc")) continue
                val text = attributes.opt("speedLimitZoneVarPrdDesc")
                if (text is String) texts.add(text)
            }
        }
        Assumptions.assumeTrue(texts.isNotEmpty()) { "no saved register sample in data/" }
        val parsed = texts.count { SchoolPeriodParser.windows(it) != null }
        println("school windows parsed from $parsed of ${texts.size} records")
        assertTrue(parsed.toDouble() / texts.size.toDouble() > 0.5)
    }
}
