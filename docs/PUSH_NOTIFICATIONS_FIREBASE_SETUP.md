# Push notifications (Firebase Cloud Messaging)

This guide covers **Firebase Console**, **Apple push (APNs)**, **Android**, the **Nest backend** (`PushService`), and how **device tokens** are registered from the Flutter app. In-app chat and Titra voice/video calls use the same FCM pipeline.

## 1. Firebase project

1. Open [Firebase Console](https://console.firebase.google.com/) and create or select a project.
2. Link a **Google Cloud** billing project if prompted (FCM uses Google infrastructure).
3. Enable **Firebase Cloud Messaging API** for that Google Cloud project (APIs & Services → enable **Firebase Cloud Messaging API** / legacy FCM as applicable).

## 2. Android app in Firebase

1. In Firebase: **Project settings** → **Your apps** → Add app → **Android**.
2. **Android package name** must match the app id in Gradle, for example `com.shahir.titra` (see `titra-mobile/android/app/build.gradle.kts`, `applicationId`).
3. Download **`google-services.json`** and place it under `titra-mobile/android/app/` (FlutterFire default).
4. Regenerate Flutter config:

   ```bash
   dart pub global activate flutterfire_cli
   cd titra-mobile
   flutterfire configure
   ```

   This updates `lib/firebase_options.dart`. Until values match your project, Firebase init may fail at runtime.

5. **Android 13+**: the app requests the notification permission at runtime; users must allow notifications for banners to appear.

6. **Optional**: if you use Firebase **Phone Auth** or Play Integrity, add your app’s **SHA-256** fingerprints in Firebase Console → Project settings → Your Android app.

## 3. iOS app in Firebase

1. Add an **iOS** app in Firebase with the **same bundle identifier** as Xcode (`Runner` target).
2. Download **`GoogleService-Info.plist`** into `titra-mobile/ios/Runner/`.
3. Run `flutterfire configure` from `titra-mobile` so `firebase_options.dart` includes the iOS app.

### Xcode

1. Open `titra-mobile/ios/Runner.xcworkspace`.
2. **Signing & Capabilities** → add **Push Notifications**.
3. **Background Modes** → enable **Remote notifications** (the repo’s `Info.plist` already lists `remote-notification`; the capability must match in Xcode).

### APNs key → Firebase

1. [Apple Developer](https://developer.apple.com/account) → **Certificates, Identifiers & Profiles** → **Keys** → create a key with **Apple Push Notifications service (APNs)**.
2. Download the **`.p8`** file once; note **Key ID** and **Team ID**.
3. Firebase → **Project settings** → **Cloud Messaging** → **Apple app configuration** → upload the APNs Authentication Key (`.p8`), Key ID, Team ID, and bundle ID.

Without this step, iOS devices will not receive FCM-delivered pushes reliably.

## 4. Backend (Nest) — Firebase Admin

The API sends multicast FCM from `titra-backend/src/push/push.service.ts` using the Firebase Admin SDK.

1. Firebase Console → **Project settings** → **Service accounts** → **Generate new private key** → save as JSON (keep secret; do not commit).
2. On the server, either:
   - Set **`FIREBASE_SERVICE_ACCOUNT_PATH`** to the absolute path of that JSON file, or  
   - Set **`FIREBASE_SERVICE_ACCOUNT_JSON`** to the **raw JSON string** of the service account (useful on PaaS).
3. If neither is set, the backend also looks for **`FIREBASE_SERVICE_ACCOUNT.json`** in the process working directory (see `titra-backend/.env.example`).

When Admin is not configured, `PushService.isEnabled()` is false and no pushes are sent (no crash).

## 5. Device registration (mobile)

- The user must be **logged in** so the app can call the backend **push token** endpoint (see `PushTokenRepository` and `UsersController` `PUT .../push-token` in the backend).
- After login, `PushNotificationController` registers the FCM token with the API.

## 6. Notification behavior (reference)

| Scenario | Behavior |
|----------|----------|
| **Foreground** | `FirebaseMessaging.onMessage` shows a **local** notification (same channels as below). |
| **Background / killed (Android)** | FCM may show a system notification; a **background isolate** may run and show a **local** notification for **data-only** messages, or when the system does not surface the FCM `notification` payload (see `background_fcm_handler.dart`). |
| **Tap** | Payload is routed to **chat** or **incoming call** UI (`PushNotificationController.openFromData`, `IncomingCallCoordinator.presentFromPushData`). Cold start from a **local** notification uses `getNotificationAppLaunchDetails`; from an **FCM** notification uses `getInitialMessage`. |

**Android channels** (must stay aligned with backend):

- `titra_messages` — chat.
- `titra_calls` — incoming calls.

Backend sets `android.notification.channelId` accordingly. Calls also set APNs `sound` and **`interruption-level`: `time-sensitive`** for iOS 15+ (subject to App Store policy for your app category).

## 7. Testing matrix

Test on **real devices** when possible (simulators have limited push behavior).

1. **Foreground**: app open; send chat message / start call; expect banner + tap opens chat or ringing UI.
2. **Background**: Home button; repeat.
3. **Force quit**: swipe away app; repeat; delivery depends on **OS + OEM** (some vendors delay or block FCM after force-stop until the user opens the app again).
4. **iOS vs Android** for both `chat_message` and `incoming_call` payload types.

Do not expect instant delivery if the user has disabled notifications, revoked background activity, or used **force stop** on some Android OEMs.

## 8. Out of scope

- **Carrier SMS** (not the same as in-app chat).
- **CallKit** / **PushKit** native incoming-call UI (separate from FCM).
