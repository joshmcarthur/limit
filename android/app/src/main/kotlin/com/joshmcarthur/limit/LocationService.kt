package com.joshmcarthur.limit

import android.Manifest
import android.annotation.SuppressLint
import android.content.Context
import android.content.pm.PackageManager
import android.location.Criteria
import android.location.Location
import android.location.LocationListener
import android.location.LocationManager
import android.os.Bundle
import android.os.Looper
import androidx.core.content.ContextCompat
import com.joshmcarthur.limit.core.Coordinate
import com.joshmcarthur.limit.core.LocationAccess
import com.joshmcarthur.limit.core.LocationSample
import java.time.Instant

class LocationService(private val context: Context) {
    var onSample: ((LocationSample) -> Unit)? = null
    var onAccessChange: ((LocationAccess) -> Unit)? = null

    private val manager = context.getSystemService(Context.LOCATION_SERVICE) as LocationManager
    private val listener = object : LocationListener {
        override fun onLocationChanged(location: Location) {
            onSample?.invoke(
                LocationSample(
                    coordinate = Coordinate(location.latitude, location.longitude),
                    speedMetresPerSecond = location.speed.toDouble(),
                    horizontalAccuracy = location.accuracy.toDouble(),
                    timestamp = Instant.ofEpochMilli(location.time),
                ),
            )
        }

        @Deprecated("Deprecated in Java")
        override fun onStatusChanged(provider: String?, status: Int, extras: Bundle?) = Unit
        override fun onProviderEnabled(provider: String) = Unit
        override fun onProviderDisabled(provider: String) = Unit
    }

    val access: LocationAccess get() = access(context)

    @SuppressLint("MissingPermission")
    fun start() {
        if (access != LocationAccess.authorized) return
        val criteria = Criteria().apply {
            accuracy = Criteria.ACCURACY_FINE
            isSpeedRequired = true
        }
        val provider = manager.getBestProvider(criteria, true) ?: LocationManager.GPS_PROVIDER
        manager.requestLocationUpdates(provider, 1_000L, 0f, listener, Looper.getMainLooper())
    }

    fun stop() {
        manager.removeUpdates(listener)
    }

    companion object {
        fun access(context: Context): LocationAccess {
            val fine = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_FINE_LOCATION)
            val coarse = ContextCompat.checkSelfPermission(context, Manifest.permission.ACCESS_COARSE_LOCATION)
            return when {
                fine == PackageManager.PERMISSION_GRANTED -> LocationAccess.authorized
                coarse == PackageManager.PERMISSION_GRANTED -> LocationAccess.reduced
                else -> LocationAccess.denied
            }
        }
    }
}
