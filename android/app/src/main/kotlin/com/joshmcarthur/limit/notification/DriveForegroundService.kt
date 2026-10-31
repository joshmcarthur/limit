package com.joshmcarthur.limit.notification

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.graphics.drawable.Icon
import android.os.Build
import android.os.IBinder
import androidx.core.app.NotificationCompat
import androidx.core.app.ServiceCompat
import com.joshmcarthur.limit.LimitApp
import com.joshmcarthur.limit.MainActivity
import com.joshmcarthur.limit.R
import com.joshmcarthur.limit.core.DriveSnapshot
import com.joshmcarthur.limit.core.LiveActivityRefresh
import java.time.Duration
import java.time.Instant

class DriveForegroundService : Service() {
    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        ensureChannels()
        when (intent?.action) {
            ACTION_END -> {
                (application as LimitApp).driveModel.endDrive(byDriver = true)
                stopSelf()
                return START_NOT_STICKY
            }
            ACTION_KEEP -> {
                (application as LimitApp).driveModel.keepDriving()
                val manager = getSystemService(NotificationManager::class.java)
                manager.cancel(DriveNotification.STOP_ID)
                return START_STICKY
            }
            ACTION_PING -> {
                postStopPrompt()
                return START_STICKY
            }
        }
        val snapshot = (application as LimitApp).driveModel.driveState.value.snapshot
        val notification = buildDriveNotification(snapshot)
        if (Build.VERSION.SDK_INT >= 34) {
            ServiceCompat.startForeground(
                this,
                DriveNotification.DRIVE_ID,
                notification,
                ServiceInfo.FOREGROUND_SERVICE_TYPE_LOCATION,
            )
        } else {
            startForeground(DriveNotification.DRIVE_ID, notification)
        }
        lastSent = Instant.now()
        lastSnapshot = snapshot
        return START_STICKY
    }

    private fun postStopPrompt() {
        val end = pending(ACTION_END, 11)
        val keep = pending(ACTION_KEEP, 12)
        val notification = NotificationCompat.Builder(this, DriveNotification.STOP_CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_sign)
            .setContentTitle("Looks like you've stopped driving")
            .setContentText("End the drive to stop using location.")
            .setContentIntent(openApp())
            .addAction(0, "End drive", end)
            .addAction(0, "Keep driving", keep)
            .setAutoCancel(true)
            .build()
        getSystemService(NotificationManager::class.java).notify(DriveNotification.STOP_ID, notification)
    }

    private fun pending(action: String, request: Int): PendingIntent {
        val intent = Intent(this, DriveForegroundService::class.java).setAction(action)
        return PendingIntent.getService(this, request, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun openApp(): PendingIntent {
        val intent = Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP)
        return PendingIntent.getActivity(this, 1, intent, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun ensureChannels() {
        val manager = getSystemService(NotificationManager::class.java)
        if (manager.getNotificationChannel(DriveNotification.DRIVE_CHANNEL) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    DriveNotification.DRIVE_CHANNEL,
                    "Drive in progress",
                    NotificationManager.IMPORTANCE_LOW,
                ).apply {
                    setSound(null, null)
                    enableVibration(false)
                },
            )
        }
        if (manager.getNotificationChannel(DriveNotification.STOP_CHANNEL) == null) {
            manager.createNotificationChannel(
                NotificationChannel(
                    DriveNotification.STOP_CHANNEL,
                    "Drive ended suggestion",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ),
            )
        }
    }

    companion object {
        const val ACTION_START = "com.joshmcarthur.limit.DRIVE_START"
        const val ACTION_END = "com.joshmcarthur.limit.DRIVE_END"
        const val ACTION_KEEP = "com.joshmcarthur.limit.DRIVE_KEEP"
        const val ACTION_PING = "com.joshmcarthur.limit.DRIVE_PING"

        private var lastSent: Instant? = null
        private var lastSnapshot: DriveSnapshot? = null

        fun update(context: Context, snapshot: DriveSnapshot, showOnLockScreen: Boolean) {
            val changed = snapshot != lastSnapshot
            val elapsed = lastSent?.let { Duration.between(it, Instant.now()) }
            val limitChanged = snapshot.sign != lastSnapshot?.sign
            val speedDue = changed || LiveActivityRefresh.shouldSend(changed, elapsed)
            if (!limitChanged && !speedDue) return
            lastSnapshot = snapshot
            lastSent = Instant.now()
            val appContext = context.applicationContext
            val notification = appContext.buildDriveNotification(snapshot)
            val manager = context.getSystemService(NotificationManager::class.java)
            manager.notify(DriveNotification.DRIVE_ID, notification)
        }

        fun pingStopped(context: Context) {
            val intent = Intent(context, DriveForegroundService::class.java).setAction(ACTION_PING)
            context.startService(intent)
        }
    }
}

private fun Context.buildDriveNotification(snapshot: DriveSnapshot): Notification {
    val density = resources.displayMetrics.density
    val large = SignBitmaps.largeIcon(this, snapshot.sign, (96 * density).toInt())
    val end = PendingIntent.getService(
        this,
        10,
        Intent(this, DriveForegroundService::class.java).setAction(DriveForegroundService.ACTION_END),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val open = PendingIntent.getActivity(
        this,
        1,
        Intent(this, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_SINGLE_TOP),
        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
    )
    val builder = NotificationCompat.Builder(this, DriveNotification.DRIVE_CHANNEL)
        .setSmallIcon(R.drawable.ic_stat_sign)
        .setLargeIcon(large)
        .setContentTitle(DriveNotification.title(snapshot))
        .setContentText(DriveNotification.text(snapshot))
        .setSubText("Driving")
        .setContentIntent(open)
        .setOngoing(true)
        .setOnlyAlertOnce(true)
        .setSilent(true)
        .setCategory(NotificationCompat.CATEGORY_NAVIGATION)
        .addAction(0, "End drive", end)
        .setForegroundServiceBehavior(NotificationCompat.FOREGROUND_SERVICE_IMMEDIATE)
    if (Build.VERSION.SDK_INT >= 36) {
        builder.setRequestPromotedOngoing(true)
        builder.setLargeIcon(Icon.createWithBitmap(large))
    }
    return builder.build()
}
