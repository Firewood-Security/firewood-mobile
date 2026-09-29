package net.firewood.app.notification

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.graphics.Color
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import androidx.core.content.ContextCompat
import net.firewood.app.MainActivity
import net.firewood.app.R

class FirewoodNotificationManager(private val context: Context) {

    companion object {
        const val CHANNEL_ALERTS = "firewood_alerts"
        const val CHANNEL_UPDATES = "firewood_updates"
    }

    init {
        createNotificationChannels()
    }

    private fun createNotificationChannels() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val notificationManager =
                context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

            val alertsChannel = NotificationChannel(
                CHANNEL_ALERTS,
                "Security & Form Alerts",
                NotificationManager.IMPORTANCE_DEFAULT
            ).apply {
                description = "Zero-knowledge security findings, weak passwords, and form completion alerts"
                enableLights(true)
                lightColor = Color.parseColor("#FF5722")
                enableVibration(true)
                // V-020: nothing renders on the lock screen (channel default;
                // users can still loosen this in system settings).
                setLockscreenVisibility(android.app.Notification.VISIBILITY_SECRET)
            }

            val updatesChannel = NotificationChannel(
                CHANNEL_UPDATES,
                "App Updates",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Verified Firewood release update notifications"
                // V-020: same lock-screen redaction as the alerts channel.
                setLockscreenVisibility(android.app.Notification.VISIBILITY_SECRET)
            }

            notificationManager.createNotificationChannel(alertsChannel)
            notificationManager.createNotificationChannel(updatesChannel)
        }
    }

    fun hasPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            ContextCompat.checkSelfPermission(
                context,
                android.Manifest.permission.POST_NOTIFICATIONS
            ) == PackageManager.PERMISSION_GRANTED
        } else {
            NotificationManagerCompat.from(context).areNotificationsEnabled()
        }
    }

    fun showNotification(
        id: Int,
        channelId: String,
        title: String,
        message: String
    ): Boolean {
        if (!hasPermission()) {
            return false
        }

        val targetChannel = if (channelId == CHANNEL_UPDATES) CHANNEL_UPDATES else CHANNEL_ALERTS

        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            putExtra("notification_id", id)
        }

        val pendingIntent = PendingIntent.getActivity(
            context,
            id,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        // V-020: the private notification is fully hidden on the lock screen
        // (VISIBILITY_SECRET). A generic public version rides along for any
        // surface that insists on rendering the public form — it carries no
        // credential details, only a tap-through intent.
        val publicNotification = NotificationCompat.Builder(context, targetChannel)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setColor(Color.parseColor("#FF5722"))
            .setContentTitle("Firewood")
            .setContentText("Open Firewood to view details")
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()

        val builder = NotificationCompat.Builder(context, targetChannel)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setColor(Color.parseColor("#FF5722"))
            .setContentTitle(title)
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle().bigText(message))
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setPublicVersion(publicNotification)
            .setPriority(
                if (targetChannel == CHANNEL_ALERTS)
                    NotificationCompat.PRIORITY_DEFAULT
                else
                    NotificationCompat.PRIORITY_LOW
            )
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        try {
            NotificationManagerCompat.from(context).notify(id, builder.build())
            return true
        } catch (_: SecurityException) {
            return false
        }
    }

    fun cancelNotification(id: Int) {
        NotificationManagerCompat.from(context).cancel(id)
    }

    fun cancelAllNotifications() {
        NotificationManagerCompat.from(context).cancelAll()
    }
}
