import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// Android channel IDs — must match backend FCM `android.notification.channelId`.
const String kFcmChannelMessagesId = 'titra_messages';
const String kFcmChannelCallsId = 'titra_calls';

/// Registered in [DarwinInitializationSettings] and must match backend APNS `category`.
const String kIncomingCallCategoryId = 'INCOMING_CALL';

const String kFcmCallAcceptActionId = 'fcm_call_accept';
const String kFcmCallDeclineActionId = 'fcm_call_decline';

final List<DarwinNotificationCategory> kDarwinIncomingCallCategories = [
  DarwinNotificationCategory(
    kIncomingCallCategoryId,
    actions: <DarwinNotificationAction>[
      DarwinNotificationAction.plain(
        kFcmCallAcceptActionId,
        'Accept',
        options: const <DarwinNotificationActionOption>{
          DarwinNotificationActionOption.foreground,
        },
      ),
      DarwinNotificationAction.plain(
        kFcmCallDeclineActionId,
        'Decline',
        options: const <DarwinNotificationActionOption>{
          DarwinNotificationActionOption.foreground,
          DarwinNotificationActionOption.destructive,
        },
      ),
    ],
  ),
];

const AndroidNotificationChannel kFcmChannelMessages = AndroidNotificationChannel(
  kFcmChannelMessagesId,
  'Messages',
  description: 'New chat messages',
  importance: Importance.high,
);

const AndroidNotificationChannel kFcmChannelCalls = AndroidNotificationChannel(
  kFcmChannelCallsId,
  'Calls',
  description: 'Incoming calls',
  importance: Importance.max,
  sound: RawResourceAndroidNotificationSound('ringtone'),
  playSound: true,
  enableVibration: true,
);

/// FCM `data` map values must be strings for tap routing / JSON payload.
Map<String, String> stringifyFcmData(Map<String, dynamic> data) {
  return data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
}

int notificationIdForFcmMessage(RemoteMessage message) {
  return (message.messageId ?? '${message.hashCode}').hashCode.abs() % 2000000000;
}

/// Stable id per call so updates replace the same tray entry.
int notificationIdForIncomingCallSession(Map<String, String> data) {
  final sid = data['callSessionId'] ?? '';
  if (sid.isEmpty) {
    return 911000001;
  }
  return sid.hashCode & 0x7fffffff;
}

Future<void> cancelIncomingCallNotification(
  FlutterLocalNotificationsPlugin plugin,
  Map<String, String> data,
) async {
  final sid = data['callSessionId'] ?? '';
  if (sid.isEmpty) return;
  try {
    await plugin.cancel(id: notificationIdForIncomingCallSession(data));
  } catch (e, st) {
    debugPrint('[Push] cancel incoming_call local notification failed: $e\n$st');
  }
}

Future<void> ensureAndroidFcmNotificationChannels(
  FlutterLocalNotificationsPlugin plugin,
) async {
  if (!Platform.isAndroid) return;
  final android = plugin.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(kFcmChannelMessages);
  await android?.createNotificationChannel(kFcmChannelCalls);
}

DarwinInitializationSettings darwinInitSettingsForLocalNotifications() {
  return DarwinInitializationSettings(
    notificationCategories: kDarwinIncomingCallCategories,
  );
}

/// When [forBackgroundIsolate] is true on Android, skip local show if FCM already
/// carries a [RemoteMessage.notification] — **except** for [incoming_call], which must
/// always show this actionable notification (Accept / Decline).
Future<void> showFcmMessageAsLocalNotification(
  FlutterLocalNotificationsPlugin plugin,
  RemoteMessage message, {
  bool forBackgroundIsolate = false,
}) async {
  final data = stringifyFcmData(message.data);
  final type = data['type'] ?? '';
  debugPrint(
    '[Push] showFcmMessageAsLocalNotification type=$type '
    'forBackgroundIsolate=$forBackgroundIsolate hasRemoteNotification=${message.notification != null}',
  );

  if (forBackgroundIsolate &&
      Platform.isAndroid &&
      type != 'incoming_call' &&
      message.notification != null &&
      (((message.notification!.title ?? '').isNotEmpty) ||
          ((message.notification!.body ?? '').isNotEmpty))) {
    return;
  }

  final n = message.notification;

  String title;
  String body;
  if (n != null &&
      ((n.title ?? '').isNotEmpty || (n.body ?? '').isNotEmpty)) {
    title = (n.title ?? '').isNotEmpty
        ? n.title!
        : (type == 'incoming_call' ? 'Incoming call' : 'Titra');
    body = n.body ?? '';
  } else if (type == 'incoming_call') {
    title = (data['alertTitle'] ?? '').isNotEmpty
        ? data['alertTitle']!
        : 'Incoming call';
    final name = data['initiatorName'] ?? 'Someone';
    body = (data['alertBody'] ?? '').isNotEmpty
        ? data['alertBody']!
        : '$name is calling';
  } else if (type == 'chat_message') {
    title = (data['senderName'] ?? '').isNotEmpty ? data['senderName']! : 'Titra';
    body = 'New message';
  } else {
    title = 'Titra';
    body = (n?.body ?? '').isNotEmpty ? n!.body! : '';
  }

  final int nid = type == 'incoming_call'
      ? notificationIdForIncomingCallSession(data)
      : notificationIdForFcmMessage(message);

  try {
  if (type == 'incoming_call') {
    final androidDetails = AndroidNotificationDetails(
      kFcmChannelCalls.id,
      kFcmChannelCalls.name,
      channelDescription: kFcmChannelCalls.description,
      importance: Importance.max,
      priority: Priority.max,
      category: AndroidNotificationCategory.call,
      fullScreenIntent: true,
      sound: const RawResourceAndroidNotificationSound('ringtone'),
      playSound: true,
      enableVibration: true,
      ongoing: true,
      autoCancel: false,
      actions: const <AndroidNotificationAction>[
        AndroidNotificationAction(
          kFcmCallAcceptActionId,
          'Accept',
          showsUserInterface: true,
          cancelNotification: true,
          semanticAction: SemanticAction.call,
        ),
        AndroidNotificationAction(
          kFcmCallDeclineActionId,
          'Decline',
          showsUserInterface: true,
          cancelNotification: true,
          semanticAction: SemanticAction.delete,
        ),
      ],
    );
    const iosDetails = DarwinNotificationDetails(
      categoryIdentifier: kIncomingCallCategoryId,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );
    await plugin.show(
    id: nid,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    ),
    payload: jsonEncode(data),
    );
    debugPrint('[Push] incoming_call local notification shown id=$nid');
    return;
  }

  final androidDetails = AndroidNotificationDetails(
    kFcmChannelMessages.id,
    kFcmChannelMessages.name,
    channelDescription: kFcmChannelMessages.description,
    importance: Importance.high,
    priority: Priority.high,
  );

  await plugin.show(
    id: nid,
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: androidDetails,
      iOS: const DarwinNotificationDetails(),
    ),
    payload: jsonEncode(data),
  );
  debugPrint('[Push] chat/other local notification shown id=$nid type=$type');
  } catch (e, st) {
    debugPrint('[Push] showFcmMessageAsLocalNotification failed: $e\n$st');
  }
}
