package com.joshmcarthur.limit.core

import java.net.URI
import java.nio.file.Files
import java.nio.file.Path
import java.time.Instant
import java.util.concurrent.CancellationException
import kotlin.test.AfterTest
import kotlin.test.BeforeTest
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.fail

private class Source : HttpFetching {
    val requests = mutableListOf<URI>()
    var editedAtMillis: Long? = 1_700_000_000_000
    var layerFails = false
    var records = 1
    var reportedCount: Int? = null

    val pageRequests: Int get() = requests.count { it.toString().contains("resultOffset") }

    override fun data(url: URI): ByteArray {
        requests.add(url)
        val text = url.toString()
        if (text.contains("returnCountOnly")) return """{"count":${reportedCount ?: records}}""".toByteArray()
        if (text.contains("resultOffset")) {
            val features = (0 until records).joinToString(",") { index ->
                """{"type":"Feature","properties":{"speedLimitZoneId":"z$index","speedLimitZoneValue":"50"},
                 "geometry":{"type":"Polygon","coordinates":[[[174,-41],[175,-41],[175,-40],[174,-40],[174,-41]]]}}"""
            }
            return """{"type":"FeatureCollection","properties":{"exceededTransferLimit":false},"features":[$features]}""".toByteArray()
        }
        if (layerFails) throw RegisterSyncError.BadResponse
        val editing = editedAtMillis?.let { "\"editingInfo\":{\"dataLastEditDate\":$it}," } ?: ""
        return "{$editing\"name\":\"layer\"}".toByteArray()
    }
}

class RegisterUpdaterTest {
    private lateinit var directory: Path
    private val weekSeconds = 7 * 86_400L

    @BeforeTest
    fun setUp() {
        directory = Files.createTempDirectory("limit-updater-")
    }

    @AfterTest
    fun tearDown() {
        deleteRecursively(directory)
    }

    private fun updater(
        source: Source,
        at: Instant,
        policy: RegisterVerificationPolicy = RegisterVerificationPolicy(minimumZones = 1),
    ): RegisterUpdater {
        val endpoint = RegisterEndpoint(
            queryURL = URI.create("https://example.test/FeatureServer/0/query"),
            pageSize = 1_000,
        )
        return RegisterUpdater(
            downloader = RegisterDownloader(endpoint = endpoint, fetcher = source),
            store = RegisterStore(directory),
            policy = policy,
            now = { at },
        )
    }

    private fun ran(scheduled: ScheduledUpdate): RegisterUpdateOutcome? = when (scheduled) {
        is ScheduledUpdate.Ran -> scheduled.outcome
        is ScheduledUpdate.NotDue -> null
    }

    private fun liveZoneCount(): Int? = RegisterStore(directory).load()?.register?.zoneCount

    private fun rejection(block: () -> Unit): RegisterRejection? = try {
        block()
        null
    } catch (error: RegisterSyncError.Rejected) {
        error.reason
    } catch (_: Exception) {
        null
    }

    @Test
    fun layerURLIsTheLayerNotTheQuery() {
        val endpoint = RegisterEndpoint(URI.create("https://example.test/FeatureServer/0/query"))
        assertEquals("https://example.test/FeatureServer/0?f=json", endpoint.layerURL().toString())
    }

    @Test
    fun editDateParsing() {
        assertEquals(
            Instant.ofEpochSecond(1_792_637_751),
            SourceEditCheck.editDate("""{"editingInfo":{"dataLastEditDate":1792637751497}}""".toByteArray()),
        )
        assertNull(SourceEditCheck.editDate("""{"name":"x"}""".toByteArray()))
        assertNull(SourceEditCheck.editDate("""{"editingInfo":{}}""".toByteArray()))
        assertNull(SourceEditCheck.editDate("not json".toByteArray()))
    }

    @Test
    fun aSourceDateWithMillisecondsIsStillUnchangedNextTime() {
        val source = Source()
        source.editedAtMillis = 1_700_000_000_497
        updater(source, at = Instant.ofEpochSecond(100)).update()
        val outcome = updater(source, at = Instant.ofEpochSecond(200)).update()
        assertTrue(outcome is RegisterUpdateOutcome.Unchanged)
    }

    @Test
    fun firstRunDownloadsAndRemembersTheSourceEdit() {
        val source = Source()
        val outcome = updater(source, at = Instant.ofEpochSecond(100)).update()
        val downloaded = outcome as? RegisterUpdateOutcome.Downloaded ?: fail("expected a download")
        assertEquals(1, downloaded.zones.size)
        assertEquals(Instant.ofEpochSecond(1_700_000_000), downloaded.metadata.sourceEditedAt)
        assertEquals(downloaded.metadata.sourceEditedAt, RegisterStore(directory).loadMetadata()?.sourceEditedAt)
    }

    @Test
    fun unchangedSourceSkipsTheDownloadButRefreshesTheCheckedDate() {
        val source = Source()
        updater(source, at = Instant.ofEpochSecond(100)).update()
        val pagesAfterFirst = source.pageRequests
        val outcome = updater(source, at = Instant.ofEpochSecond(5_000)).update()
        val unchanged = outcome as? RegisterUpdateOutcome.Unchanged ?: fail("expected no download")
        assertEquals(pagesAfterFirst, source.pageRequests)
        assertEquals(Instant.ofEpochSecond(5_000), unchanged.metadata.checkedAt)
        assertEquals(Instant.ofEpochSecond(5_000), RegisterStore(directory).loadMetadata()?.checkedAt)
        assertEquals(1, RegisterStore(directory).load()?.register?.zoneCount)
    }

    @Test
    fun newerSourceDownloadsAgain() {
        val source = Source()
        updater(source, at = Instant.ofEpochSecond(100)).update()
        source.editedAtMillis = source.editedAtMillis!! + 60_000
        val outcome = updater(source, at = Instant.ofEpochSecond(200)).update()
        val downloaded = outcome as? RegisterUpdateOutcome.Downloaded ?: fail("expected a download")
        assertEquals(Instant.ofEpochSecond(1_700_000_060), downloaded.metadata.sourceEditedAt)
    }

    @Test
    fun unreadableLayerWithACopyDoesNotDownload() {
        val source = Source()
        updater(source, at = Instant.ofEpochSecond(100)).update()
        val pagesBefore = source.pageRequests
        source.layerFails = true
        val error = assertFailsWith<RegisterSyncError> {
            updater(source, at = Instant.ofEpochSecond(200)).update()
        }
        assertEquals(RegisterSyncError.SourceUnavailable, error)
        assertEquals(pagesBefore, source.pageRequests)
        assertEquals(1, liveZoneCount())
    }

    @Test
    fun unreadableLayerWithNoCopyStillDownloads() {
        val source = Source()
        source.layerFails = true
        val outcome = updater(source, at = Instant.ofEpochSecond(100)).update()
        val downloaded = outcome as? RegisterUpdateOutcome.Downloaded ?: fail("expected a download")
        assertNull(downloaded.metadata.sourceEditedAt)
    }

    @Test
    fun aLayerWithNoEditDateDownloadsAgain() {
        val source = Source()
        updater(source, at = Instant.ofEpochSecond(100)).update()
        source.editedAtMillis = null
        val outcome = updater(source, at = Instant.ofEpochSecond(200)).update()
        assertTrue(outcome is RegisterUpdateOutcome.Downloaded)
    }

    @Test
    fun copySavedWithoutASourceEditDownloadsAgain() {
        val source = Source()
        RegisterStore(directory).save(
            zones = emptyList(),
            metadata = RegisterMetadata(checkedAt = Instant.now(), zoneCount = 0, sourceFeatureCount = 0),
        )
        val outcome = updater(source, at = Instant.now()).update()
        assertTrue(outcome is RegisterUpdateOutcome.Downloaded)
    }

    @Test
    fun oldMetadataFilesStillDecode() {
        val generation = directory.resolve("gen-old")
        Files.createDirectories(generation)
        Files.writeString(
            generation.resolve("register.json"),
            """{"checkedAt":"2026-10-01T00:00:00Z","zoneCount":2,"sourceFeatureCount":3}""",
        )
        Files.writeString(directory.resolve("current"), "gen-old")
        val metadata = RegisterStore(directory).loadMetadata() ?: fail("expected metadata")
        assertNull(metadata.sourceEditedAt)
        assertEquals(2, metadata.zoneCount)
    }

    @Test
    fun automaticChecksWaitAWeekAndThenCostOnlyTheLayerRequest() {
        val source = Source()
        val t0 = Instant.ofEpochSecond(1_000_000)
        val first = updater(source, at = t0).updateIfDue()
        assertTrue(ran(first) != null)
        val requestsAfterFirst = source.requests.size
        for (hours in listOf(1.0, 24.0, 100.0, 167.0)) {
            val scheduled = updater(source, at = t0.plusSeconds((hours * 3_600).toLong())).updateIfDue()
            val waiting = scheduled as? ScheduledUpdate.NotDue ?: fail("expected to wait at $hours h")
            assertEquals(t0.plusSeconds(weekSeconds), waiting.until)
        }
        assertEquals(requestsAfterFirst, source.requests.size)
        val weekLater = updater(source, at = t0.plusSeconds(weekSeconds)).updateIfDue()
        val outcome = ran(weekLater) ?: fail("expected a check")
        assertTrue(outcome is RegisterUpdateOutcome.Unchanged)
        assertEquals(requestsAfterFirst + 1, source.requests.size)
        assertEquals(1, source.pageRequests)
    }

    @Test
    fun progressStartsWithNilOnlyWhenTheUpdateActuallyRuns() {
        val source = Source()
        val t0 = Instant.ofEpochSecond(1_000_000)
        val started = mutableListOf<Double?>()
        updater(source, at = t0).updateIfDue { started.add(it) }
        assertNull(started.first())
        val skipped = mutableListOf<Double?>()
        val scheduled = updater(source, at = t0.plusSeconds(60)).updateIfDue { skipped.add(it) }
        assertTrue(scheduled is ScheduledUpdate.NotDue)
        assertTrue(skipped.isEmpty())
    }

    @Test
    fun failuresBackOffAndSurviveARelaunch() {
        val source = Source()
        source.layerFails = true
        source.records = 0
        val t0 = Instant.ofEpochSecond(1_000_000)
        try {
            updater(source, at = t0, policy = RegisterVerificationPolicy.standard).updateIfDue()
        } catch (_: Exception) {
        }
        assertEquals(1, RegisterStore(directory).loadAttempts().consecutiveFailures)
        val requests = source.requests.size
        val waiting = updater(source, at = t0.plusSeconds(60)).updateIfDue() as? ScheduledUpdate.NotDue
            ?: fail("expected to back off")
        assertEquals(t0.plusSeconds(15 * 60), waiting.until)
        assertEquals(requests, source.requests.size)
        try {
            updater(source, at = t0.plusSeconds(15 * 60), policy = RegisterVerificationPolicy.standard).updateIfDue()
        } catch (_: Exception) {
        }
        val second = updater(source, at = t0.plusSeconds(16 * 60)).updateIfDue() as? ScheduledUpdate.NotDue
            ?: fail("expected a longer back-off")
        assertEquals(t0.plusSeconds(15 * 60 + 3_600), second.until)
    }

    @Test
    fun aRejectedDownloadBacksOffLikeAnyOtherFailure() {
        val source = Source()
        source.records = 10
        val t0 = Instant.ofEpochSecond(1_000_000)
        updater(source, at = t0).updateIfDue()
        source.records = 3
        source.editedAtMillis = source.editedAtMillis!! + 60_000
        val t1 = t0.plusSeconds(weekSeconds)
        try {
            updater(source, at = t1).updateIfDue()
        } catch (_: Exception) {
        }
        val pages = source.pageRequests
        val scheduled = updater(source, at = t1.plusSeconds(60)).updateIfDue()
        assertTrue(scheduled is ScheduledUpdate.NotDue)
        assertEquals(pages, source.pageRequests)
    }

    @Test
    fun manualChecksSkipTheWeeklyWaitButNotTheFloor() {
        val source = Source()
        val t0 = Instant.ofEpochSecond(1_000_000)
        updater(source, at = t0).updateIfDue()
        val tooSoon = updater(source, at = t0.plusSeconds(60)).updateIfDue(userInitiated = true)
        val waiting = tooSoon as? ScheduledUpdate.NotDue ?: fail("expected the floor to hold")
        assertEquals(t0.plusSeconds(5 * 60), waiting.until)
        val allowed = updater(source, at = t0.plusSeconds(5 * 60)).updateIfDue(userInitiated = true)
        val outcome = ran(allowed) ?: fail("expected a check")
        assertTrue(outcome is RegisterUpdateOutcome.Unchanged)
    }

    @Test
    fun attemptsSurviveClearingAndStagedWrites() {
        val store = RegisterStore(directory)
        store.saveAttempts(SyncAttempts(lastAttemptAt = Instant.ofEpochSecond(100), consecutiveFailures = 2))
        store.save(zones = emptyList(), metadata = RegisterMetadata(checkedAt = Instant.now(), zoneCount = 0, sourceFeatureCount = 0))
        assertEquals(2, store.loadAttempts().consecutiveFailures)
        store.clear()
        assertEquals(2, store.loadAttempts().consecutiveFailures)
    }

    @Test
    fun aShrunkenSourceDoesNotReplaceTheLiveCopy() {
        val source = Source()
        source.records = 10
        updater(source, at = Instant.ofEpochSecond(100)).update()
        assertEquals(10, liveZoneCount())
        source.records = 3
        source.editedAtMillis = source.editedAtMillis!! + 60_000
        val reason = rejection { updater(source, at = Instant.ofEpochSecond(200)).update() }
        assertEquals(RegisterRejection.MuchSmaller(count = 3, current = 10), reason)
        assertEquals(10, liveZoneCount())
        assertEquals(Instant.ofEpochSecond(100), RegisterStore(directory).loadMetadata()?.checkedAt)
    }

    @Test
    fun anIncompleteDownloadIsRejected() {
        val source = Source()
        source.records = 10
        source.reportedCount = 100
        val reason = rejection { updater(source, at = Instant.now()).update() }
        assertEquals(RegisterRejection.Incomplete(fetched = 10, expected = 100), reason)
        assertNull(liveZoneCount())
    }

    @Test
    fun tooFewZonesIsRejectedEvenWithNothingToReplace() {
        val source = Source()
        source.records = 4
        val reason = rejection { updater(source, at = Instant.now(), policy = RegisterVerificationPolicy.standard).update() }
        assertEquals(RegisterRejection.TooFewZones(count = 4, minimum = 8_000), reason)
        assertNull(liveZoneCount())
    }

    @Test
    fun aRejectedDownloadLeavesNoStrayFolders() {
        val source = Source()
        source.records = 4
        rejection { updater(source, at = Instant.now(), policy = RegisterVerificationPolicy.standard).update() }
        val leftovers = Files.list(directory).use { stream -> stream.map { it.fileName.toString() }.toList() }
        assertTrue(leftovers.none { it.startsWith("gen-") })
    }

    @Test
    fun anUnreportedCountCannotShowIncompleteButTheOtherChecksStillApply() {
        val source = Source()
        source.records = 4
        source.reportedCount = null
        val reason = rejection { updater(source, at = Instant.now(), policy = RegisterVerificationPolicy.standard).update() }
        assertEquals(RegisterRejection.TooFewZones(count = 4, minimum = 8_000), reason)
    }

    @Test
    fun aCancelledDownloadNeverSwaps() {
        val source = Source()
        source.records = 10
        updater(source, at = Instant.ofEpochSecond(100)).update()
        source.records = 12
        source.editedAtMillis = source.editedAtMillis!! + 60_000
        val updating = updater(source, at = Instant.ofEpochSecond(200))
        updating.isCancelled = { true }
        assertFailsWith<CancellationException> { updating.update() }
        assertEquals(10, liveZoneCount())
        val leftovers = Files.list(directory).use { stream ->
            stream.map { it.fileName.toString() }.filter { it.startsWith("gen-") }.toList()
        }
        assertEquals(1, leftovers.size)
    }

    @Test
    fun aRealClockTimeStillPassesTheReadBack() {
        val source = Source()
        source.records = 10
        val outcome = updater(source, at = Instant.ofEpochSecond(100, 987_000_000)).update()
        val downloaded = outcome as? RegisterUpdateOutcome.Downloaded ?: fail("expected a download")
        assertEquals(Instant.ofEpochSecond(100), downloaded.metadata.checkedAt)
    }

    @Test
    fun aGoodDownloadReplacesTheLiveCopy() {
        val source = Source()
        source.records = 10
        updater(source, at = Instant.ofEpochSecond(100)).update()
        source.records = 9
        source.editedAtMillis = source.editedAtMillis!! + 60_000
        updater(source, at = Instant.ofEpochSecond(200)).update()
        assertEquals(9, liveZoneCount())
    }

    private fun deleteRecursively(path: Path) {
        if (!Files.exists(path)) return
        if (Files.isDirectory(path)) {
            Files.list(path).use { stream -> stream.forEach { deleteRecursively(it) } }
        }
        Files.deleteIfExists(path)
    }
}
