package com.shahir.titra

import android.app.Activity
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.view.WindowManager

class IncomingCallActivity : Activity() {
    companion object {
        const val extraPayloadJson = "incoming_call_payload_json"
        const val extraActionId = "incoming_call_action_id"
        const val acceptActionId = "fcm_call_accept"
        const val declineActionId = "fcm_call_decline"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        prepareWindow()
        forwardToFlutter(intent)
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        forwardToFlutter(intent)
    }

    private fun forwardToFlutter(intent: Intent) {
        val payloadJson = intent.getStringExtra(extraPayloadJson)
        if (payloadJson.isNullOrBlank()) {
            finish()
            return
        }

        val actionId = intent.getStringExtra(extraActionId)
        
        if (actionId == declineActionId) {
            // Send decline broadcast directly
            val declineIntent = Intent(this, IncomingCallActionReceiver::class.java).apply {
                action = IncomingCallActionReceiver.ACTION_DECLINE
                putExtra(extraPayloadJson, payloadJson)
            }
            sendBroadcast(declineIntent)
            finish()
            return
        }

        IncomingCallNativeStore.persistPendingNotification(
            this,
            payloadJson,
            actionId,
            System.currentTimeMillis(),
        )

        IncomingCallNotifier.cancelIncomingCall(this, payloadJson)

        val launchIntent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or
                Intent.FLAG_ACTIVITY_CLEAR_TOP or
                Intent.FLAG_ACTIVITY_SINGLE_TOP
            putExtra("from_incoming_call", true)
            putExtra(extraPayloadJson, payloadJson)
            putExtra(extraActionId, actionId)
        }
        startActivity(launchIntent)
        finish()
    }

    private fun prepareWindow() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        } else {
            @Suppress("DEPRECATION")
            window.addFlags(
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            )
        }
        window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
    }
}
