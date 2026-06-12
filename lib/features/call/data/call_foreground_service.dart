import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_callkit_incoming/entities/entities.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class BackgroundCallInfo {
  const BackgroundCallInfo({
    required this.callSessionId,
    required this.callerName,
    required this.handle,
    required this.isVideo,
    this.isOutgoing = false,
    this.extra = const <String, dynamic>{},
  });

  final String callSessionId;
  final String callerName;
  final String handle;
  final bool isVideo;
  final bool isOutgoing;
  final Map<String, dynamic> extra;
}

class CallForegroundService {
  static const int _notificationId = 1001;
  static bool _configured = false;

  static Future<void> initialize() async {
    if (_configured || kIsWeb || !Platform.isAndroid) {
      return;
    }

    final service = FlutterBackgroundService();
    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: _androidBackgroundCallEntryPoint,
        autoStart: false,
        isForegroundMode: true,
        initialNotificationTitle: 'Call in progress',
        initialNotificationContent: 'Titra call audio is active',
        foregroundServiceNotificationId: _notificationId,
        autoStartOnBoot: false,
        foregroundServiceTypes: const [
          AndroidForegroundType.microphone,
          AndroidForegroundType.phoneCall,
        ],
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: _androidBackgroundCallEntryPoint,
        onBackground: _iosBackgroundFallback,
      ),
    );
    _configured = true;
  }

  static Future<void> start({
    required String callerName,
    required bool isVideo,
  }) async {
    await startBackgroundCall(
      BackgroundCallInfo(
        callSessionId: 'android-active-call',
        callerName: callerName,
        handle: callerName,
        isVideo: isVideo,
      ),
    );
  }

  static Future<void> stop() => stopBackgroundCall();

  static Future<void> updateNotification(String text) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await initialize();
    FlutterBackgroundService().invoke('update', {'content': text});
  }

  static Future<void> updateTimer(String duration) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    await initialize();
    FlutterBackgroundService().invoke('updateTimer', {'duration': duration});
  }
}

Future<void> startBackgroundCall(BackgroundCallInfo info) async {
  if (kIsWeb || info.callSessionId.isEmpty) {
    return;
  }

  if (Platform.isAndroid) {
    await CallForegroundService.initialize();
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
    service.invoke('startCall', {
      'title': 'Call with ${info.callerName}',
      'content': info.isVideo
          ? 'Video call in progress'
          : 'Audio call in progress',
    });
    return;
  }

  if (Platform.isIOS) {
    await _startOrConnectIosCall(info);
  }
}

Future<void> stopBackgroundCall({String? callSessionId}) async {
  if (kIsWeb) {
    return;
  }

  if (Platform.isAndroid) {
    FlutterBackgroundService().invoke('stopCall');
    Future.delayed(const Duration(milliseconds: 500), () {
      FlutterLocalNotificationsPlugin().cancel(id: 1001);
    });
    return;
  }

  if (Platform.isIOS) {
    try {
      if (callSessionId != null && callSessionId.isNotEmpty) {
        await FlutterCallkitIncoming.endCall(callSessionId);
      } else {
        await FlutterCallkitIncoming.endAllCalls();
      }
    } catch (e, st) {
      debugPrint('[CallForegroundService] stop iOS CallKit: $e\n$st');
    }
  }
}

Future<void> _startOrConnectIosCall(BackgroundCallInfo info) async {
  try {
    final activeCalls = await FlutterCallkitIncoming.activeCalls();
    final hasExistingCall = activeCalls.any(
      (call) => call.id == info.callSessionId,
    );

    if (!hasExistingCall) {
      final params = CallKitParams(
        id: info.callSessionId,
        nameCaller: info.callerName,
        appName: 'Titra',
        handle: info.handle,
        type: info.isVideo ? 1 : 0,
        extra: info.extra,
        ios: IOSParams(
          iconName: 'AppIcon',
          handleType: 'generic',
          supportsVideo: info.isVideo,
          maximumCallGroups: 1,
          maximumCallsPerCallGroup: 1,
          audioSessionMode: 'voiceChat',
          audioSessionActive: true,
          audioSessionPreferredSampleRate: 44100.0,
          audioSessionPreferredIOBufferDuration: 0.005,
          supportsDTMF: false,
          supportsHolding: false,
          supportsGrouping: false,
          supportsUngrouping: false,
        ),
      );

      if (info.isOutgoing) {
        await FlutterCallkitIncoming.startCall(params);
      } else {
        await FlutterCallkitIncoming.showCallkitIncoming(params);
      }
    }

    await FlutterCallkitIncoming.setCallConnected(info.callSessionId);
  } catch (e, st) {
    debugPrint('[CallForegroundService] start iOS CallKit: $e\n$st');
  }
}

@pragma('vm:entry-point')
Future<bool> _iosBackgroundFallback(ServiceInstance service) async {
  return true;
}

@pragma('vm:entry-point')
void _androidBackgroundCallEntryPoint(ServiceInstance service) async {
  String currentTitle = 'Call in progress';
  String currentContent = 'Titra call audio is active';

  if (service is AndroidServiceInstance) {
    await service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: currentTitle,
      content: currentContent,
    );
  }

  service.on('startCall').listen((event) {
    if (service is! AndroidServiceInstance) {
      return;
    }
    currentTitle = event?['title']?.toString() ?? 'Call in progress';
    currentContent = event?['content']?.toString() ?? 'Titra call audio is active';
    service.setForegroundNotificationInfo(
      title: currentTitle,
      content: currentContent,
    );
  });

  service.on('update').listen((event) {
    if (service is! AndroidServiceInstance) {
      return;
    }
    currentContent = event?['content']?.toString() ?? 'Titra call audio is active';
    service.setForegroundNotificationInfo(
      title: currentTitle,
      content: currentContent,
    );
  });

  service.on('updateTimer').listen((event) {
    if (service is! AndroidServiceInstance) {
      return;
    }
    final duration = event?['duration']?.toString() ?? '';
    if (duration.isEmpty) return;
    service.setForegroundNotificationInfo(
      title: currentTitle,
      content: duration,
    );
  });

  service.on('stopCall').listen((_) {
    service.stopSelf();
  });
}
