package com.joshmcarthur.limit.ui.settings

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.OpenInNew
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.joshmcarthur.limit.DriveModel

private const val REGISTER_WEBSITE = "https://speedlimits.nzta.govt.nz/"
private const val SOURCE_DATA =
    "https://opendata-nzta.opendata.arcgis.com/datasets/NZTA::national-speed-limit-register-nslr/about"
private const val LICENCE = "https://creativecommons.org/licenses/by/4.0/"

@Composable
fun AboutScreen(model: DriveModel) {
    val sync by model.syncState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    Column(
        Modifier
            .fillMaxSize()
            .windowInsetsPadding(WindowInsets.safeDrawing)
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 16.dp),
    ) {
        Text("About", style = MaterialTheme.typography.headlineMedium, modifier = Modifier.padding(top = 24.dp))
        Text(
            "Always obey the posted speed limits and follow the NZ Road Code. Use this app as a guide only.",
            style = MaterialTheme.typography.titleMedium,
            modifier = Modifier.padding(top = 16.dp),
        )
        Text(
            "The register can be out of date or differ from the signs on the road, and GPS speed can be a few km/h out.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            "A speed limit is a maximum, not a target. Slow down for the conditions, and set up the app before you drive.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text("Speed limit data", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 24.dp))
        SyncStatusRow(state = sync, onRetry = { model.retrySync() })
        Text(
            "The National Speed Limit Register (NSLR) holds New Zealand\u2019s certified speed limits in one place. It\u2019s updated every night, and emergency limits are added soon after they\u2019re set. Roadworks and other temporary limits aren\u2019t included.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            "Seasonal limits are assumed to repeat on the same dates every year, so they can be a bit out. School holidays move. Obey the posted signs when you see the label.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            "School zone limits apply on weekdays during school hours. The register doesn\u2019t have term dates, so they also show during school holidays.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(top = 8.dp),
        )
        LinkButton("Search the register online") {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(REGISTER_WEBSITE)))
        }
        Text("Attribution", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp))
        Text(
            "Speed limit data comes from the National Speed Limit Register (NSLR) by Waka Kotahi NZ Transport Agency, licensed under Creative Commons Attribution 4.0 International.",
            style = MaterialTheme.typography.bodyLarge,
        )
        Text(
            "We\u2019ve changed the data so it works offline: only limits currently in force are kept, repeated records are merged, and school times are read from the notes. Waka Kotahi doesn\u2019t endorse this app.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(top = 8.dp),
        )
        LinkButton("View the source data") {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(SOURCE_DATA)))
        }
        LinkButton("Read the CC BY 4.0 licence") {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(LICENCE)))
        }
        Text("Privacy", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp))
        Text(
            "Your location and speed stay on your device. You don\u2019t need an account, and we don\u2019t collect any information.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(bottom = 24.dp),
        )
    }
}

@Composable
private fun LinkButton(label: String, onClick: () -> Unit) {
    TextButton(onClick = onClick, modifier = Modifier.heightIn(min = 48.dp)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(label)
            Icon(Icons.AutoMirrored.Rounded.OpenInNew, contentDescription = null, modifier = Modifier.padding(start = 8.dp))
        }
    }
}
