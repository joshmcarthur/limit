package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class LimitSettingsTest {
    @Test
    fun defaultsMatchOnboardingDesign() {
        val s = LimitSettings()
        assertTrue(s.showOnLockScreen)
        assertEquals(3, s.overTolerance)
        assertFalse(s.hasCompletedOnboarding)
        assertEquals("+3 km/h", s.toleranceLabel)
        assertTrue(s.suggestEndingDrive)
    }

    @Test
    fun roundTrip() {
        val s = LimitSettings(overTolerance = 5)
        assertEquals(s, LimitSettings.decode(s.encoded()))
    }

    @Test
    fun settingsSavedWithTheOldChimeKeyStillDecode() {
        val old = """{"showOnLockScreen":false,"overTolerance":5,"chimeOnLimitChange":true,"hasCompletedOnboarding":true}"""
            .toByteArray()
        val s = LimitSettings.decode(old)
        assertFalse(s.showOnLockScreen)
        assertEquals(5, s.overTolerance)
        assertTrue(s.hasCompletedOnboarding)
    }

    @Test
    fun settingsSavedBeforeTheDriveStopKeyKeepTheRest() {
        val old = """{"showOnLockScreen":false,"overTolerance":5,"hasCompletedOnboarding":true}""".toByteArray()
        val s = LimitSettings.decode(old)
        assertFalse(s.showOnLockScreen)
        assertEquals(5, s.overTolerance)
        assertTrue(s.hasCompletedOnboarding)
        assertTrue(s.suggestEndingDrive)
    }

    @Test
    fun badDataGivesDefaults() {
        assertEquals(LimitSettings(), LimitSettings.decode(null))
        assertEquals(LimitSettings(), LimitSettings.decode("garbage".toByteArray()))
    }
}
