package com.shahir.titra

import android.content.Context
import org.json.JSONObject

internal object IncomingCallNativeStore {
    private const val PREFS_NAME = "FlutterSharedPreferences"
    private const val FLUTTER_PREFIX = "flutter."
    private const val KEY_PAYLOAD = "pending_notification_payload"
    private const val KEY_ACTION = "pending_notification_action"
    private const val KEY_TIMESTAMP = "pending_notification_timestamp"

    fun persistPendingNotification(
        context: Context,
        payloadJson: String,
        actionId: String? = null,
        timestamp: Long = System.currentTimeMillis(),
    ) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .putString("${FLUTTER_PREFIX}$KEY_PAYLOAD", payloadJson)
            .apply {
                if (actionId.isNullOrBlank()) {
                    remove("${FLUTTER_PREFIX}$KEY_ACTION")
                } else {
                    putString("${FLUTTER_PREFIX}$KEY_ACTION", actionId)
                }
            }
            .putLong("${FLUTTER_PREFIX}$KEY_TIMESTAMP", timestamp)
            .apply()
    }

    fun getPendingCall(context: Context): PendingCallData? {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val payload = prefs.getString("${FLUTTER_PREFIX}$KEY_PAYLOAD", null)
        val action = prefs.getString("${FLUTTER_PREFIX}$KEY_ACTION", null)
        val timestamp = prefs.getLong("${FLUTTER_PREFIX}$KEY_TIMESTAMP", 0)

        if (payload.isNullOrBlank()) return null

        if (timestamp > 0 && System.currentTimeMillis() - timestamp > 30000) {
            clearPendingCall(context)
            return null
        }

        return PendingCallData(
            payloadJson = payload,
            actionId = action,
            timestamp = timestamp,
        )
    }

    fun clearPendingCall(context: Context) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        prefs.edit()
            .remove("${FLUTTER_PREFIX}$KEY_PAYLOAD")
            .remove("${FLUTTER_PREFIX}$KEY_ACTION")
            .remove("${FLUTTER_PREFIX}$KEY_TIMESTAMP")
            .apply()
    }

    fun notificationId(payloadJson: String): Int {
        val callSessionId = try {
            JSONObject(payloadJson).optString("callSessionId")
        } catch (_: Exception) {
            ""
        }
        return if (callSessionId.isBlank()) {
            payloadJson.hashCode()
        } else {
            callSessionId.hashCode()
        }
    }
}

data class PendingCallData(
    val payloadJson: String,
    val actionId: String?,
    val timestamp: Long,
)
