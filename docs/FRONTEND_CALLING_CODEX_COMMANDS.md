# Flutter Calling Implementation Guide (for this backend)

This is the frontend implementation spec for calling.  
Chat already works; this document covers how to add reliable audio/video calling.

## 1) Backend contract to implement

### Auth
- Send `x-session-token` on all calling REST requests.
- Use same token in Socket.IO handshake for `/realtime`.

### REST endpoints
- `POST /calls/start`
- `POST /calls/join`
- `POST /calls/leave`
- `POST /calls/end`
- `GET /calls/ice-config`
- `GET /calls/history?limit=...`
- `GET /calls/:conversationId/active`

### Socket events
- Listen: `call.state`
- Send/receive signaling: `call.signal`

## 2) Flutter module design

Create a dedicated `calls` feature with:

1. Data layer
- `CallsApiClient`
- `CallsSocketClient`
- `WebRtcService`
- DTO mappers

2. Domain layer
- `CallSession`
- `CallParticipant`
- `CallStatus` enum (`idle`, `dialing`, `ringing`, `connecting`, `active`, `ending`, `ended`, `failed`)
- `CallSignal` model (`offer`, `answer`, `ice-candidate`)

3. Application layer
- `CallController` (single source of truth)
- Handles REST + socket + WebRTC lifecycle

4. Presentation layer
- `IncomingCallScreen`
- `OutgoingCallScreen`
- `ActiveCallScreen`
- small reusable widgets (local/remote video, controls, timer)

## 3) Core call flows

### Outgoing call
1. User taps call button in conversation.
2. Call `POST /calls/start` with `conversationId` + call type.
3. Fetch ICE config from `GET /calls/ice-config`.
4. Create RTCPeerConnection with ICE servers.
5. Capture local media and add tracks.
6. Create offer and emit via `call.signal`.
7. Move UI state: `dialing -> ringing -> connecting -> active`.
8. On hangup, call `POST /calls/end`, then cleanup media/peer connection/listeners.

### Incoming call
1. Receive `call.state` indicating ringing for current user.
2. Show incoming UI once (dedupe by `callSessionId`).
3. Accept:
- `POST /calls/join`
- setup peer connection + local media
- process offer/answer exchange with `call.signal`
- enter `active`
4. Decline:
- call `POST /calls/end` (reason declined)
- cleanup and return to previous screen.

### Reconnect / cold start recovery
1. On app resume/socket reconnect/open from push:
- query `GET /calls/:conversationId/active`
2. If active/ringing session exists:
- rebuild call UI state from server response
- reattach socket signaling
- rejoin flow when needed
3. If none exists:
- ensure any local stale call state is cleared.

## 4) WebRTC signaling rules

Use `call.signal` payload containing:
- `conversationId`
- `callSessionId`
- target + sender identity (if needed by your payload contract)
- SDP or ICE candidate

Handling:
1. If signal type is `offer`: set remote description, create answer, send answer.
2. If signal type is `answer`: set remote description.
3. If signal type is `ice-candidate`: add candidate to peer connection.
4. Ignore signals for unknown/ended `callSessionId`.

## 5) State machine (must-have)

Allowed transitions:
1. `idle -> dialing`
2. `dialing -> ringing | connecting | failed | ended`
3. `ringing -> connecting | ended`
4. `connecting -> active | failed | ended`
5. `active -> ending | ended`
6. `ending -> ended`
7. `failed -> ended | idle`
8. `ended -> idle`

All UI rendering should derive from this state only.

## 6) Push integration requirements

1. Register FCM token after login and refresh via:
- `PUT /users/me/push-token`
2. On incoming call push:
- open call route with `conversationId` + `callSessionId`
- reconnect socket
- validate server-side active call before showing full UI
3. Dedupe repeated push notifications by `callSessionId`.

## 7) Reliability requirements

1. Cleanup on every end path:
- stop local tracks
- dispose renderers
- close RTCPeerConnection once
- unregister socket listeners
2. Prevent duplicate screens/listeners:
- keep per-session registry in controller
3. Timeout handling:
- if no answer/connection progress within threshold, move to ended/failed
4. Error handling:
- show user-friendly failure state, never leave loading forever

## 8) Minimum test plan

1. Start call success/failure
2. Incoming accept flow
3. Incoming decline flow
4. Signal deduplication and wrong-session ignore
5. Reconnect recovery from active call
6. Teardown always disposes media/pc/listeners
7. Route guard prevents two active call screens

## 9) Done definition

Calling implementation is done when:
1. 1:1 audio/video calls work on two devices.
2. Incoming ringing works both foreground and resume path.
3. Reconnect can recover an active call.
4. Hangup/decline always clears local resources.
5. No regression in existing chat flow.
