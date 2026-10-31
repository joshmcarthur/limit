package com.joshmcarthur.limit.ui.settings

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.joshmcarthur.limit.DriveModel
import com.joshmcarthur.limit.core.FreshnessText
import com.joshmcarthur.limit.core.SyncState
import java.time.Instant

@Composable
fun AboutScreen(model: DriveModel, onBack: () -> Unit) {
    val sync by model.syncState.collectAsStateWithLifecycle()
    val context = LocalContext.current
    val row = FreshnessText.row(sync, Instant.now())
    Column(
        Modifier
            .fillMaxSize()
            .statusBarsPadding()
            .verticalScroll(rememberScrollState())
            .padding(16.dp),
    ) {
        Text("About", style = MaterialTheme.typography.headlineMedium)
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
            "A speed limit is a maximum, not a target. Slow down for the conditions, and set the app up before you drive.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text("Speed limit data", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 24.dp))
        Text(row.title, style = MaterialTheme.typography.bodyLarge)
        Text(row.subtitle, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant)
        val retryLabel = if (sync is SyncState.Failed || sync is SyncState.NeverSynced) "Retry" else "Check now"
        TextButton(onClick = { model.retrySync() }) { Text(retryLabel) }
        Text(
            "The National Speed Limit Register (NSLR) holds New Zealand’s certified speed limits in one place. It’s updated every night, and emergency limits are added soon after they’re set. Roadworks and other temporary limits aren’t included.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            "Seasonal limits are assumed to repeat on the same dates every year, so they can be a bit out. School holidays move. Obey the posted signs when you see the label.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            "School zone limits apply on weekdays during school hours. The register doesn’t have term dates, so they also show during school holidays.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(top = 8.dp),
        )
        TextButton(onClick = { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://speedlimits.nzta.govt.nz/"))) }) {
            Text("Search the register online")
        }
        Text("Attribution", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp))
        Text(
            "Speed limit data comes from the National Speed Limit Register (NSLR) by Waka Kotahi NZ Transport Agency, licensed under Creative Commons Attribution 4.0 International.",
            style = MaterialTheme.typography.bodyLarge,
        )
        Text(
            "We’ve changed the data so it works offline: only limits currently in force are kept, repeated records are merged, and school times are read from the notes. Waka Kotahi doesn’t endorse this app.",
            style = MaterialTheme.typography.bodyLarge,
            modifier = Modifier.padding(top = 8.dp),
        )
        TextButton(onClick = {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://opendata-nzta.opendata.arcgis.com/datasets/NZTA::national-speed-limit-register-nslr/about")))
        }) { Text("View the source data") }
        TextButton(onClick = {
            context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://creativecommons.org/by/4.0/")))
        }) { Text("Read the CC BY 4.0 licence") }
        Text("Privacy", style = MaterialTheme.typography.titleMedium, modifier = Modifier.padding(top = 16.dp))
        Text(
            "Your location and speed stay on your device. You don’t need an account, and we don’t collect any information.",
            style = MaterialTheme.typography.bodyLarge,
        )
        TextButton(onClick = onBack, modifier = Modifier.padding(top = 16.dp)) { Text("Back") }
    }
}
