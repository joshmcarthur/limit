package com.joshmcarthur.limit.core

import java.time.Duration
import kotlin.test.Test
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class LiveActivityRefreshTest {
    @Test
    fun aChangeIsSentAtOnce() {
        assertTrue(LiveActivityRefresh.shouldSend(changed = true, secondsSinceLastSend = Duration.ZERO))
    }

    @Test
    fun unchangedContentIsResentBeforeItGoesStale() {
        assertFalse(LiveActivityRefresh.shouldSend(changed = false, secondsSinceLastSend = Duration.ofSeconds(1)))
        assertFalse(LiveActivityRefresh.shouldSend(changed = false, secondsSinceLastSend = Duration.ofMillis(2900)))
        assertTrue(LiveActivityRefresh.shouldSend(changed = false, secondsSinceLastSend = Duration.ofSeconds(3)))
    }

    @Test
    fun theHeartbeatBeatsTheDimAndStaleTimes() {
        assertTrue(LiveActivityRefresh.heartbeat < LiveActivityRefresh.dimAfter)
    }

    @Test
    fun nothingSentYetMeansSend() {
        assertTrue(LiveActivityRefresh.shouldSend(changed = false, secondsSinceLastSend = null))
    }
}
