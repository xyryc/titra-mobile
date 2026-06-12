import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titra/core/push/background_fcm_handler.dart';
import 'package:titra/core/push/fcm_notification_display.dart';
import 'package:titra/core/push/native_call_bridge.dart';
import 'package:titra/core/push/push_token_repository.dart';
import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/features/call/data/incoming_call_coordinator.dart';
import 'package:titra/features/call/presentation/view/incoming_call_screen.dart';
import 'package:titra/features/chat/presentation/view/chat_screen.dart';
import 'package:titra/firebase_options.dart';

/// Routes notification opens to chat / incoming-call overlay.
class PushNotificationController {
  PushNotificationController({
    required GlobalKey<NavigatorState> navigatorKey,
    required SessionController sessionController,
    required RealtimeService realtimeService,
    required PushTokenRepository pushTokenRepository,
  }) : _navigatorKey = navigatorKey,
       _session = sessionController,
       _realtime = realtimeService,
       _pushRepo = pushTokenRepository;

  final GlobalKey<NavigatorState> _navigatorKey;
  final SessionController _session;
  final RealtimeService _realtime;
  final PushTokenRepository _pushRepo;

  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;
  bool _isProcessingPending = false;
  static Map<String, String>? pendingOpen;

  /// Set when launching from a local notification action (e.g. Decline).
  static String? pendingOpenActionId;

  Future<void> _hydratePendingOpenFromSharedPrefs() async {
    if (pendingOpen != null) {
      debugPrint('[Push] pendingOpen already loaded, skipping cache hydrate');
      return;
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      if (Platform.isAndroid) {
        await prefs.reload();
      }

      if (!prefs.containsKey(kPendingNotificationPayloadKey)) {
        return;
      }

      final pl = prefs.getString(kPendingNotificationPayloadKey);
      final action = prefs.getString(kPendingNotificationActionKey);

      if (pl == null || pl.isEmpty) return;

      pendingOpen = Map<String, String>.from(jsonDecode(pl) as Map);
      pendingOpenActionId = action;

      await prefs.remove(kPendingNotificationPayloadKey);
      await prefs.remove(kPendingNotificationActionKey);

      debugPrint('[Push] loaded pending notification from cache (once only)');
    } catch (e, st) {
      debugPrint('[Push] hydrate pending notification failed: $e\n$st');
    }
  }

  Future<void> initialize() async {
    if (_initialized || kIsWeb) return;

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
      }
    } catch (e, st) {
      debugPrint('[Push] Firebase init failed (configure firebase_options.dart): $e\n$st',);
      return;
    }
    debugPrint('[Push] Firebase initialized for push');

    await _local.initialize(
      settings: InitializationSettings(
        android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwinInitSettingsForLocalNotifications(),
      ),
      onDidReceiveNotificationResponse: _onLocalNotificationTapped,
      onDidReceiveBackgroundNotificationResponse: onBackgroundNotificationResponse,
    );

    await ensureAndroidFcmNotificationChannels(_local);

    try {
      final launchDetails = await _local.getNotificationAppLaunchDetails();
      if (launchDetails?.didNotificationLaunchApp == true) {
        final rsp = launchDetails!.notificationResponse;
        final pl = rsp?.payload;
        if (pl != null && pl.isNotEmpty) {
          pendingOpen = Map<String, String>.from(jsonDecode(pl) as Map);
          pendingOpenActionId = rsp?.actionId;
          debugPrint(
            '[Push] launch from local notification type=${pendingOpen!['type']} action=$pendingOpenActionId',
          );
        }
      }
    } catch (_) {}

    if (pendingOpen == null) {
      if (Platform.isAndroid) {
        final nativePending = await NativeCallBridge.getPendingCall();
        if (nativePending != null) {
          pendingOpen = Map<String, String>.from(
            nativePending['payload'] as Map<String, String>,
          );
          pendingOpenActionId = nativePending['actionId'] as String?;
          debugPrint(
            '[Push] recovered pending call from native type=${pendingOpen!['type']} action=$pendingOpenActionId',
          );
        }
      }
    }

    if (pendingOpen == null) {
      await _hydratePendingOpenFromSharedPrefs();
      if (pendingOpen != null) {
        debugPrint(
          '[Push] launch from stored notification type=${pendingOpen!['type']} action=$pendingOpenActionId',
        );
      }
    }

    final fm = FirebaseMessaging.instance;

    if (Platform.isAndroid) {
      NativeCallBridge.installMethodCallHandler();
      NativeCallBridge.onIncomingCallAction.listen((data) {
        final payloadJson = data['payloadJson'] as String?;
        final actionId = data['actionId'] as String?;
        if (payloadJson != null) {
          try {
            final payload =
                Map<String, String>.from(jsonDecode(payloadJson) as Map);
            debugPrint(
              '[Push] Native call action received: action=$actionId payload.type=${payload['type']}',
            );

            // Stash it so consumePendingOpen (which is called on app-resume)
            // will definitely see it, even if we are still in the middle of resuming.
            pendingOpen = payload;
            pendingOpenActionId = actionId;

            // Trigger consumption immediately in case we're already foreground
            unawaited(consumePendingOpen());
          } catch (e, st) {
            debugPrint('[Push] Error handling native call action: $e\n$st');
          }
        }
      });
    }

    FirebaseMessaging.instance.onTokenRefresh.listen((t) {
      debugPrint(
        '[Push] FCM token refreshed prefix=${t.length > 12 ? t.substring(0, 12) : t}…',
      );
      unawaited(_registerToken(t));
    });

    FirebaseMessaging.onMessage.listen(_onForegroundRemoteMessage);

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      debugPrint(
        '[Push] onMessageOpenedApp messageId=${message.messageId} dataKeys=${message.data.keys.toList()}',
      );
      _routeFromRemoteMessage(message);
    });

    final initial = await fm.getInitialMessage();
    if (initial != null && pendingOpen == null) {
      pendingOpen = stringifyFcmData(initial.data);
      pendingOpenActionId = null;
      debugPrint(
        '[Push] getInitialMessage (cold start tap) dataKeys=${initial.data.keys.toList()}',
      );
    }

    _initialized = true;
    unawaited(_finishNotificationInitialization(fm));
    debugPrint('[Push] PushNotificationController.initialize() done');
  }

  Future<void> _finishNotificationInitialization(FirebaseMessaging fm) async {
    try {
      if (Platform.isAndroid) {
        await Permission.notification.request();
      }

      await fm.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      await fm.requestPermission(alert: true, badge: true, sound: true);

      try {
        final settings = await fm.getNotificationSettings();
        debugPrint(
          '[Push] notification settings authorization=${settings.authorizationStatus}',
        );
      } catch (e) {
        debugPrint('[Push] getNotificationSettings: $e');
      }
    } catch (e, st) {
      debugPrint('[Push] deferred notification init failed: $e\n$st');
    }
  }


  void _onLocalNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload == null || payload.isEmpty) return;
    try {
      final map = Map<String, String>.from(jsonDecode(payload) as Map);
      final type = map['type'] ?? '';
      final action = response.actionId;

      if (type == 'incoming_call') {
        if (action == kFcmCallAcceptActionId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _acceptIncomingFromNotification(map);
          });
          return;
        }
        if (action == kFcmCallDeclineActionId) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final ctx = _navigatorKey.currentContext;
            if (ctx == null) return;
            unawaited(
              ctx
                  .read<IncomingCallCoordinator>()
                  .declineIncomingFromNotification(map),
            );
          });
          return;
        }
        openFromData(map);
        return;
      }
      openFromData(map);
    } catch (_) {}
  }

  Future<void> onSessionBecameAuthenticated() async {
    if (!_initialized || kIsWeb) return;
    try {
      await _registerCurrentToken();
    } catch (_) {}
  }

  Future<void> _registerCurrentToken() async {
    if (_session.sessionToken == null) {
      debugPrint('[Push] skip getToken: no session yet');
      return;
    }

    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) return;

    final prefs = await SharedPreferences.getInstance();
    final savedToken = prefs.getString('last_fcm_token');

    if (savedToken == token) {
      debugPrint('[Push] FCM token already registered, skipping');
      return;
    }

    await _registerToken(token);

    await prefs.setString('last_fcm_token', token);
  }

  Future<void> _registerToken(String token) async {
    if (_session.sessionToken == null) return;
    try {
      await _pushRepo.registerFcmToken(
        fcmToken: token,
        clientDeviceId: _session.deviceId,
      );
    } catch (e, st) {
      debugPrint('[Push] register token failed: $e\n$st');
    }
  }

  void _onForegroundRemoteMessage(RemoteMessage message) {
    debugPrint(
      '[Push] onMessage (foreground) messageId=${message.messageId} '
      'hasNotification=${message.notification != null} data.type=${message.data['type']}',
    );
    if (message.data['type'] == 'incoming_call') {
      unawaited(showFcmMessageAsLocalNotification(_local, message));
    }
  }

  void _routeFromRemoteMessage(RemoteMessage message) {
    openFromData(stringifyFcmData(message.data));
  }

  /// Call when [MaterialApp] is up and session is ready (e.g. home after login).
  Future<void> consumePendingOpen() async {
    if (_isProcessingPending || !_initialized) return;

    if (pendingOpen == null) {
      await _consumePendingOpenFromStore();
      return;
    }
    await _consumePendingOpenNow();
  }

  Future<void> _consumePendingOpenFromStore() async {
    await _hydratePendingOpenFromSharedPrefs();
    await _consumePendingOpenNow();
  }

  void _retryPendingOpenSoon() {
    Future<void>.delayed(const Duration(milliseconds: 250), () {
      if (!_initialized) return;
      unawaited(consumePendingOpen());
    });
  }

  Future<void> _consumePendingOpenNow() async {
    if (_isProcessingPending) return;

    _isProcessingPending = true;

    final p = pendingOpen;
    final action = pendingOpenActionId;
    if (p == null) {
      _isProcessingPending = false;
      return;
    }

    // Clear IMMEDIATELY to prevent race conditions
    pendingOpen = null;
    pendingOpenActionId = null;

    if (p['type'] == 'incoming_call' && action == kFcmCallAcceptActionId) {
      await _runAfterFrame(() async {
        await _acceptIncomingFromNotification(p);
      });
      _isProcessingPending = false;
      return;
    }

    if (p['type'] == 'incoming_call' && action == kFcmCallDeclineActionId) {
      await _runAfterFrame(() async {
        final ctx = _navigatorKey.currentContext;
        if (ctx == null) {
          pendingOpen = p;
          pendingOpenActionId = action;
          _isProcessingPending = false;
          _retryPendingOpenSoon();
          return;
        }
        final coordinator = Provider.of<IncomingCallCoordinator>(
          ctx,
          listen: false,
        );
        await cancelIncomingCallNotification(_local, p);
        if (Platform.isAndroid) {
          unawaited(NativeCallBridge.clearPendingCall());
        }
        await coordinator.declineIncomingFromNotification(p);
        _isProcessingPending = false;
      });
      return;
    }

    if (p['type'] == 'incoming_call') {
      await _runAfterFrame(() async {
        final ctx = _navigatorKey.currentContext;
        final nav = _navigatorKey.currentState;
        if (ctx == null || nav == null) {
          pendingOpen = p;
          pendingOpenActionId = null;
          _isProcessingPending = false;
          _retryPendingOpenSoon();
          return;
        }
        final coordinator = Provider.of<IncomingCallCoordinator>(
          ctx,
          listen: false,
        );
        try {
          await cancelIncomingCallNotification(_local, p);
          coordinator.presentFromPushData(p);
          if (Platform.isAndroid) {
            unawaited(NativeCallBridge.clearPendingCall());
          }
          await nav.push<void>(
            MaterialPageRoute<void>(
              builder: (_) => IncomingCallScreen(payload: p),
            ),
          );
        } catch (e, st) {
          debugPrint('[Push] incoming_call presentFromPushData: $e\n$st');
        } finally {
          _isProcessingPending = false;
        }
      });
      return;
    }

    openFromData(p);
    _isProcessingPending = false;
  }

  Future<void> _runAfterFrame(FutureOr<void> Function() action) {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await action();
        completer.complete();
      } catch (e, st) {
        completer.completeError(e, st);
      }
    });
    return completer.future;
  }


  Future<void> _acceptIncomingFromNotification(Map<String, String> data) async {
    if (_navigatorKey.currentContext == null) {
      pendingOpen = data;
      pendingOpenActionId = kFcmCallAcceptActionId;
      _retryPendingOpenSoon();
      return;
    }
    try {
      await cancelIncomingCallNotification(_local, data);
      
      // Trigger reconnection in the background but do NOT await it.
      // The call screen's view model will handle waiting for it during bootstrap.
      final token = _session.sessionToken;
      if (token != null && token.isNotEmpty) {
        _realtime.reconnectIfNeeded(token);
      }

      final ctx = _navigatorKey.currentContext!;
      // ignore: use_build_context_synchronously
      final coordinator = Provider.of<IncomingCallCoordinator>(ctx, listen: false);
      final callSessionId = data['callSessionId'] ?? '';

      // Start buffering signals NOW, before the screen is pushed.
      // Any offer/ICE that arrives between here and ViewModel init is captured.
      if (callSessionId.isNotEmpty) {
        coordinator.startPreScreenBuffering(callSessionId, _realtime);
      }

      await coordinator.acceptFromPushData(data);
      if (Platform.isAndroid) {
        await NativeCallBridge.notifyCallHandled();
      }
    } catch (e, st) {
      debugPrint('[Push] incoming_call accept action failed: $e\n$st');
    }
  }

  void openFromData(Map<String, String> data) {
    if (_session.sessionToken == null) {
      pendingOpen = data;
      return;
    }

    final nav = _navigatorKey.currentState;
    if (nav == null) {
      pendingOpen = data;
      return;
    }

    final type = data['type'] ?? '';
    if (type == 'chat_message') {
      final convId = data['conversationId'] ?? '';
      if (convId.isEmpty) return;
      final senderName = data['senderName'] ?? 'Chat';
      final accountId = data['senderAccountId'] ?? '';
      final peerUserId = data['peerUserId'] ?? '';
      final isGroup = data['isGroup'] == '1';
      nav.pushAndRemoveUntil<void>(
        MaterialPageRoute<void>(
          builder: (_) => ChatScreen(
            conversationId: convId,
            contactName: senderName,
            contactId: accountId.isNotEmpty ? accountId : peerUserId,
            avatarUrl: null,
            isGroup: isGroup,
            peerUserId: peerUserId.isNotEmpty ? peerUserId : null,
            openedFromNotification: true,
          ),
        ),
          (route) => route.isFirst,
      );
      return;
    }

    if (type == 'incoming_call') {
      final ctx = _navigatorKey.currentContext;
      final nav = _navigatorKey.currentState;
      if (ctx != null && nav != null) {
        try {
          unawaited(cancelIncomingCallNotification(_local, data));
          ctx.read<IncomingCallCoordinator>().presentFromPushData(data);
          unawaited(
            nav.push<void>(
              MaterialPageRoute<void>(
                builder: (_) => IncomingCallScreen(payload: data),
              ),
            ),
          );
          if (Platform.isAndroid) {
            unawaited(NativeCallBridge.clearPendingCall());
          }
        } catch (e, st) {
          debugPrint('[Push] incoming_call route: $e\n$st');
        }
      } else {
        pendingOpen = data;
      }
    }
  }
}
