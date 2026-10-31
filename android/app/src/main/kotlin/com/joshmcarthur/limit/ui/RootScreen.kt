package com.joshmcarthur.limit.ui

import androidx.activity.compose.BackHandler
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.joshmcarthur.limit.DriveModel
import com.joshmcarthur.limit.ui.drive.DriveScreen
import com.joshmcarthur.limit.ui.settings.AboutScreen
import com.joshmcarthur.limit.ui.settings.SettingsScreen
import com.joshmcarthur.limit.ui.setup.SetupScreen

private enum class Dest { Drive, Settings, About }

@Composable
fun RootScreen(model: DriveModel) {
    val settings by model.settings.collectAsStateWithLifecycle()
    var dest by rememberSaveable { mutableStateOf(Dest.Drive) }
    if (!settings.hasCompletedOnboarding) {
        SetupScreen(model)
        return
    }
    BackHandler(enabled = dest != Dest.Drive) {
        dest = if (dest == Dest.About) Dest.Settings else Dest.Drive
    }
    when (dest) {
        Dest.Drive -> DriveScreen(model, onSettings = { dest = Dest.Settings })
        Dest.Settings -> SettingsScreen(model, onAbout = { dest = Dest.About })
        Dest.About -> AboutScreen(model)
    }
}
