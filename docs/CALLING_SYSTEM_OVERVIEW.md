# Calling System Overview

This document is the short, practical map of the current calling system in `titra-mobile`.

Use this file when you want to answer:

- how calling works end to end
- which file is responsible for which step
- where direct calls start
- how incoming call accept/decline works
- which fixes are already in place
- which call-related files are legacy or not wired

## Stack

- Push wakeup: Firebase Cloud Messaging
- Signaling: Socket.IO events `call.state` and `call.signal`
- Media: WebRTC via `flutter_webrtc`
- Session lifecycle: REST `calls/*`

## Entry Points

### App bootstrap

- `lib/main.dart`
  Initializes Firebase and registers the background FCM handler.
- `lib/app.dart`
  Creates providers for `RealtimeService`, `CallsRepository`, `PushNotificationController`, and `IncomingCallCoordinator`.
  It also reconnects realtime on app resume and attaches the incoming-call coordinator after session hydrate.

### Outgoing call entry

- `lib/features/chat/presentation/view/chat_screen.dart`
  Direct 1:1 calls are launched from here.
  `VideoCallScreen` or `AudioCallScreen` is pushed for direct calls.
  `GroupVideoCallScreen` or `GroupAudioCallScreen` is pushed for group calls.

### Incoming call entry

- `lib/core/push/push_notification_controller.dart`
  Handles notification tap, accept, and decline.
- `lib/features/call/data/incoming_call_coordinator.dart`
  Handles in-app ringing state and navigation into the real call screen.

## File Responsibility Map

### Core wiring

- `lib/app.dart`
  App-level dependency wiring for calling.
- `lib/core/session/session_controller.dart`
  Supplies current user and session token.
- `lib/core/realtime/realtime_service.dart`
  Socket.IO connection, `onCallState`, `onCallSignal`, queued signaling while disconnected.
- `lib/features/call/data/calls_repository.dart`
  REST layer for `start`, `join`, `leave`, `end`, `ice-config`, and history.

### Direct 1:1 call runtime

- `lib/features/call/presentation/view/audio_call_screen.dart`
  Audio call UI route.
- `lib/features/call/presentation/view/video_call_screen.dart`
  Video call UI route.
- `lib/features/call/presentation/view_models/audio_call_view_model.dart`
  Audio call lifecycle, signaling, offer replay, ICE replay, hangup, tones.
- `lib/features/call/presentation/view_models/video_call_view_model.dart`
  Video call lifecycle, signaling, offer replay, ICE replay, hangup, local/remote renderers.
- `lib/features/call/data/web_rtc_call_session.dart`
  Peer connection wrapper for offer/answer, trickle ICE, media capture, remote stream, cached offer replay.

### Incoming ringing and notification bridge

- `lib/features/call/data/incoming_call_coordinator.dart`
  Most important incoming-call file.
  It buffers early offer/ICE, exposes ringing state, coordinates accept/decline, and opens the final call screen.
- `lib/features/call/presentation/widgets/incoming_call_overlay.dart`
  Foreground in-app incoming call banner.
- `lib/core/push/background_fcm_handler.dart`
  Background isolate storage fallback for notification payloads.
- `lib/core/push/fcm_notification_display.dart`
  Local notification builder for FCM payloads.
- `lib/core/push/push_notification_controller.dart`
  Reads pending notification actions, waits for realtime reconnect, starts pre-screen buffering, then asks the coordinator to accept.

### Android native incoming-call path

- `android/app/src/main/kotlin/com/shahir/titra/IncomingCallFirebaseMessagingService.kt`
  Receives `incoming_call` FCM while app is backgrounded or killed.
- `android/app/src/main/kotlin/com/shahir/titra/IncomingCallNotifier.kt`
  Shows full-screen incoming-call notification with Accept and Decline actions.
- `android/app/src/main/kotlin/com/shahir/titra/IncomingCallActivity.kt`
  Displays native full-screen UI and forwards accept/decline to Flutter by persisting payload and launching `MainActivity`.
- `android/app/src/main/kotlin/com/shahir/titra/IncomingCallNativeStore.kt`
  Saves pending notification payload/action into shared preferences.

### Group calling

- `lib/features/call/presentation/view/group_audio_call_screen.dart`
  Group audio UI.
- `lib/features/call/presentation/view/group_video_call_screen.dart`
  Group video UI.
- `lib/features/call/presentation/view_models/group_audio_call_view_model.dart`
  Group audio runtime.
- `lib/features/call/presentation/view_models/group_video_call_view_model.dart`
  Group video runtime.
- `lib/features/call/data/group_mesh_call_coordinator.dart`
  Mesh coordinator: one `WebRtcCallSession` per remote participant.
- `lib/features/call/data/group_mesh_media.dart`
  Media stream cloning/sharing for mesh calls.

### Support files

- `lib/features/call/data/active_call_guard.dart`
  Prevents multiple active call screens at once.
- `lib/features/call/data/incoming_call_ringtone.dart`
  In-app incoming ringtone.
- `lib/features/call/data/outgoing_ringback.dart`
  Outgoing ringback tone.
- `lib/features/call/data/call_end_tone.dart`
  End, missed, declined tone logic.
- `lib/features/call/presentation/view_models/calls_view_model.dart`
  Recent call history.
- `lib/features/call/data/call_history_entry.dart`
  Call history model.

## Direct 1:1 Flow

### Outgoing call

1. `chat_screen.dart` pushes `AudioCallScreen` or `VideoCallScreen`.
2. View model calls `CallsRepository.startCall()`.
3. View model creates `WebRtcCallSession`.
4. `WebRtcCallSession.startAsCaller()` creates the SDP offer and sends `call.signal`.
5. Callee receives `call.state started` and `call.signal offer`.
6. Caller waits for answer and trickle ICE.
7. Connection moves to connected and media starts.

### Incoming call while app is already open

1. `IncomingCallCoordinator` listens to `RealtimeService.onCallState`.
2. On `type=started`, it creates `IncomingRingingCall`.
3. If `offer` or `ice-candidate` arrives early, the coordinator buffers them.
4. UI shows `IncomingCallOverlay`.
5. When user accepts, the coordinator navigates to `AudioCallScreen` or `VideoCallScreen`.
6. The view model joins the call, consumes buffered offer/ICE, then starts the callee WebRTC flow.

### Incoming call from notification

1. Android native FCM service shows full-screen incoming UI.
2. Accept action stores payload/action and launches Flutter.
3. `PushNotificationController` loads the pending action.
4. It waits for realtime reconnect.
5. It starts `IncomingCallCoordinator.startPreScreenBuffering()` before the call screen opens.
6. It then calls `acceptFromPushData()`.
7. The view model consumes the accepted bootstrap data, joins the call, and starts as callee.
8. If the original offer was missed, the callee requests an offer replay from the caller.

## Group Call Flow

- Group calls use a full-mesh design.
- `GroupMeshCallCoordinator` creates one `WebRtcCallSession` per remote participant.
- Outgoing group calls call `startCall`, then `joinCall`, then send offers to each remote participant.
- Incoming group accept also goes through `IncomingCallCoordinator`, which fetches group conversation detail before opening the group call screen.

## Fixes Already Present In Code

These are the important issues that have already been addressed by the current implementation:

### 1. Early signaling is buffered

- If `call.signal offer` or `ice-candidate` arrives before `call.state started`, `IncomingCallCoordinator` stores it in `_earlyByCallSessionId`.
- This prevents race conditions caused by socket event ordering.

### 2. Pre-screen buffering exists for notification accept

- `PushNotificationController` starts pre-screen buffering before pushing the call screen.
- This captures offer/ICE that arrives during app wakeup, navigation, or permission prompts.

### 3. Accepted bootstrap data is merged safely

- `IncomingCallCoordinator` keeps accepted bootstrap data in `_acceptedByCallSessionId`.
- The audio/video view models consume this after their listeners are ready.
- This fixes the classic "accepted from notification but call never connects" race.

### 4. Callee offer recovery exists

- In direct audio/video calls, if the callee joins and still has no offer, the callee sends `offer-request`.
- The caller resends the cached offer and cached ICE through `WebRtcCallSession.resendLastOfferAndCachedIceOrCreate()`.

### 5. Outgoing offer replay exists

- Direct audio/video callers periodically replay the offer for a short time until the call connects.
- This improves reliability if the first offer was missed during cold start or reconnect.

### 6. Buffered ICE is replayed after remote description

- Audio/video view models store ICE that arrives before WebRTC callee bootstrap.
- After `startAsCallee()`, they replay that ICE.

## Known Gaps And Cleanup Items

These are not the main direct-call blocker anymore, but they are important to know:

### 1. iOS native CallKit path is not active

- `lib/features/call/data/native_call_ui.dart` is fully commented out.
- Current native incoming-call implementation is Android-focused.
- If true iOS CallKit / VoIP support is needed, this path still has to be wired back in.

### 2. Android foreground-call service is not active

- `lib/features/call/data/call_foreground_service.dart` is commented out.
- So the current system does not use an Android foreground service to keep active calls alive in background.

### 3. `CallControlBus` is present but not wired

- `lib/features/call/data/call_control_bus.dart` exists as a global hangup bus.
- No active usages were found in the current codebase.

### 4. Group calls do not have the same replay/recovery path as direct calls

- Direct audio/video calls have explicit `offer-request` replay handling.
- Group mesh flow currently does not show the same cold-start recovery mechanism.
- If group-call accept from killed state becomes unreliable, this is the first area to inspect.

## Fast Debug Path

If a direct call fails, check these files first in this order:

1. `lib/core/push/push_notification_controller.dart`
   Confirm notification accept reached `_acceptIncomingFromNotification()`.
2. `lib/features/call/data/incoming_call_coordinator.dart`
   Confirm offer/ICE buffering and `acceptFromPushData()` happened.
3. `lib/features/call/presentation/view_models/audio_call_view_model.dart`
   Direct audio runtime and offer recovery.
4. `lib/features/call/presentation/view_models/video_call_view_model.dart`
   Direct video runtime and offer recovery.
5. `lib/features/call/data/web_rtc_call_session.dart`
   Offer/answer, ICE, connection-state behavior.
6. `lib/core/realtime/realtime_service.dart`
   Socket reconnect and queued signaling.
7. `lib/features/call/data/calls_repository.dart`
   REST start/join/end and ICE config.

## Recommended Reading Order

If you need deeper understanding, read the files in this order:

1. `docs/CALLING_SYSTEM_OVERVIEW.md`
2. `docs/CALLING_ARCHITECTURE.md`
3. `docs/FIREBASE_CALL_SYSTEM.md`
4. `lib/app.dart`
5. `lib/core/push/push_notification_controller.dart`
6. `lib/features/call/data/incoming_call_coordinator.dart`
7. `lib/features/call/presentation/view_models/audio_call_view_model.dart`
8. `lib/features/call/presentation/view_models/video_call_view_model.dart`
9. `lib/features/call/data/web_rtc_call_session.dart`
