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
            
            // 1. Cancel notification
            IncomingCallNotifier.cancelIncomingCall(context, payloadJson)

            // 2. Send decline to backend
            declineCallOnBackend(context, payloadJson)
        }
    }

    private fun declineCallOnBackend(context: Context, payloadJson: String) {
        val callSessionId = try {
            JSONObject(payloadJson).getString("callSessionId")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to parse callSessionId", e)
            return
        }

        val prefs = context.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val token = prefs.getString("flutter.native_session_token", null)

        if (token.isNullOrBlank()) {
            Log.e(TAG, "No session token found for native decline")
            return
        }

        thread {
            var conn: HttpURLConnection? = null
            try {
                val url = URL("https://tietra.xdtunnel.icu/api/v1/calls/end")
                conn = url.openConnection() as HttpURLConnection
                conn.requestMethod = "POST"
                conn.setRequestProperty("Content-Type", "application/json")
                conn.setRequestProperty("x-session-token", token)
                conn.doOutput = true

                val body = JSONObject().apply {
                    put("callSessionId", callSessionId)
                    put("reason", "declined")
                }

                conn.outputStream.use { os ->
                    os.write(body.toString().toByteArray())
                }

                val responseCode = conn.responseCode
                Log.d(TAG, "Decline request (calls/end) sent for sid=$callSessionId. Response: $responseCode")
            } catch (e: Exception) {
                Log.e(TAG, "Failed to send decline request", e)
            } finally {
                conn?.disconnect()
            }
        }
    }
}
