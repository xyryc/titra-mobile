import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titra/core/push/fcm_notification_display.dart';
import 'package:titra/firebase_options.dart';

const String kPendingNotificationPayloadKey = 'pending_notification_payload';
const String kPendingNotificationActionKey = 'pending_notification_action';

/// Called when the user taps a notification while the app is in the background
/// (background isolate context — must be a top-level function).
@pragma('vm:entry-point')
void onBackgroundNotificationResponse(NotificationResponse response) async {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString(kPendingNotificationPayloadKey, payload);
  if (response.actionId != null) {
    await prefs.setString(kPendingNotificationActionKey, response.actionId!);
  } else {
    await prefs.remove(kPendingNotificationActionKey);
  }
}

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  final type = message.data['type']?.toString();
  debugPrint(
    '[Push] background FCM handler messageId=${message.messageId} '
    'data.type=$type',
  );
  if (Platform.isAndroid && type == 'incoming_call') {
    debugPrint('[Push] Android incoming_call handled by native FCM service');
    return;
  }
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  }

  final plugin = FlutterLocalNotificationsPlugin();
  await plugin.initialize(
    settings: InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: darwinInitSettingsForLocalNotifications(),
    ),
    onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationResponse,
  );
  await ensureAndroidFcmNotificationChannels(plugin);
  await showFcmMessageAsLocalNotification(
    plugin,
    message,
    forBackgroundIsolate: true,
  );
  debugPrint('[Push] background FCM handler finished');
}
