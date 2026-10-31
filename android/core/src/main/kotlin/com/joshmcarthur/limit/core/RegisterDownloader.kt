package com.joshmcarthur.limit.core

import java.net.HttpURLConnection
import java.net.URI
import java.net.URLEncoder
import java.time.Instant
import java.time.ZoneOffset
import java.time.format.DateTimeFormatter
import java.util.concurrent.CancellationException
import java.util.zip.GZIPInputStream
import kotlin.math.pow
import org.json.JSONObject

sealed class RegisterSyncError : Exception() {
    data object BadResponse : RegisterSyncError()

    /** The source said it is busy or limiting us (429 or 503). The sync stops rather than trying again. */
    data object SourceBusy : RegisterSyncError()

    /** The source refused the request (another 4xx). Asking again won't change the answer. */
    data class RequestRefused(val status: Int) : RegisterSyncError()

    /** The source can't be reached to see whether anything changed, so nothing was downloaded. */
    data object SourceUnavailable : RegisterSyncError()

    /** The source returned features but none carried a usable limit. */
    data class NoLimitsInSource(val featureCount: Int) : RegisterSyncError()

    data object EmptySource : RegisterSyncError()

    /** The download finished but failed a check, so the register in use was kept. */
    data class Rejected(val reason: RegisterRejection) : RegisterSyncError()
}

fun interface HttpFetching {
    fun data(url: URI): ByteArray
}

class HttpURLConnectionFetcher(
    private val userAgent: String = LimitCore.userAgent(),
) : HttpFetching {
    override fun data(url: URI): ByteArray {
        val connection = url.toURL().openConnection() as HttpURLConnection
        connection.setRequestProperty("User-Agent", userAgent)
        connection.setRequestProperty("Accept-Encoding", "gzip")
        connection.connectTimeout = 30_000
        connection.readTimeout = 60_000
        try {
            val status = connection.responseCode
            if (status !in 200..299) throw errorForStatus(status)
            val raw = connection.inputStream.readBytes()
            val encoding = connection.contentEncoding
            return if (encoding != null && encoding.contains("gzip", ignoreCase = true)) {
                GZIPInputStream(raw.inputStream()).readBytes()
            } else {
                raw
            }
        } finally {
            connection.disconnect()
        }
    }

    companion object {
        fun errorForStatus(status: Int): RegisterSyncError = when (status) {
            429, 503 -> RegisterSyncError.SourceBusy
            in 400..499 -> RegisterSyncError.RequestRefused(status)
            else -> RegisterSyncError.BadResponse
        }
    }
}

/** The ArcGIS feature service query endpoint for the register. */
data class RegisterEndpoint(
    val queryURL: URI,
    val pageSize: Int = 2_000,
) {
    fun pageURL(offset: Int, now: Instant = Instant.now()): URI = url(
        listOf(
            "where" to inForce(now),
            "outFields" to outFields.joinToString(","),
            "returnGeometry" to "true",
            "outSR" to "4326",
            "geometryPrecision" to "6",
            "orderByFields" to "OBJECTID",
            "resultOffset" to offset.toString(),
            "resultRecordCount" to pageSize.toString(),
            "f" to "pgeojson",
        ),
    )

    /** The layer's description. It carries when the data last changed. */
    fun layerURL(): URI {
        val parent = queryURL.path.substringBeforeLast("/")
        return URI.create("${queryURL.scheme}://${queryURL.rawAuthority}$parent?f=json")
    }

    fun countURL(now: Instant = Instant.now()): URI = url(
        listOf(
            "where" to inForce(now),
            "returnCountOnly" to "true",
            "f" to "json",
        ),
    )

    private fun url(items: List<Pair<String, String>>): URI {
        val query = items.joinToString("&") { (name, value) -> "${form(name)}=${form(value)}" }
        return URI.create("${queryURL.scheme}://${queryURL.rawAuthority}${queryURL.path}?$query")
    }

    companion object {
        /** NZTA's speed limit zone layer. */
        val nzta: RegisterEndpoint = RegisterEndpoint(
            URI.create(
                "https://services.arcgis.com/CXBb7LAjgIIdcsPt/ArcGIS/rest/services/SpeedLimitZoneFull__View/FeatureServer/0/query",
            ),
        )

        /**
         * The layer also holds superseded and expired records. The cut-off is two days back so a record that
         * ended today or yesterday still arrives; lookups check the dates themselves.
         */
        fun inForce(now: Instant = Instant.now()): String {
            val day = now.atZone(ZoneOffset.UTC).toLocalDate().minusDays(2).format(DateTimeFormatter.ISO_LOCAL_DATE)
            return "(whenIneffective IS NULL OR whenIneffective < TIMESTAMP '1901-01-01 00:00:00' " +
                "OR whenIneffective >= TIMESTAMP '$day 00:00:00') AND (speedLimitZoneEndDate IS NULL " +
                "OR speedLimitZoneEndDate >= TIMESTAMP '$day 00:00:00' OR speedLimitZoneSeasonalRecur = 1)"
        }

        /** Only the fields the app reads; the layer's legal text fields are large. */
        val outFields: List<String> = listOf(
            "speedLimitZoneId",
            "speedLimitZoneName",
            "speedLimitZoneValue",
            "speedLimitZoneVariableSpeed",
            "speedLimitZoneVarPrdDesc",
            "speedCategoryName",
            "speedLimitZoneStartDate",
            "speedLimitZoneEndDate",
            "speedLimitZoneSeasonalRecur",
            "speedLimitZoneStructureTypeName",
        )

        private fun form(value: String): String =
            URLEncoder.encode(value, Charsets.UTF_8).replace("+", "%20")
    }
}

/** Downloads every page of the register. Progress is 0...1, or null if the total couldn't be learned. */
class RegisterDownloader(
    val endpoint: RegisterEndpoint = RegisterEndpoint.nzta,
    val fetcher: HttpFetching = HttpURLConnectionFetcher(),
) {
    /** Extra attempts per request after the first. Each waits four times as long as the last (1 s, 4 s). */
    var retries: Int = 2
    var sleep: (Double) -> Unit = { seconds ->
        if (seconds > 0) Thread.sleep((seconds * 1000).toLong())
    }
    var isCancelled: () -> Boolean = { false }

    private val maxPages = 5_000

    fun download(progress: (Double?) -> Unit = {}): DownloadedRegister {
        val total = totalCount()
        progress(if (total == null) null else 0.0)

        val zones = mutableListOf<SpeedZone>()
        var fetched = 0
        var offset = 0
        var pageIndex = 0
        while (pageIndex < maxPages) {
            checkCancellation()
            val data = fetch(endpoint.pageURL(offset))
            val page = try {
                GeoJSONZoneParser.parse(data)
            } catch (_: Exception) {
                throw RegisterSyncError.BadResponse
            }
            if (offset == 0 && page.featureCount > 0 && page.zones.isEmpty() && page.skippedWithoutLimit == page.featureCount) {
                throw RegisterSyncError.NoLimitsInSource(featureCount = page.featureCount)
            }
            zones += page.zones
            fetched += page.featureCount
            offset += page.featureCount
            if (total != null && total > 0) {
                progress(minOf(fetched.toDouble() / total.toDouble(), 1.0))
            } else {
                progress(null)
            }
            if (page.featureCount == 0 || (!page.exceededTransferLimit && page.featureCount < endpoint.pageSize)) break
            pageIndex += 1
        }

        if (fetched == 0) throw RegisterSyncError.EmptySource
        if (zones.isEmpty()) throw RegisterSyncError.NoLimitsInSource(featureCount = fetched)
        checkCancellation()
        progress(1.0)
        return DownloadedRegister(
            zones = ZoneDeduplicator.unique(zones),
            sourceFeatureCount = fetched,
            expectedFeatureCount = total,
        )
    }

    private fun totalCount(): Int? {
        val data = try {
            fetch(endpoint.countURL())
        } catch (error: Exception) {
            if (isFinal(error)) throw error
            return null
        }
        return try {
            val json = JSONObject(String(data, Charsets.UTF_8))
            if (!json.has("count") || json.isNull("count")) null else json.getInt("count")
        } catch (_: Exception) {
            null
        }
    }

    private fun fetch(url: URI): ByteArray {
        var attempt = 0
        while (true) {
            try {
                return fetcher.data(url)
            } catch (error: Exception) {
                if (attempt >= retries || isFinal(error)) throw error
                sleep(4.0.pow(attempt.toDouble()))
                attempt += 1
            }
        }
    }

    private fun checkCancellation() {
        if (isCancelled()) throw CancellationException()
    }

    private fun isFinal(error: Throwable): Boolean = when (error) {
        is RegisterSyncError.SourceBusy, is RegisterSyncError.RequestRefused -> true
        is CancellationException -> true
        else -> false
    }
}
