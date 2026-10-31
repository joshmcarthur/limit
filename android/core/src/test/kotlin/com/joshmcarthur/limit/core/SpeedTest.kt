package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertNull

class SpeedTest {
    @Test
    fun conversion() {
        assertEquals(36.0, Speed.kilometresPerHour(10.0)!!, 1e-9)
        assertEquals(0.0, Speed.kilometresPerHour(0.0)!!, 1e-9)
    }

    @Test
    fun invalidSpeedsAreNil() {
        assertNull(Speed.kilometresPerHour(-1.0))
        assertNull(Speed.kilometresPerHour(Double.NaN))
        assertNull(Speed.kilometresPerHour(Double.POSITIVE_INFINITY))
    }

    @Test
    fun displayedRounds() {
        assertEquals(47, Speed.displayed(46.5))
        assertEquals(46, Speed.displayed(46.49))
        assertNull(Speed.displayed(null))
        assertNull(Speed.displayed(-3.0))
    }
}
