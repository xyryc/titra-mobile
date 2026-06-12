# PiP / Overlay System — Titra Mobile

## সংক্ষেপ

Titra-তে তিনটি স্তরে overlay/PiP কাজ করে:

| স্তর | কোথায় দেখায় | কীভাবে কাজ করে |
|------|-------------|----------------|
| **App-level floating bubble** | App-এর ভেতরে অন্য screen-এ গেলে | Flutter `Stack` + `Positioned` |
| **Flutter overlay** | App চলাকালীন যেকোনো screen-এ | Flutter `OverlayEntry` (পরিকল্পিত) |
| **System-level overlay** | App background-এ গেলেও দেখায় | `SYSTEM_ALERT_WINDOW` + Android native |

---

## ১. App-level Floating Bubble (এখন কাজ করছে)

### ফাইল
```
lib/features/call/presentation/widgets/active_call_overlay.dart
```

### কীভাবে কাজ করে

```
MaterialApp
  └── builder: (context, child) => ActiveCallOverlay(child: child)
        └── Stack
              ├── child (আসল app content)
              └── Positioned (floating bubble) ← call active থাকলে দেখায়
```

**`app.dart`-এ integration:**
```dart
builder: (context, child) {
  return ActiveCallOverlay(
    child: child ?? const SizedBox.shrink(),
  );
},
```

### দেখানোর শর্ত
```dart
final bool shouldShow = active != null &&
                        currentRoute != '/video_call' &&
                        currentRoute != '/audio_call';
```
- `IncomingCallCoordinator.activeCall` != null মানে call চলছে
- User যদি call screen-এ না থাকে তাহলে bubble দেখায়

### Bubble UI
- Draggable — `onPanUpdate` দিয়ে screen-এর যেকোনো জায়গায় সরানো যায়
- Tap করলে call screen-এ ফিরে যায়
- Video call হলে নীল, audio হলে primary color
- "Return to call · `<contact name>`" লেখা

### Route tracking
```
lib/core/services/navigation_service.dart
lib/core/app_route_observer.dart
```
`NavigationService.currentRouteName` track করে বলে overlay জানে কোন screen-এ আছে।

---

## ২. SYSTEM_ALERT_WINDOW Permission

### AndroidManifest.xml-এ declared
```xml
<uses-permission android:name="android.permission.SYSTEM_ALERT_WINDOW"/>
```
**ফাইল:** `android/app/src/main/AndroidManifest.xml`

### এই permission কী করে
- Phone-এর **যেকোনো app-এর উপরে** window দেখাতে দেয়
- App background-এ গেলেও overlay থাকে
- Android 6.0+ এ user-কে manually enable করতে হয় (Settings → Apps → Special app access → Display over other apps)

### বর্তমান ব্যবহার
`flutter_callkit_incoming` এবং `flutter_background_service` package এই permission ব্যবহার করে:
- Incoming call notification-এ full-screen intent দেখাতে
- Background service চলাকালীন call UI দেখাতে

### Runtime permission check করার উপায়
```dart
import 'package:permission_handler/permission_handler.dart';

// Check
bool canOverlay = await Permission.systemAlertWindow.isGranted;

// Request (Settings page খুলে দেয়)
await Permission.systemAlertWindow.request();
```

---

## ৩. অন্যান্য Android Permissions (কী কী করা হয়েছে)

```xml
<!-- Background service চালাতে -->
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_MICROPHONE"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE_PHONE_CALL"/>

<!-- Call screen locked phone-এও দেখাতে -->
android:showWhenLocked="true"
android:turnScreenOn="true"

<!-- Full-screen notification (incoming call) -->
<uses-permission android:name="android.permission.USE_FULL_SCREEN_INTENT"/>

<!-- Background task -->
<uses-permission android:name="android.permission.WAKE_LOCK"/>
```

### Background Service
```
lib/features/call/data/call_foreground_service.dart
```
`flutter_background_service` দিয়ে foreground service চলে — call চলাকালীন app kill হলেও audio চালু থাকে।

---

## ৪. Call Flow সংক্ষেপ

```
Incoming FCM push
       ↓
IncomingCallFirebaseMessagingService (native Android)
       ↓
IncomingCallActivity (showWhenLocked + turnScreenOn)
       ↓
User accepts → Flutter IncomingCallCoordinator.activeCall = CallInfo
       ↓
ActiveCallOverlay bubble দেখায় (যদি call screen-এ না থাকে)
       ↓
User অন্য app-এ গেলে → CallForegroundService চলতে থাকে
```

---

## ৫. System-level Overlay যোগ করতে হলে (ভবিষ্যৎ)

App background-এ গেলেও bubble দেখাতে হলে Android native code দরকার:

**প্রয়োজনীয় steps:**
1. `SYSTEM_ALERT_WINDOW` runtime permission নিতে হবে
2. `WindowManager.addView()` দিয়ে system window যোগ করতে হবে
3. Flutter-এর সাথে `MethodChannel` দিয়ে communicate করতে হবে

**Package বিকল্প:**
- `flutter_overlay_window` — সহজ Flutter-based system overlay
- Custom native code — `android/app/src/main/kotlin/`-এ

---

## ৬. ফাইল রেফারেন্স সারণী

| উদ্দেশ্য | ফাইল |
|---------|------|
| App-level floating bubble | `lib/features/call/presentation/widgets/active_call_overlay.dart` |
| App.dart-এ overlay wrap | `lib/app.dart` (builder) |
| Route tracking | `lib/core/services/navigation_service.dart` |
| Call state management | `lib/features/call/data/incoming_call_coordinator.dart` |
| Background service | `lib/features/call/data/call_foreground_service.dart` |
| Android permissions | `android/app/src/main/AndroidManifest.xml` |
| Incoming call (native) | `android/app/src/main/kotlin/.../IncomingCallActivity` |
