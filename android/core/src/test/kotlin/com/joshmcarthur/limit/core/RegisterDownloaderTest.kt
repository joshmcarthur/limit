package com.joshmcarthur.limit.core

import java.io.IOException
import java.net.URI
import java.net.URLDecoder
import java.time.Instant
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFailsWith
import kotlin.test.assertNull
import kotlin.test.assertTrue
import kotlin.test.fail

class RegisterDownloaderTest {
    private val square = "[[[174,-41],[175,-41],[175,-40],[174,-40],[174,-41]]]"

    private fun feature(limit: Int?, name: String = "X"): String {
        val limitProp = if (limit == null) "" else ",\"speedLimitZoneValue\":$limit"
        return """{"type":"Feature","properties":{"speedLimitZoneName":"$name"$limitProp},"geometry":{"type":"Polygon","coordinates":$square}}"""
    }

    private fun page(features: List<String>, exceeded: Boolean): ByteArray =
        """{"type":"FeatureCollection","properties":{"exceededTransferLimit":$exceeded},"features":[${features.joinToString(",")}]}"""
            .toByteArray()

    private fun items(uri: URI): Map<String, String> {
        val query = uri.rawQuery ?: return emptyMap()
        return query.split("&").associate { part ->
            val bits = part.split("=", limit = 2)
            URLDecoder.decode(bits[0], Charsets.UTF_8) to URLDecoder.decode(bits.getOrElse(1) { "" }, Charsets.UTF_8)
        }
    }

    private fun offset(uri: URI): Int = items(uri)["resultOffset"]?.toIntOrNull() ?: -1

    private fun isCount(uri: URI): Boolean = items(uri).containsKey("returnCountOnly")

    private val endpoint = RegisterEndpoint(queryURL = URI.create("https://example.test/query"), pageSize = 2)

    @Test
    fun endpointURLs() {
        val now = Instant.parse("2026-10-22T05:00:00Z")
        val url = endpoint.pageURL(offset = 4, now = now)
        val query = items(url)
        assertEquals("4", query["resultOffset"])
        assertEquals("2", query["resultRecordCount"])
        assertEquals("pgeojson", query["f"])
        assertEquals(RegisterEndpoint.inForce(now), query["where"])
        val where = query["where"] ?: fail("missing where")
        assertTrue(where.startsWith("(whenIneffective IS NULL "))
        assertTrue(where.contains("whenIneffective < TIMESTAMP '1901-01-01 00:00:00'"))
        assertTrue(where.contains("whenIneffective >= TIMESTAMP '2026-10-20 00:00:00'"))
        assertTrue(where.contains("speedLimitZoneEndDate >= TIMESTAMP '2026-10-20 00:00:00'"))
        assertTrue(where.contains("speedLimitZoneSeasonalRecur = 1"))
        assertEquals("OBJECTID", query["orderByFields"])
        assertEquals(
            "speedLimitZoneId,speedLimitZoneName,speedLimitZoneValue,speedLimitZoneVariableSpeed,speedLimitZoneVarPrdDesc," +
                "speedCategoryName,speedLimitZoneStartDate,speedLimitZoneEndDate,speedLimitZoneSeasonalRecur,speedLimitZoneStructureTypeName",
            query["outFields"],
        )
        assertEquals("4326", query["outSR"])
        val count = items(endpoint.countURL(now))
        assertEquals("true", count["returnCountOnly"])
        assertEquals(RegisterEndpoint.inForce(now), count["where"])
    }

    @Test
    fun repeatedRecordsAreDroppedFromTheDownload() {
        val repeated =
            """{"type":"Feature","properties":{"speedLimitZoneId":"z1","speedLimitZoneValue":"30"},"geometry":{"type":"Polygon","coordinates":$square}}"""
        val fetcher = HttpFetching { url ->
            if (isCount(url)) """{"count":3}""".toByteArray() else page(listOf(repeated, repeated, repeated), exceeded = false)
        }
        val wide = RegisterEndpoint(queryURL = endpoint.queryURL, pageSize = 10)
        val result = RegisterDownloader(endpoint = wide, fetcher = fetcher).download()
        assertEquals(1, result.zones.size)
        assertEquals(3, result.sourceFeatureCount)
    }

    @Test
    fun pagesUntilTheSourceStopsExceeding() {
        val fetcher = HttpFetching { url ->
            if (isCount(url)) {
                """{"count":5}""".toByteArray()
            } else {
                when (offset(url)) {
                    0 -> page(listOf(feature(50), feature(60)), exceeded = true)
                    2 -> page(listOf(feature(30), feature(40)), exceeded = true)
                    4 -> page(listOf(feature(100)), exceeded = false)
                    else -> {
                        fail("unexpected offset")
                    }
                }
            }
        }
        val recorder = mutableListOf<Double?>()
        val result = RegisterDownloader(endpoint = endpoint, fetcher = fetcher).download { recorder.add(it) }
        assertEquals(listOf(50, 60, 30, 40, 100), result.zones.map { it.limit })
        assertEquals(5, result.sourceFeatureCount)
        assertEquals(1.0, recorder.last())
        assertEquals(0.0, recorder.first())
    }

    @Test
    fun progressIsNilWhenCountUnavailable() {
        val fetcher = HttpFetching { url ->
            if (isCount(url)) throw IOException("offline")
            page(listOf(feature(50)), exceeded = false)
        }
        val downloader = RegisterDownloader(endpoint = endpoint, fetcher = fetcher)
        downloader.retries = 0
        val recorder = mutableListOf<Double?>()
        downloader.download { recorder.add(it) }
        assertNull(recorder.first())
    }

    @Test
    fun sourceWithoutLimitsFailsFastAndHonestly() {
        val fetcher = HttpFetching { url ->
            if (isCount(url)) {
                """{"count":99999}""".toByteArray()
            } else {
                assertEquals(0, offset(url))
                page(listOf(feature(null), feature(null)), exceeded = true)
            }
        }
        val error = assertFailsWith<RegisterSyncError.NoLimitsInSource> {
            RegisterDownloader(endpoint = endpoint, fetcher = fetcher).download()
        }
        assertEquals(2, error.featureCount)
    }

    @Test
    fun emptySource() {
        val fetcher = HttpFetching { url ->
            if (isCount(url)) """{"count":0}""".toByteArray() else page(emptyList(), exceeded = false)
        }
        assertFailsWith<RegisterSyncError.EmptySource> {
            RegisterDownloader(endpoint = endpoint, fetcher = fetcher).download()
        }
    }

    @Test
    fun arcGISErrorBodyIsABadResponse() {
        val fetcher = HttpFetching {
            """{"error":{"code":400,"message":"Invalid"}}""".toByteArray()
        }
        assertFailsWith<RegisterSyncError.BadResponse> {
            RegisterDownloader(endpoint = endpoint, fetcher = fetcher).download()
        }
    }

    @Test
    fun retriesTransientFailuresWithGrowingDelays() {
        var calls = 0
        val delays = mutableListOf<Double>()
        val fetcher = HttpFetching { url ->
            if (isCount(url)) {
                """{"count":1}""".toByteArray()
            } else {
                calls += 1
                if (calls < 3) throw IOException("timed out")
                page(listOf(feature(50)), exceeded = false)
            }
        }
        val wide = RegisterEndpoint(queryURL = endpoint.queryURL, pageSize = 10)
        val downloader = RegisterDownloader(endpoint = wide, fetcher = fetcher)
        downloader.sleep = { delays.add(it) }
        val result = downloader.download()
        assertEquals(1, result.zones.size)
        assertEquals(3, calls)
        assertEquals(listOf(1.0, 4.0), delays)
    }

    @Test
    fun aBusyOrRefusingSourceIsNeverRetried() {
        val failures = listOf(RegisterSyncError.SourceBusy, RegisterSyncError.RequestRefused(403))
        for (failure in failures) {
            var calls = 0
            val delays = mutableListOf<Double>()
            val fetcher = HttpFetching {
                calls += 1
                throw failure
            }
            val downloader = RegisterDownloader(endpoint = endpoint, fetcher = fetcher)
            downloader.sleep = { delays.add(it) }
            val error = assertFailsWith<RegisterSyncError> { downloader.download() }
            assertEquals(failure, error)
            assertEquals(1, calls)
            assertTrue(delays.isEmpty())
        }
    }

    @Test
    fun aBusySourceOnTheCountRequestStopsTheSync() {
        var calls = 0
        val fetcher = HttpFetching { url ->
            calls += 1
            if (isCount(url)) throw RegisterSyncError.SourceBusy
            page(listOf(feature(50)), exceeded = false)
        }
        val error = assertFailsWith<RegisterSyncError> {
            RegisterDownloader(endpoint = endpoint, fetcher = fetcher).download()
        }
        assertEquals(RegisterSyncError.SourceBusy, error)
        assertEquals(1, calls)
    }

    @Test
    fun statusCodesMapToErrors() {
        assertEquals(RegisterSyncError.SourceBusy, HttpURLConnectionFetcher.errorForStatus(429))
        assertEquals(RegisterSyncError.SourceBusy, HttpURLConnectionFetcher.errorForStatus(503))
        assertEquals(RegisterSyncError.RequestRefused(403), HttpURLConnectionFetcher.errorForStatus(403))
        assertEquals(RegisterSyncError.BadResponse, HttpURLConnectionFetcher.errorForStatus(500))
    }

    @Test
    fun userAgentNamesTheApp() {
        val agent = LimitCore.userAgent()
        assertTrue(agent.startsWith("Limit-Android/"))
        assertTrue(agent.contains("github.com/joshmcarthur/limit"))
    }
}
