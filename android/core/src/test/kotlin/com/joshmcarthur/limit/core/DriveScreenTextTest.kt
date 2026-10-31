package com.joshmcarthur.limit.core

import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

class DriveScreenTextTest {
    private val withLimit = DriveSnapshot(sign = SignState.Limit(50, isStale = false), roadName = "Cuba Street")
    private val limitNoName = DriveSnapshot(sign = SignState.Limit(50, isStale = false))
    private val noLimit = DriveSnapshot.searching

    private fun text(
        snapshot: DriveSnapshot,
        driving: Boolean = true,
        access: LocationAccess = LocationAccess.authorized,
    ): Pair<String, String?> = Pair(
        DriveScreenText.headline(isDriving = driving, access = access, snapshot = snapshot),
        DriveScreenText.subheadline(isDriving = driving, access = access, snapshot = snapshot),
    )

    @Test
    fun onlyAuthorizedAccessIsUsable() {
        assertTrue(LocationAccess.authorized.isUsable)
        for (access in listOf(LocationAccess.notDetermined, LocationAccess.denied, LocationAccess.reduced)) {
            assertFalse(access.isUsable)
        }
    }

    @Test
    fun anEndedDriveWithAccessSaysSo() {
        val (headline, subheadline) = text(withLimit, driving = false, access = LocationAccess.authorized)
        assertEquals("Drive ended", headline)
        assertEquals("Location and the Lock Screen card are off.", subheadline)
    }

    @Test
    fun withoutUsableAccessItSaysWhatToDoAndNeverShowsARoad() {
        val cases = listOf(
            LocationAccess.denied to "Turn on location for Limit in Settings",
            LocationAccess.reduced to "Turn on Precise Location so Limit can find your road",
            LocationAccess.notDetermined to "Allow location to see the limit",
        )
        for ((access, advice) in cases) {
            for (driving in listOf(true, false)) {
                val (headline, subheadline) = text(withLimit, driving = driving, access = access)
                assertEquals("Location needed", headline)
                assertEquals(advice, subheadline)
            }
        }
    }

    @Test
    fun withAccessItNamesTheRoadAndNothingElse() {
        val (headline, subheadline) = text(withLimit)
        assertEquals("Cuba Street", headline)
        assertNull(subheadline)
    }

    @Test
    fun aLimitWithNoRoadNameIsStillAnnounced() {
        assertEquals("Speed limit", text(limitNoName).first)
    }

    @Test
    fun withNoLimitYetItSaysSoAndPointsAtTheSigns() {
        val (headline, subheadline) = text(noLimit)
        assertEquals("Finding your road…", headline)
        assertEquals("Obey the posted speed limit signs", subheadline)
    }

    @Test
    fun outsideNewZealandSaysSoInsteadOfLookingForever() {
        val outside = DriveSnapshot(roadName = "Outside New Zealand", isOutsideNewZealand = true)
        val (headline, subheadline) = text(outside)
        assertEquals("Outside New Zealand", headline)
        assertEquals("Limit only has New Zealand speed limits. Your speed is still shown.", subheadline)
    }
}
