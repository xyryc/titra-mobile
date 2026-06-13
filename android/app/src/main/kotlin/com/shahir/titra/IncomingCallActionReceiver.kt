package com.shahir.titra

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import org.json.JSONObject
import java.net.HttpURLConnection
import java.net.URL
import kotlin.concurrent.thread

class IncomingCallActionReceiver : BroadcastReceiver() {
    companion object {
        private const val TAG = "IncomingCallReceiver"
        const val ACTION_DECLINE = "com.shahir.titra.ACTION_DECLINE"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val payloadJson = intent.getStringExtra(IncomingCallActivity.extraPayloadJson)
        if (payloadJson.isNullOrBlank()) return

        if (intent.action == ACTION_DECLINE) {
            Log.d(TAG, "Declining call via receiver")
            
            // 1. Cancel notification immediately
            IncomingCallNotifier.cancelIncomingCall(context, payloadJson)

            // 2. Send decline to backend using goAsync to ensure thread completes
            val pendingResult = goAsync()
            thread {
                try {
                    declineCallOnBackend(context, payloadJson)
                } finally {
                    pendingResult.finish()
                }
            }
        }
    }

    private fun declineCallOnBackend(context: Context, payloadJson: String) {
        val payloadObj = try {
            JSONObject(payloadJson)
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse payload: $payloadJson", e)
            return
        }

        val callSessionId = payloadObj.optString("callSessionId")
        val conversationId = payloadObj.optString("conversationId")

        if (callSessionId.isNullOrBlank()) {
            Log.e(TAG, "Missing callSessionId in payload")
            return
        }

        // Try multiple possible SharedPreferences file names
        var token: String? = null
        var deviceId: String? = null
        val prefFiles = arrayOf(
            "FlutterSharedPreferences", 
            "SharedPreferences", 
            "titra_preferences", 
            "${context.packageName}_preferences",
            "com.shahir.titra_preferences",
            "flutter"
        )
        
        for (fileName in prefFiles) {
            val prefs = context.getSharedPreferences(fileName, Context.MODE_PRIVATE)
            token = token ?: prefs.getString("flutter.native_session_token", null) 
                    ?: prefs.getString("native_session_token", null)
            
            deviceId = deviceId ?: prefs.getString("flutter.native_device_id", null)
                    ?: prefs.getString("native_device_id", null)
                    ?: prefs.getString("flutter.titra_device_id", null)
            
            if (!token.isNullOrBlank() && !deviceId.isNullOrBlank()) break
        }

        if (token.isNullOrBlank()) {
            Log.e(TAG, "ABORT: No session token found. Native decline is impossible.")
            return
        }

        var conn: HttpURLConnection? = null
        try {
            val url = URL("https://tietra.xdtunnel.icu/api/v1/calls/end")
            conn = url.openConnection() as HttpURLConnection
            conn.requestMethod = "POST"
            conn.setRequestProperty("Content-Type", "application/json; charset=UTF-8")
            conn.setRequestProperty("Accept", "application/json")
            conn.setRequestProperty("x-session-token", token)
            if (!deviceId.isNullOrBlank()) {
                conn.setRequestProperty("x-device-id", deviceId)
            }
            conn.setRequestProperty("User-Agent", "TitraNative/1.0")
            conn.connectTimeout = 15000
            conn.readTimeout = 15000
            conn.doOutput = true

            val body = JSONObject()
            body.put("callSessionId", callSessionId)
            if (!conversationId.isNullOrBlank()) {
                body.put("conversationId", conversationId)
            }
            body.put("reason", "declined")

            val jsonString = body.toString()
            Log.d(TAG, "Executing background decline: POST $url")
            Log.d(TAG, "Payload: $jsonString")

            conn.outputStream.use { os ->
                os.write(jsonString.toByteArray(Charsets.UTF_8))
            }

            val responseCode = conn.responseCode
            if (responseCode >= 400) {
                val errorBody = conn.errorStream?.bufferedReader()?.use { it.readText() }
                Log.e(TAG, "SERVER ERROR $responseCode: $errorBody")
            } else {
                Log.d(TAG, "SUCCESS: Call declined (Code $responseCode)")
            }
        } catch (e: Exception) {
            Log.e(TAG, "NETWORK ERROR during background decline", e)
        } finally {
            conn?.disconnect()
        }
    }
}
