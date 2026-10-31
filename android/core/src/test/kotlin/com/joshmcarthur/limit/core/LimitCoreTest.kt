package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertTrue

class LimitCoreTest {
    @Test
    fun registerName() {
        assertEquals("NZTA National Speed Limit Register", LimitCore.registerName)
    }

    @Test
    fun attributionNamesTheAuthorAndTheRegister() {
        assertTrue(LimitCore.attribution.contains("Waka Kotahi"))
        assertTrue(LimitCore.attribution.contains("National Speed Limit Register"))
    }

    @Test
    fun userAgentIdentifiesTheAndroidApp() {
        assertEquals(
            "Limit-Android/0.1.0 (+https://github.com/joshmcarthur/limit)",
            LimitCore.userAgent("0.1.0"),
        )
        assertTrue(LimitCore.userAgent().startsWith("Limit-Android/"))
    }
}
