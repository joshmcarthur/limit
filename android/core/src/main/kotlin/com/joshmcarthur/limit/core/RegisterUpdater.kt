package com.joshmcarthur.limit.core

import java.time.Instant
import java.util.concurrent.CancellationException
import kotlin.math.floor
import org.json.JSONObject

/** Learns when the source layer's data last changed, without downloading any of it. */
class SourceEditCheck(
    val endpoint: RegisterEndpoint = RegisterEndpoint.nzta,
    val fetcher: HttpFetching = HttpURLConnectionFetcher(),
) {
    sealed class Result {
        data class Edited(val date: Instant) : Result()

        /** The layer answered but doesn't say when it last changed. */
        data object Undated : Result()

        /** The layer couldn't be read. */
        data object Unreachable : Result()
    }

    fun check(): Result {
        val data = try {
            fetcher.data(endpoint.layerURL())
        } catch (_: Exception) {
            return Result.Unreachable
        }
        val edited = editDate(data) ?: return Result.Undated
        return Result.Edited(edited)
    }

    companion object {
        /**
         * `editingInfo.dataLastEditDate` is milliseconds since 1970. Kept to whole seconds, because the stored
         * metadata drops the fraction.
         */
        fun editDate(data: ByteArray): Instant? {
            val layer = try {
                JSONObject(String(data, Charsets.UTF_8))
            } catch (_: Exception) {
                return null
            }
            val info = layer.optJSONObject("editingInfo") ?: return null
            if (!info.has("dataLastEditDate") || info.isNull("dataLastEditDate")) return null
            val millis = (info.get("dataLastEditDate") as? Number)?.toDouble() ?: return null
            if (millis <= 0.0) return null
            return Instant.ofEpochSecond(floor(millis / 1000.0).toLong())
        }
    }
}

sealed class RegisterUpdateOutcome {
    /** The source hasn't changed since the stored copy, so nothing was downloaded. */
    data class Unchanged(val metadata: RegisterMetadata) : RegisterUpdateOutcome()
    data class Downloaded(val zones: List<SpeedZone>, val metadata: RegisterMetadata) : RegisterUpdateOutcome()
}

sealed class ScheduledUpdate {
    /** The schedule says it's too soon; no request was made. */
    data class NotDue(val until: Instant) : ScheduledUpdate()
    data class Ran(val outcome: RegisterUpdateOutcome) : ScheduledUpdate()
}

/** Brings the stored register up to date: a cheap check first, a full download only when the source changed. */
class RegisterUpdater(
    val downloader: RegisterDownloader = RegisterDownloader(),
    val store: RegisterStore,
    val policy: RegisterVerificationPolicy = RegisterVerificationPolicy.standard,
    val schedule: SyncSchedule = SyncSchedule.standard,
    val now: () -> Instant = { Instant.now() },
) {
    var isCancelled: () -> Boolean = { false }

    /**
     * Updates only if the schedule allows it. Reports progress null as soon as it commits to running.
     */
    fun updateIfDue(userInitiated: Boolean = false, progress: (Double?) -> Unit = {}): ScheduledUpdate {
        when (val decision = decision(userInitiated)) {
            is SyncSchedule.Decision.Wait -> return ScheduledUpdate.NotDue(decision.until)
            SyncSchedule.Decision.Now -> Unit
        }
        progress(null)
        return ScheduledUpdate.Ran(update(progress))
    }

    /** Updates now, whatever the schedule says, and records the attempt so the schedule can see it. */
    fun update(progress: (Double?) -> Unit = {}): RegisterUpdateOutcome {
        val attempts = store.loadAttempts()
        attempts.lastAttemptAt = now()
        attempts.consecutiveFailures += 1
        store.saveAttempts(attempts)
        val outcome = perform(progress)
        attempts.consecutiveFailures = 0
        store.saveAttempts(attempts)
        return outcome
    }

    private fun decision(userInitiated: Boolean): SyncSchedule.Decision {
        val checkedAt = try {
            store.loadMetadata()?.checkedAt
        } catch (_: Exception) {
            null
        }
        return schedule.decision(
            attempts = store.loadAttempts(),
            lastSuccessAt = checkedAt,
            now = now(),
            userInitiated = userInitiated,
        )
    }

    private fun perform(progress: (Double?) -> Unit): RegisterUpdateOutcome {
        downloader.isCancelled = isCancelled
        val check = SourceEditCheck(endpoint = downloader.endpoint, fetcher = downloader.fetcher).check()
        val stored = try {
            store.loadMetadata()
        } catch (_: Exception) {
            null
        }
        val latest = when (check) {
            is SourceEditCheck.Result.Edited -> check.date
            SourceEditCheck.Result.Undated -> null
            SourceEditCheck.Result.Unreachable -> {
                if (stored != null) throw RegisterSyncError.SourceUnavailable
                null
            }
        }
        val storedEdit = stored?.sourceEditedAt
        if (stored != null && storedEdit != null && latest != null && latest <= storedEdit) {
            val checked = now()
            store.updateCheckedAt(checked)
            return RegisterUpdateOutcome.Unchanged(stored.copy(checkedAt = checked))
        }

        val downloaded = downloader.download(progress)
        if (isCancelled() || Thread.currentThread().isInterrupted) throw CancellationException()
        val current = try {
            store.loadMetadata()
        } catch (_: Exception) {
            null
        }
        val rejection = RegisterVerifier.check(downloaded, current, policy)
        if (rejection != null) throw RegisterSyncError.Rejected(rejection)
        val metadata = RegisterMetadata(
            checkedAt = now(),
            zoneCount = downloaded.zones.size,
            sourceFeatureCount = downloaded.sourceFeatureCount,
            sourceEditedAt = latest,
        )
        val staged = store.stage(zones = downloaded.zones, metadata = metadata)
        if (!store.verifyWritten(staged)) {
            store.discard(staged)
            throw RegisterSyncError.Rejected(RegisterRejection.WriteMismatch)
        }
        if (isCancelled() || Thread.currentThread().isInterrupted) {
            store.discard(staged)
            throw CancellationException()
        }
        store.commit(staged)
        return RegisterUpdateOutcome.Downloaded(zones = downloaded.zones, metadata = staged.metadata)
    }
}
