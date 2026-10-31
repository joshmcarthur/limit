package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertEquals

class AccessibilityTest {
    @Test
    fun signLabels() {
        assertEquals("Speed limit 50 kilometres per hour", AccessibilityLabels.sign(SignState.Limit(50, isStale = false)))
        assertEquals("Speed limit unknown", AccessibilityLabels.sign(SignState.Unknown))
        assertEquals(
            "No limit recorded for this road, follow the posted signs",
            AccessibilityLabels.sign(SignState.OpenRoad(isStale = false)),
        )
    }

    @Test
    fun readoutLabels() {
        assertEquals("Your speed is 47 kilometres per hour", AccessibilityLabels.readout(speed = 47, over = OverLimitState.NotOver))
        assertEquals(
            "Your speed is 38 kilometres per hour, 8 over the limit",
            AccessibilityLabels.readout(speed = 38, over = OverLimitState.Over(by = 8)),
        )
        assertEquals(
            "Your speed isn't available, there's no GPS",
            AccessibilityLabels.readout(speed = null, over = OverLimitState.NotOver),
        )
    }
}
