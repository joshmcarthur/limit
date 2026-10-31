package com.joshmcarthur.limit.auto

import android.content.Intent
import androidx.car.app.CarAppService
import androidx.car.app.Screen
import androidx.car.app.Session
import androidx.car.app.validation.HostValidator
import com.joshmcarthur.limit.BuildConfig
import com.joshmcarthur.limit.LimitApp
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.launch

class LimitCarAppService : CarAppService() {
    override fun createHostValidator(): HostValidator {
        return if (BuildConfig.DEBUG) {
            HostValidator.ALLOW_ALL_HOSTS_VALIDATOR
        } else {
            HostValidator.Builder(applicationContext)
                .addAllowedHosts(androidx.car.app.R.array.hosts_allowlist_sample)
                .build()
        }
    }

    override fun onCreateSession(): Session = LimitCarSession()
}

class LimitCarSession : Session() {
    private var collectJob: Job? = null

    override fun onCreateScreen(intent: Intent): Screen {
        val screen = DriveCarScreen(carContext)
        val model = (carContext.applicationContext as LimitApp).driveModel
        collectJob?.cancel()
        collectJob = CoroutineScope(Dispatchers.Main.immediate).launch {
            combine(model.driveState, model.isDriving) { _, _ -> }
                .collect { screen.invalidate() }
        }
        return screen
    }
}
