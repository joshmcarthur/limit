package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class OverLimitTest {
    @Test
    fun triggersAtTolerance() {
        val e = OverLimitEvaluator(tolerance = 3)
        assertEquals(OverLimitState.NotOver, e.evaluate(speed = 52, limit = 50))
        assertEquals(OverLimitState.Over(by = 3), e.evaluate(speed = 53, limit = 50))
    }

    @Test
    fun reportsDeltaLikeTheDesign() {
        val e = OverLimitEvaluator(tolerance = 3)
        assertEquals(OverLimitState.Over(by = 8), e.evaluate(speed = 38, limit = 30))
    }

    @Test
    fun hysteresisKeepsOverUntilBelowClearThreshold() {
        val e = OverLimitEvaluator(tolerance = 3)
        e.evaluate(speed = 54, limit = 50)
        assertTrue(e.evaluate(speed = 52, limit = 50).isOver)
        assertEquals(OverLimitState.NotOver, e.evaluate(speed = 51, limit = 50))
        assertEquals(OverLimitState.NotOver, e.evaluate(speed = 52, limit = 50))
    }

    @Test
    fun missingInputsClear() {
        val e = OverLimitEvaluator(tolerance = 3)
        e.evaluate(speed = 60, limit = 50)
        assertEquals(OverLimitState.NotOver, e.evaluate(speed = null, limit = 50))
        assertEquals(OverLimitState.NotOver, e.evaluate(speed = 52, limit = 50))
        e.evaluate(speed = 60, limit = 50)
        assertEquals(OverLimitState.NotOver, e.evaluate(speed = 60, limit = null))
    }

    @Test
    fun toleranceIsClamped() {
        assertEquals(1, OverLimitEvaluator(tolerance = 0).tolerance)
        assertEquals(10, OverLimitEvaluator(tolerance = 99).tolerance)
    }

    @Test
    fun toleranceOneClearsAtLimit() {
        val e = OverLimitEvaluator(tolerance = 1)
        assertEquals(OverLimitState.Over(by = 1), e.evaluate(speed = 51, limit = 50))
        assertEquals(OverLimitState.NotOver, e.evaluate(speed = 50, limit = 50))
    }
}
