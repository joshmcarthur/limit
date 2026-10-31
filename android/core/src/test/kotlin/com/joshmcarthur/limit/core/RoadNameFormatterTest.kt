package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class RoadNameFormatterTest {
    @Test
    fun titleCase() {
        assertEquals("Gloucester Street", RoadNameFormatter.display("GLOUCESTER STREET"))
        assertEquals("Main North Road", RoadNameFormatter.display("  MAIN NORTH ROAD "))
    }

    @Test
    fun stripsUTASuffix() {
        assertEquals("Wellington City", RoadNameFormatter.display("WELLINGTON CITY UTA"))
    }

    @Test
    fun keepsStateHighwayAbbreviations() {
        assertEquals(
            "Blakes Road - Shands Road To SH 76",
            RoadNameFormatter.display("BLAKES ROAD - SHANDS ROAD TO SH 76"),
        )
        assertEquals("Old North Road - From SH1", RoadNameFormatter.display("OLD NORTH ROAD - FROM SH1"))
    }

    @Test
    fun parenthesesAndHyphens() {
        assertEquals("Te Paerahi (Porangahau Beach)", RoadNameFormatter.display("TE PAERAHI (PORANGAHAU BEACH)"))
        assertEquals("Mt-Victoria", RoadNameFormatter.display("MT-VICTORIA"))
    }

    @Test
    fun emptyIsNil() {
        assertNull(RoadNameFormatter.display(null))
        assertNull(RoadNameFormatter.display("   "))
        assertNull(RoadNameFormatter.display(" UTA"))
    }
}
