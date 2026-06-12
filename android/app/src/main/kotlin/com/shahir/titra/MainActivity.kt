package com.shahir.titra

import android.content.Intent
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val methodChannel = "com.shahir.titra/call_lifecycle"
        private const val TAG = "MainActivity"
    }

    private var methodChannelRef: MethodChannel? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        val channel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, methodChannel)
        methodChannelRef = channel

        channel.setMethodCallHandler { call, result ->
            when (call.method) {
                "getPendingCall" -> {
                    val pending = IncomingCallNativeStore.getPendingCall(this)
                    if (pending == null) {
                        result.success(null)
                    } else {
                        result.success(
                            mapOf(
                                "payloadJson" to pending.payloadJson,
                                "actionId" to pending.actionId,
                                "timestamp" to pending.timestamp,
                            ),
                        )
                    }
                }

                "clearPendingCall", "onCallHandled" -> {
                    IncomingCallNativeStore.clearPendingCall(this)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }

        // Handle the intent that launched this activity (covers the minimised-state resume case)
        handleCallIntent(intent)
    }

    /** Called when the app is already running and a new intent arrives (FLAG_ACTIVITY_SINGLE_TOP). */
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        handleCallIntent(intent)
    }

    /**
     * If [intent] was fired by [IncomingCallActivity] (Accept action while app was minimised),
     * persist the payload so Flutter can pick it up via [getPendingCall], then notify Flutter
     * directly via the MethodChannel so it doesn't have to wait for the next frame.
     */
    private fun handleCallIntent(intent: Intent?) {
        val payloadJson = intent?.getStringExtra(IncomingCallActivity.extraPayloadJson)
            ?: return
        if (!intent.getBooleanExtra("from_incoming_call", false)) return

        val actionId = intent.getStringExtra(IncomingCallActivity.extraActionId)

        Log.d(TAG, "handleCallIntent: action=$actionId payload=$payloadJson")

        // Always (re-)persist so getPendingCall returns fresh data
        IncomingCallNativeStore.persistPendingNotification(
            this,
            payloadJson,
            actionId,
            System.currentTimeMillis(),
        )

        // Notify Flutter immediately via MethodChannel so it can act without
        // waiting for SharedPreferences round-trip
        methodChannelRef?.invokeMethod(
            "onIncomingCallAction",
            mapOf(
                "payloadJson" to payloadJson,
                "actionId" to (actionId ?: ""),
            ),
        )
    }

    /** Called when user swipes app away from recents (task killed). */
    override fun onDestroy() {
        super.onDestroy()
        if (isTaskRoot) {
            // Stop the foreground call service so audio/notification is cleaned up
            stopService(Intent(this, id.flutter.flutter_background_service.BackgroundService::class.java))
            // Clear any pending incoming call state
            IncomingCallNativeStore.clearPendingCall(this)
        }
    }
}
