package com.joshmcarthur.limit

import android.app.Application
import android.content.Context
import android.content.Intent
import android.os.Build
import androidx.core.content.ContextCompat
import com.joshmcarthur.limit.core.DriveEngine
import com.joshmcarthur.limit.core.DriveState
import com.joshmcarthur.limit.core.DriveStopDetector
import com.joshmcarthur.limit.core.HttpURLConnectionFetcher
import com.joshmcarthur.limit.core.LimitCore
import com.joshmcarthur.limit.core.LimitSettings
import com.joshmcarthur.limit.core.LocationAccess
import com.joshmcarthur.limit.core.LocationSample
import com.joshmcarthur.limit.core.RegisterDownloader
import com.joshmcarthur.limit.core.RegisterStore
import com.joshmcarthur.limit.core.RegisterUpdateOutcome
import com.joshmcarthur.limit.core.RegisterUpdater
import com.joshmcarthur.limit.core.ScheduledUpdate
import com.joshmcarthur.limit.core.SpeedLimitRegister
import com.joshmcarthur.limit.core.SyncState
import com.joshmcarthur.limit.core.SyncStatus
import com.joshmcarthur.limit.notification.DriveForegroundService
import com.joshmcarthur.limit.widget.DriveWidget
import java.time.Instant
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

class DriveModel(private val app: Application) {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private val prefs = app.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
    private val store = RegisterStore(app.filesDir.toPath().resolve("Register"))
    private val engine = DriveEngine()
    private val location = LocationService(app)
    private var stopDetector = DriveStopDetector()
    private val sync = SyncStatus()
    private var ticker: Job? = null
    private var syncJob: Job? = null

    private val _settings = MutableStateFlow(LimitSettings.decode(prefs.getString(SETTINGS_KEY, null)?.toByteArray()))
    val settings: StateFlow<LimitSettings> = _settings

    private val _driveState = MutableStateFlow(DriveState.searching)
    val driveState: StateFlow<DriveState> = _driveState

    private val _isDriving = MutableStateFlow(false)
    val isDriving: StateFlow<Boolean> = _isDriving

    private val _locationAccess = MutableStateFlow(currentAccess())
    val locationAccess: StateFlow<LocationAccess> = _locationAccess

    private val _syncState = MutableStateFlow(sync.state(Instant.now()))
    val syncState: StateFlow<SyncState> = _syncState

    private val _snackbar = MutableStateFlow<String?>(null)
    val snackbar: StateFlow<String?> = _snackbar

    private val _notificationsGranted = MutableStateFlow(notificationAccess())
    val notificationsGranted: StateFlow<Boolean> = _notificationsGranted

    private val _notificationsPrompted = MutableStateFlow(prefs.getBoolean(NOTIFICATIONS_PROMPTED, false))
    val notificationsPrompted: StateFlow<Boolean> = _notificationsPrompted

    init {
        engine.evaluator.setTolerance(_settings.value.overTolerance)
        location.onSample = { sample -> handle(sample) }
        location.onAccessChange = { _locationAccess.value = it }
        loadStoredRegister()
        refreshAccess()
        syncRegister()
    }

    val hasCompletedOnboarding: Boolean get() = _settings.value.hasCompletedOnboarding

    fun refreshAccess() {
        _locationAccess.value = currentAccess()
        _notificationsGranted.value = notificationAccess()
    }

    fun markLocationPrompted() {
        prefs.edit().putBoolean(LOCATION_PROMPTED, true).apply()
        refreshAccess()
    }

    fun markNotificationsPrompted() {
        prefs.edit().putBoolean(NOTIFICATIONS_PROMPTED, true).apply()
        _notificationsPrompted.value = true
        refreshAccess()
    }

    /** Refresh permission state and ask the register schedule whether a check is due. */
    fun onForeground() {
        refreshAccess()
        syncRegister()
    }

    fun updateSettings(transform: (LimitSettings) -> LimitSettings) {
        val next = transform(_settings.value)
        _settings.value = next
        prefs.edit().putString(SETTINGS_KEY, next.encoded().toString(Charsets.UTF_8)).apply()
        engine.evaluator.setTolerance(next.overTolerance)
        if (!next.showOnLockScreen && _isDriving.value) {
            // Notification stays required for the FGS; the setting only hides promoted/lock treatment in copy.
        }
    }

    fun finishOnboarding() {
        updateSettings { it.copy(hasCompletedOnboarding = true) }
        syncRegister()
    }

    fun beginDrive() {
        if (_isDriving.value) return
        if (!_locationAccess.value.isUsable) return
        _isDriving.value = true
        prefs.edit().putBoolean(ENDED_BY_DRIVER, false).apply()
        stopDetector = DriveStopDetector()
        location.start()
        ContextCompat.startForegroundService(app, Intent(app, DriveForegroundService::class.java).apply {
            action = DriveForegroundService.ACTION_START
        })
        ticker = scope.launch {
            while (isActive) {
                delay(1_000)
                refresh()
            }
        }
        scope.launch { DriveWidget.refresh(app) }
    }

    fun endDrive(byDriver: Boolean) {
        if (!_isDriving.value) return
        _isDriving.value = false
        prefs.edit().putBoolean(ENDED_BY_DRIVER, byDriver).apply()
        ticker?.cancel()
        ticker = null
        location.stop()
        engine.state(Instant.EPOCH)
        _driveState.value = DriveState.searching
        app.stopService(Intent(app, DriveForegroundService::class.java))
        scope.launch { DriveWidget.refresh(app) }
    }

    fun keepDriving() {
        stopDetector.keepDriving(Instant.now())
    }

    fun consumeSnackbar() {
        _snackbar.value = null
    }

    fun syncRegister(userInitiated: Boolean = false) {
        if (syncJob != null) return
        val updater = RegisterUpdater(
            downloader = RegisterDownloader(
                fetcher = HttpURLConnectionFetcher(LimitCore.userAgent(BuildConfig.VERSION_NAME)),
            ),
            store = store,
        )
        syncJob = scope.launch {
            try {
                val result = withContext(Dispatchers.IO) {
                    updater.updateIfDue(userInitiated) { progress ->
                        scope.launch {
                            sync.progressed(progress)
                            publishSync()
                        }
                    }
                }
                when (result) {
                    is ScheduledUpdate.NotDue -> Unit
                    is ScheduledUpdate.Ran -> when (val outcome = result.outcome) {
                        is RegisterUpdateOutcome.Unchanged -> {
                            engine.registerCheckedAt = outcome.metadata.checkedAt
                            sync.finished(outcome.metadata.checkedAt)
                        }
                        is RegisterUpdateOutcome.Downloaded -> {
                            engine.register = SpeedLimitRegister(outcome.zones)
                            engine.registerCheckedAt = outcome.metadata.checkedAt
                            sync.finished(outcome.metadata.checkedAt)
                            _snackbar.value = "Speed limits updated"
                        }
                    }
                }
            } catch (cancelled: kotlinx.coroutines.CancellationException) {
                throw cancelled
            } catch (_: Throwable) {
                sync.failed()
            } finally {
                publishSync()
                syncJob = null
            }
        }
    }

    fun retrySync() = syncRegister(userInitiated = true)

    private fun handle(sample: LocationSample) {
        if (!_isDriving.value) return
        apply(engine.ingest(sample))
    }

    private fun refresh() {
        if (!_isDriving.value) return
        apply(engine.state())
        evaluateStop()
    }

    private fun apply(state: DriveState) {
        _driveState.value = state
        stopDetector.observe(speedKmh = state.snapshot.speed, at = Instant.now())
        DriveForegroundService.update(app, state.snapshot, _settings.value.showOnLockScreen)
        scope.launch { DriveWidget.refresh(app) }
    }

    private fun evaluateStop() {
        if (!_settings.value.suggestEndingDrive) return
        when (stopDetector.evaluate(Instant.now())) {
            DriveStopDetector.Action.none -> Unit
            DriveStopDetector.Action.ping -> DriveForegroundService.pingStopped(app)
            DriveStopDetector.Action.end -> endDrive(byDriver = false)
        }
    }

    private fun loadStoredRegister() {
        try {
            val stored = store.load() ?: return
            engine.register = stored.register
            engine.registerCheckedAt = stored.metadata.checkedAt
            sync.finished(stored.metadata.checkedAt)
            publishSync()
        } catch (_: Exception) {
            try {
                store.clear()
            } catch (_: Exception) {
                Unit
            }
        }
    }

    private fun publishSync() {
        _syncState.value = sync.state(Instant.now())
    }

    private fun currentAccess(): LocationAccess {
        if (!prefs.getBoolean(LOCATION_PROMPTED, false)) {
            val granted = LocationService.access(app)
            return if (granted == LocationAccess.authorized) LocationAccess.authorized else LocationAccess.notDetermined
        }
        return LocationService.access(app)
    }

    private fun notificationAccess(): Boolean {
        return if (Build.VERSION.SDK_INT < 33) {
            true
        } else {
            ContextCompat.checkSelfPermission(app, android.Manifest.permission.POST_NOTIFICATIONS) ==
                android.content.pm.PackageManager.PERMISSION_GRANTED
        }
    }

    companion object {
        private const val PREFS = "limit"
        private const val SETTINGS_KEY = "settings.v1"
        private const val ENDED_BY_DRIVER = "drive.endedByDriver"
        private const val LOCATION_PROMPTED = "location.prompted"
        private const val NOTIFICATIONS_PROMPTED = "notifications.prompted"
    }
}
