package com.shahir.titra

import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage

class IncomingCallFirebaseMessagingService : FirebaseMessagingService() {
    override fun onMessageReceived(message: RemoteMessage) {
        val payload = message.data
        if (payload["type"] != "incoming_call") {
            return
        }
        if (IncomingCallNotifier.isAppInForeground(this)) {
            return
        }
        if (payload["callSessionId"].isNullOrBlank() ||
            payload["conversationId"].isNullOrBlank() ||
            payload["initiatorUserId"].isNullOrBlank()
        ) {
            return
        }
        IncomingCallNotifier.showIncomingCall(
            this,
            payload.mapValues { it.value },
        )
    }
}
