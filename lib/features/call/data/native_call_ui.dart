// import 'dart:io';
//
// import 'package:flutter/foundation.dart';
// import 'package:flutter_callkit_incoming/entities/entities.dart';
// import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
//
// class NativeCallUi {
//   static const String incomingCallType = 'incoming_call';
//
//   static Map<String, String> normalizePayload(Map<dynamic, dynamic> raw) {
//     final data = <String, String>{};
//     raw.forEach((key, value) {
//       if (key == null || value == null) {
//         return;
//       }
//       data[key.toString()] = value.toString();
//     });
//
//     final sid = _firstNonEmpty(data, const ['callSessionId', 'call_id', 'id']);
//     if (sid != null) {
//       data['callSessionId'] = sid;
//     }
//
//     final conversationId = _firstNonEmpty(data, const [
//       'conversationId',
//       'conversation_id',
//     ]);
//     if (conversationId != null) {
//       data['conversationId'] = conversationId;
//     }
//
//     final initiatorUserId = _firstNonEmpty(data, const [
//       'initiatorUserId',
//       'caller_id',
//       'callerUserId',
//     ]);
//     if (initiatorUserId != null) {
//       data['initiatorUserId'] = initiatorUserId;
//     }
//
//     final initiatorName = _firstNonEmpty(data, const [
//       'initiatorName',
//       'caller_name',
//       'nameCaller',
//     ]);
//     if (initiatorName != null) {
//       data['initiatorName'] = initiatorName;
//     }
//
//     final initiatorAccountId = _firstNonEmpty(data, const [
//       'initiatorAccountId',
//       'caller_account_id',
//       'handle',
//       'number',
//     ]);
//     if (initiatorAccountId != null) {
//       data['initiatorAccountId'] = initiatorAccountId;
//     }
//
//     final isGroup = _firstNonEmpty(data, const ['isGroup', 'is_group']);
//     if (isGroup != null) {
//       data['isGroup'] = _boolToFlag(isGroup);
//     }
//
//     final existingCallType = _firstNonEmpty(data, const ['callType']);
//     if (existingCallType != null) {
//       data['callType'] = existingCallType.toUpperCase();
//     } else {
//       final isVideo = _firstNonEmpty(data, const ['is_video']);
//       final type = _firstNonEmpty(data, const ['type']);
//       if (isVideo != null) {
//         data['callType'] = _isTruthy(isVideo) ? 'VIDEO' : 'AUDIO';
//       } else if (type != null) {
//         data['callType'] = type == '1' ? 'VIDEO' : 'AUDIO';
//       }
//     }
//
//     data['type'] = incomingCallType;
//     return data;
//   }
//
//   static Map<String, String> payloadFromEventBody(dynamic body) {
//     if (body is! Map) {
//       return {};
//     }
//     final raw = Map<String, dynamic>.from(body);
//     final merged = <String, dynamic>{};
//     final extra = raw['extra'];
//     if (extra is Map) {
//       merged.addAll(Map<String, dynamic>.from(extra));
//     }
//     merged.addAll(raw);
//     return normalizePayload(merged);
//   }
//
//   static Future<void> showIncomingCall(Map<dynamic, dynamic> raw) async {
//     if (kIsWeb) {
//       return;
//     }
//     final data = normalizePayload(raw);
//     final sid = data['callSessionId'] ?? '';
//     if (sid.isEmpty) {
//       return;
//     }
//     try {
//       await FlutterCallkitIncoming.showCallkitIncoming(
//         _paramsForIncoming(data),
//       );
//     } catch (e, st) {
//       debugPrint('[NativeCallUi] showIncomingCall: $e\n$st');
//     }
//   }
//
//   static Future<void> dismissIncomingUi(String callSessionId) async {
//     if (kIsWeb || !Platform.isAndroid || callSessionId.isEmpty) {
//       return;
//     }
//     try {
//       await FlutterCallkitIncoming.hideCallkitIncoming(
//         CallKitParams(id: callSessionId),
//       );
//     } catch (e, st) {
//       debugPrint('[NativeCallUi] dismissIncomingUi: $e\n$st');
//     }
//   }
//
//   static Future<void> setConnected(String callSessionId) async {
//     if (kIsWeb || callSessionId.isEmpty) {
//       return;
//     }
//     try {
//       await FlutterCallkitIncoming.setCallConnected(callSessionId);
//     } catch (e, st) {
//       debugPrint('[NativeCallUi] setConnected: $e\n$st');
//     }
//   }
//
//   static Future<void> endCall(String callSessionId) async {
//     if (kIsWeb || callSessionId.isEmpty) {
//       return;
//     }
//     try {
//       await FlutterCallkitIncoming.endCall(callSessionId);
//     } catch (e, st) {
//       debugPrint('[NativeCallUi] endCall: $e\n$st');
//     }
//   }
//
//   static Future<String?> getVoipPushToken() async {
//     if (kIsWeb || !Platform.isIOS) {
//       return null;
//     }
//     try {
//       final token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();
//       final value = token?.toString();
//       if (value == null || value.isEmpty) {
//         return null;
//       }
//       return value;
//     } catch (e, st) {
//       debugPrint('[NativeCallUi] getVoipPushToken: $e\n$st');
//       return null;
//     }
//   }
//
//   static String? voipPushTokenFromEvent(dynamic body) {
//     if (body is! Map) {
//       return null;
//     }
//     final data = <String, String>{};
//     body.forEach((key, value) {
//       if (key == null || value == null) {
//         return;
//       }
//       data[key.toString()] = value.toString();
//     });
//     return _firstNonEmpty(data, const [
//       'deviceTokenVoIP',
//       'devicePushTokenVoIP',
//       'voipToken',
//       'token',
//     ]);
//   }
//
//   static bool isVideoPayload(Map<String, String> data) {
//     return (data['callType'] ?? 'AUDIO').toUpperCase() == 'VIDEO';
//   }
//
//   static CallKitParams _paramsForIncoming(Map<String, String> data) {
//     final sid = data['callSessionId']!;
//     final name = data['initiatorName'] ?? 'Unknown';
//     final handle = data['initiatorAccountId'] ?? data['initiatorUserId'] ?? '';
//     final isVideo = isVideoPayload(data);
//     return CallKitParams(
//       id: sid,
//       nameCaller: name,
//       appName: 'Titra',
//       handle: handle,
//       type: isVideo ? 1 : 0,
//       duration: 30000,
//       textAccept: 'Accept',
//       textDecline: 'Decline',
//       extra: Map<String, dynamic>.from(data),
//       missedCallNotification: const NotificationParams(
//         showNotification: true,
//         isShowCallback: false,
//         subtitle: 'Missed call',
//       ),
//       callingNotification: const NotificationParams(
//         showNotification: true,
//         isShowCallback: false,
//         subtitle: 'Connecting...',
//       ),
//       android: const AndroidParams(
//         isCustomNotification: true,
//         isShowLogo: false,
//         isShowCallID: false,
//         ringtonePath: 'system_ringtone_default',
//         backgroundColor: '#0A0A0A',
//         incomingCallNotificationChannelName: 'Incoming call',
//         missedCallNotificationChannelName: 'Missed call',
//         isShowFullLockedScreen: true,
//       ),
//       ios: IOSParams(
//         iconName: 'AppIcon',
//         handleType: 'generic',
//         supportsVideo: isVideo,
//         maximumCallGroups: 1,
//         maximumCallsPerCallGroup: 1,
//         audioSessionMode: 'voiceChat',
//         audioSessionActive: true,
//         audioSessionPreferredSampleRate: 44100.0,
//         audioSessionPreferredIOBufferDuration: 0.005,
//         supportsDTMF: false,
//         supportsHolding: false,
//         supportsGrouping: false,
//         supportsUngrouping: false,
//       ),
//     );
//   }
//
//   static String _boolToFlag(String value) {
//     return _isTruthy(value) ? '1' : '0';
//   }
//
//   static bool _isTruthy(String value) {
//     final normalized = value.trim().toLowerCase();
//     return normalized == '1' ||
//         normalized == 'true' ||
//         normalized == 'yes' ||
//         normalized == 'y';
//   }
//
//   static String? _firstNonEmpty(Map<String, String> data, List<String> keys) {
//     for (final key in keys) {
//       final value = data[key]?.trim();
//       if (value != null && value.isNotEmpty) {
//         return value;
//       }
//     }
//     return null;
//   }
// }
