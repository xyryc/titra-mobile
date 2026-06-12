# Firebase Call System — How It Works

This document explains the end-to-end call flow: from Firebase Cloud Messaging (FCM) wakeup through WebRTC media connection.

---

## Stack overview

| Layer | Technology | Purpose |
|---|---|---|
| Wakeup / notification | Firebase Cloud Messaging | Wake the app when it is backgrounded or killed |
| Signaling transport | Socket.IO (`call.state`, `call.signal`) | Exchange SDP offer/answer and ICE candidates |
| Media | WebRTC (`flutter_webrtc`) | Actual audio/video stream |
| REST | `calls/*` API | Session lifecycle (start, join, leave, end, ICE config) |

---

## Key files

```
lib/
  main.dart                                    — Firebase init, background FCM handler registration
  app.dart                                     — Providers, IncomingCallCoordinator attach, push init after login
  core/
    push/
      push_notification_controller.dart        — Routes FCM/local notification taps to the right screen
      background_fcm_handler.dart              — Background isolate: saves payload to shared prefs
      fcm_notification_display.dart            — Builds local notifications from FCM data
    realtime/
      realtime_service.dart                    — Socket.IO client; exposes onCallState / onCallSignal streams
  features/call/data/
    calls_repository.dart                      — REST: start, join, leave, end, ice-config
    incoming_call_coordinator.dart             — Central bridge: ringing state, signal buffering, navigation
    web_rtc_call_session.dart                  — 1:1 WebRTC wrapper (offer/answer/ICE/media)
    incoming_call_ringtone.dart                — In-app ringtone
    outgoing_ringback.dart                     — Ringback tone for caller
    call_end_tone.dart                         — End/missed/declined tones
    active_call_guard.dart                     — Prevents overlapping calls
  features/call/presentation/
    view/video_call_screen.dart
    view/audio_call_screen.dart
    view_models/video_call_view_model.dart
    view_models/audio_call_view_model.dart

android/app/src/main/kotlin/com/shahir/titra/
  IncomingCallFirebaseMessagingService.kt      — Native FCM service (background/killed)
  IncomingCallNotifier.kt                      — Full-screen incoming-call notification with Accept/Decline
  IncomingCallActivity.kt                      — Native full-screen UI; writes pending action to shared prefs
  IncomingCallNativeStore.kt                   — Persists payload/action for Flutter to read on cold start
```

---

## Call flows

### 1. Outgoing call (caller side)

```
User taps call button
  → VideoCallViewModel / AudioCallViewModel
  → CallsRepository.startCall()          — POST /calls/start → returns callSessionId
  → WebRtcCallSession created
  → WebRtcCallSession.startAsCaller()
      createOffer → setLocalDescription
      sendSignal('offer', sdpPayload)    — via RealtimeService.emitCallSignal()
  → Caller waits for 'answer' on onCallSignal
  → WebRtcCallSession.applyAnswer()
  → ICE candidates exchanged (trickle)
  → RTCPeerConnectionState.connected → media starts
```

### 2. Incoming call — app is open (foreground)

```
Socket event: call.state { type: 'started', call: {...} }
  → IncomingCallCoordinator._onCallState()
  → Creates IncomingRingingCall, starts ringtone
  → IncomingCallOverlay shown (notifyListeners)

Socket event: call.signal { signalType: 'offer' }  (may arrive before or after 'started')
  → IncomingCallCoordinator._onCallSignal()
  → Buffered in IncomingRingingCall.bufferedOffer

User taps Accept
  → IncomingCallCoordinator.accept()
  → _stashAcceptedJoinBootstrap()       — moves buffered offer/ICE to _acceptedByCallSessionId
  → Navigates to VideoCallScreen / AudioCallScreen
      passing remoteOffer + preBufferedIceCandidates

ViewModel.init()
  → CallsRepository.joinCall()
  → WebRtcCallSession.startAsCallee(offer)
  → ICE candidates applied
  → sendSignal('answer', ...)
  → Connection established
```

### 3. Incoming call — app is backgrounded or killed (Firebase path)

```
FCM message arrives (type: 'incoming_call')
  → Android: IncomingCallFirebaseMessagingService
      → IncomingCallNotifier shows full-screen notification with Accept / Decline buttons

User taps Accept on native notification
  → IncomingCallActivity writes payload + action to shared prefs
  → Launches Flutter (cold start or resume)

Flutter starts
  → PushNotificationController.initialize()
      reads shared prefs → pendingOpen = { type:'incoming_call', ... }
      pendingOpenActionId = 'fcm_call_accept'

After login / home screen ready
  → PushNotificationController.consumePendingOpen()
  → _acceptIncomingFromNotification(data)
      1. Waits for Socket.IO to reconnect (RealtimeService.waitUntilConnected)
      2. coordinator.startPreScreenBuffering(callSessionId)
             — starts listening for offer/ICE NOW, before screen is pushed
      3. 600 ms delay (lets buffered signals accumulate)
      4. coordinator.acceptFromPushData(data)
             — navigates to VideoCallScreen / AudioCallScreen
             — passes any already-buffered offer/ICE

ViewModel.init()
  → coordinator.consumeAcceptedJoinBootstrap(callSessionId)
  → CallsRepository.joinCall()
  → if offer present: WebRtcCallSession.startAsCallee(offer)
  → if no offer yet: sends signalType='offer-request' to caller
      → Caller receives it → WebRtcCallSession.resendLastOfferOrCreate()
      → Callee receives resent offer → startAsCallee()
  → ICE exchange → connection established
```

---

## Signal buffering — why it matters

Signals can arrive in any order relative to the app lifecycle:

| Scenario | What happens |
|---|---|
| `call.signal offer` arrives before `call.state started` | Stored in `_earlyByCallSessionId` map; merged into `IncomingRingingCall` when `started` arrives |
| `call.signal offer` arrives while ringing (before accept) | Stored in `IncomingRingingCall.bufferedOffer` |
| `call.signal offer` arrives after accept but before ViewModel init | Captured by `startPreScreenBuffering()` into `_bufferedOffer` |
| `call.signal offer` arrives after ViewModel subscribes | Received live via `RealtimeService.onCallSignal` |

`IncomingCallCoordinator.consumeAcceptedJoinBootstrap()` merges all of these layers and hands them to the ViewModel in one call.

---

## Offer replay (cold-start recovery)

When the callee app was killed, the caller's first `offer` signal was never received. The recovery sequence:

1. Callee joins the call session via REST.
2. Callee sends `signalType = 'offer-request'` through the socket.
3. Caller's ViewModel receives it and calls `WebRtcCallSession.resendLastOfferOrCreate()`.
4. Callee receives the replayed offer and proceeds normally.

This is implemented for direct 1:1 audio and video calls only.

---

## FCM payload fields (incoming_call)

| Field | Description |
|---|---|
| `type` | Always `"incoming_call"` |
| `callSessionId` | Unique call session ID |
| `conversationId` | Conversation the call belongs to |
| `initiatorUserId` | User ID of the caller |
| `initiatorName` | Display name of the caller |
| `initiatorAccountId` | Account ID (for avatar lookup) |
| `callType` | `"AUDIO"` or `"VIDEO"` |
| `isGroup` | `"1"` for group calls, `"0"` for direct |

---

## Debugging checklist

**Call does not connect after accepting from notification**

1. Check `[Push] accept incoming call realtimeConnected=` log — if `false`, socket did not reconnect in time.
2. Check `[IncomingCall] acceptFromPushData sid=... hasOffer=... preIce=...` — if `hasOffer=false`, the offer was not buffered.
3. Check ViewModel logs for `startAsCallee with push/bootstrap offer` or `waiting for remote offer over realtime`.
4. Check `[WebRtc] connectionState=` — should reach `connected`. If it reaches `failed`, check ICE servers.

**No audio/video after connection**

- Check `[WebRtc] iceServers count=` — if 0, the `/calls/ice-config` REST call failed.
- Verify TURN credentials are valid (they expire).

**Ringtone keeps playing after accept**

- `IncomingCallCoordinator._syncIncomingRingtone(false)` is called in both `accept()` and `acceptFromPushData()`. If it still plays, check that `_ringing` is being cleared.

**Group call does not open**

- `acceptFromPushData` fetches group member list via `ConversationsRepository.fetchGroupConversationDetail()`. A network failure here will silently abort navigation. Check for `[IncomingCall] group acceptFromPushData:` error logs.
