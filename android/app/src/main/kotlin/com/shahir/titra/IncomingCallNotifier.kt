package com.shahir.titra

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import org.json.JSONObject

internal object IncomingCallNotifier {
    private const val callsChannelId = "titra_calls"
    private const val callsChannelName = "Calls"
    private const val callsChannelDescription = "Incoming calls"

    fun showIncomingCall(context: Context, payload: Map<String, String>) {
        val payloadJson = JSONObject(payload).toString()
        val notificationId = IncomingCallNativeStore.notificationId(payloadJson)
        ensureChannel(context)

        val launchIntent = Intent(context, IncomingCallActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(IncomingCallActivity.extraPayloadJson, payloadJson)
        }
        val contentIntent = PendingIntent.getActivity(
            context,
            notificationId,
            launchIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val acceptIntent = Intent(context, IncomingCallActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra(IncomingCallActivity.extraPayloadJson, payloadJson)
            putExtra(IncomingCallActivity.extraActionId, IncomingCallActivity.acceptActionId)
        }
        val acceptPendingIntent = PendingIntent.getActivity(
            context,
            notificationId + 1,
            acceptIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val declineIntent = Intent(context, IncomingCallActionReceiver::class.java).apply {
            action = IncomingCallActionReceiver.ACTION_DECLINE
            putExtra(IncomingCallActivity.extraPayloadJson, payloadJson)
        }
        val declinePendingIntent = PendingIntent.getBroadcast(
            context,
            notificationId + 2,
            declineIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

        val callerName = payload["initiatorName"]
            ?.takeIf { it.isNotBlank() }
            ?: "Someone"
        val title = if ((payload["callType"] ?: "").equals("VIDEO", ignoreCase = true)) {
            "Incoming video call"
        } else {
            "Incoming call"
        }
        val body = payload["alertBody"]
            ?.takeIf { it.isNotBlank() }
            ?: "$callerName is calling"

        val notification = NotificationCompat.Builder(context, callsChannelId)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle(title)
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_CALL)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setOngoing(true)
            .setAutoCancel(false)
            .setSound(ringtoneUri(context))
            .setFullScreenIntent(contentIntent, true)
            .setContentIntent(contentIntent)
            .addAction(0, "Accept", acceptPendingIntent)
            .addAction(0, "Decline", declinePendingIntent)
            .build()

        NotificationManagerCompat.from(context).notify(notificationId, notification)
    }

    fun cancelIncomingCall(context: Context, payloadJson: String) {
        NotificationManagerCompat.from(context).cancel(
            IncomingCallNativeStore.notificationId(payloadJson),
        )
    }

    fun isAppInForeground(context: Context): Boolean {
        val manager = context.getSystemService(Context.ACTIVITY_SERVICE) as? ActivityManager
            ?: return false
        val packageName = context.packageName
        return manager.runningAppProcesses?.any { process ->
            process.processName == packageName &&
                process.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND
        } == true
    }

    private fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val existing = manager.getNotificationChannel(callsChannelId)
        if (existing != null) return

        val channel = NotificationChannel(
            callsChannelId,
            callsChannelName,
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = callsChannelDescription
            lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            setSound(
                ringtoneUri(context),
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_NOTIFICATION_RINGTONE)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            enableVibration(true)
        }
        manager.createNotificationChannel(channel)
    }

    private fun ringtoneUri(context: Context): Uri {
        return Uri.parse("android.resource://${context.packageName}/${R.raw.ringtone}")
    }
}
