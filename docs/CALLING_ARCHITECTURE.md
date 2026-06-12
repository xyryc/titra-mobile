# Calling Architecture

This app uses:

- `calls/*` REST APIs for call session lifecycle
- `call.state` and `call.signal` Socket.IO events for signaling
- WebRTC media for the actual audio/video stream
- Firebase Cloud Messaging for incoming-call wakeup and notification entry

## Main file map

### App bootstrap

- `lib/main.dart`
  Starts Firebase and registers the background FCM handler.
- `lib/app.dart`
  Builds providers, hydrates session, attaches `IncomingCallCoordinator`, initializes push handling after login.

### Push and notification entry

- `lib/core/push/push_notification_controller.dart`
  Central Flutter-side router for FCM/local notification taps. Handles pending opens, accept, decline, and chat/call routing.
- `lib/core/push/background_fcm_handler.dart`
  Background isolate handler for local-notification fallback.
- `lib/core/push/fcm_notification_display.dart`
  Builds local notifications from FCM payloads.
- `android/app/src/main/kotlin/com/shahir/titra/IncomingCallFirebaseMessagingService.kt`
  Android native FCM service for background/killed incoming-call notifications.
- `android/app/src/main/kotlin/com/shahir/titra/IncomingCallNotifier.kt`
  Builds the Android incoming-call full-screen notification with Accept/Decline actions.
- `android/app/src/main/kotlin/com/shahir/titra/IncomingCallActivity.kt`
  Native full-screen incoming-call UI on Android. Accept/Decline writes pending action data and launches Flutter.
- `android/app/src/main/kotlin/com/shahir/titra/IncomingCallNativeStore.kt`
  Stores pending notification payload/action into Flutter shared preferences.

### Realtime and backend APIs

- `lib/core/realtime/realtime_service.dart`
  Socket.IO client for `call.state` and `call.signal`. Also queues outgoing signals while reconnecting.
- `lib/features/call/data/calls_repository.dart`
  REST client for `start`, `join`, `leave`, `end`, and ICE server config.

### Incoming-call coordination

- `lib/features/call/data/incoming_call_coordinator.dart`
  Global coordinator for ringing state, push-presented incoming calls, signal buffering before accept, and screen navigation.
- `lib/features/call/presentation/widgets/incoming_call_overlay.dart`
  In-app accept/decline overlay when the app is already open.

### 1:1 call implementation

- `lib/features/call/data/web_rtc_call_session.dart`
  Core 1:1 WebRTC wrapper: local media, offer/answer, ICE, remote stream, connection state.
- `lib/features/call/presentation/view/video_call_screen.dart`
  Video call route and UI.
- `lib/features/call/presentation/view_models/video_call_view_model.dart`
  Video call bootstrap and runtime logic.
- `lib/features/call/presentation/view/audio_call_screen.dart`
  Audio call route and UI.
- `lib/features/call/presentation/view_models/audio_call_view_model.dart`
  Audio call bootstrap and runtime logic.
- `lib/features/call/data/active_call_guard.dart`
  Prevents overlapping active calls in app state.
- `lib/features/call/data/incoming_call_ringtone.dart`
  Plays the in-app ringtone.
- `lib/features/call/data/outgoing_ringback.dart`
  Plays ringback while caller is waiting.
- `lib/features/call/data/call_end_tone.dart`
  Plays end/missed/declined tones.

### Group call implementation

- `lib/features/call/data/group_mesh_call_coordinator.dart`
  Creates one WebRTC session per remote user for group mesh calls.
- `lib/features/call/data/group_mesh_media.dart`
  Shares/clones media streams across mesh peers.
- `lib/features/call/presentation/view_models/group_video_call_view_model.dart`
  Group video call runtime.
- `lib/features/call/presentation/view_models/group_audio_call_view_model.dart`
  Group audio call runtime.
- `lib/features/call/presentation/view/group_video_call_screen.dart`
  Group video UI.
- `lib/features/call/presentation/view/group_audio_call_screen.dart`
  Group audio UI.

### Call history

- `lib/features/call/presentation/view_models/calls_view_model.dart`
  Loads recent call history.
- `lib/features/home/presentation/view/calls_tab_content.dart`
  Displays call history UI.
- `lib/features/call/data/call_history_entry.dart`
  Call history model.

## Direct 1:1 video call flow

### Outgoing

1. `VideoCallViewModel` calls `CallsRepository.startCall()`.
2. Backend returns `callSessionId`.
3. View model creates `WebRtcCallSession`.
4. `WebRtcCallSession.startAsCaller()` creates local offer and sends it through `RealtimeService.emitCallSignal()`.
5. Remote user receives `call.state started` and `call.signal offer`.
6. Caller receives remote `answer` and `ice-candidate` events through `RealtimeService.onCallSignal`.
7. WebRTC connection becomes `connected`, media starts.

### Incoming while app is open

1. `IncomingCallCoordinator` listens to `call.state`.
2. On `type=started`, it creates `IncomingRingingCall`.
3. Any early `offer` or `ice-candidate` is buffered in the coordinator.
4. User taps Accept in `IncomingCallOverlay`.
5. Coordinator navigates to `VideoCallScreen`.
6. `VideoCallViewModel` joins the call, consumes buffered offer/ICE, starts as callee, then continues with live socket signaling.

### Incoming from Firebase notification

1. Native Android FCM service shows incoming-call UI while app is backgrounded or killed.
2. Accept action writes the payload into shared prefs and launches Flutter.
3. `PushNotificationController.consumePendingOpen()` detects action `fcm_call_accept`.
4. Controller waits for realtime connection, then calls `IncomingCallCoordinator.acceptFromPushData()`.
5. Coordinator stores any already-seen offer/ICE for the accepted call and opens `VideoCallScreen`.
6. `VideoCallViewModel` subscribes to `onCallSignal`, drains stored offer/ICE from the coordinator, calls `joinCall`, and starts as callee when an offer is available.

## Important purpose of `IncomingCallCoordinator`

This file is the bridge between:

- push payload data
- socket `call.state`
- socket `call.signal`
- in-app ringing UI
- final navigation into audio/video call routes

Without it, incoming notification accept would miss timing-sensitive signaling.

## Bug that caused "Accept from Firebase notification but call does not connect"

Previous behavior:

1. Notification accept called `acceptFromPushData()`.
2. Coordinator drained buffered offer/ICE immediately.
3. Flutter navigated to the call screen.
4. More signaling could arrive during navigation, permission prompts, or view-model bootstrap.
5. That later signaling stayed buffered in the coordinator, but the new call screen never consumed it.
6. Result: callee could wait forever for an offer or miss critical ICE candidates.

Current behavior:

- `IncomingCallCoordinator` now keeps an accepted-call bootstrap buffer per `callSessionId`.
- `AudioCallViewModel` and `VideoCallViewModel` consume that buffer only after their realtime listeners are active.
- This closes the race between push accept and WebRTC callee startup for direct calls.

## Killed-app cold start: why background socket service is not the primary fix

For this codebase, the larger problem is not only "socket reconnect is slow".

It is:

1. Caller sends the first WebRTC `offer`.
2. Callee app is killed, so it is offline and misses that live `call.signal`.
3. App wakes from FCM and reconnects later.
4. There was previously no mechanism to recover or replay the missed offer.

Keeping a permanent socket in an Android background service is not the right first fix here:

- it is complex and battery-sensitive
- it still would not help iOS the same way
- it does not solve already-missed signaling unless the caller can replay it

The better app-level fix is:

- reconnect the socket on cold start
- join the call
- if no offer is available yet, ask the caller to resend the last offer

## New direct-call cold-start recovery

The current direct 1:1 flow now adds offer replay:

1. Callee accepts from notification and opens the call screen.
2. If no buffered offer exists after join, the callee sends `signalType=offer-request` to the caller.
3. The outgoing caller resends its cached SDP offer using the same `call.signal` transport.
4. Callee receives the resent offer, calls `startAsCallee()`, then continues normally with answer + ICE.

This is implemented only for direct audio/video calls. Group-call cold-start recovery would need a separate mesh-specific design.

## Where to debug next if calls still fail

- Check `PushNotificationController._acceptIncomingFromNotification()` logs to confirm realtime connection before navigation.
- Check `IncomingCallCoordinator` logs for `acceptFromPushData sid=... hasOffer=... preIce=...`.
- Check `VideoCallViewModel` or `AudioCallViewModel` logs for:
  - `startAsCallee with push/bootstrap offer`
  - `waiting for remote offer over realtime`
  - incoming `signal` logs
- Check `WebRtcCallSession` logs for:
  - ICE server config
  - `iceConnectionState`
  - `connectionState`
- If signaling is correct but media still fails, inspect backend TURN credentials returned by `calls/ice-config`.
