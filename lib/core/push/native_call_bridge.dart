// lib/core/push/native_call_bridge.dart

import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Bridges Flutter ↔ native Android for incoming-call lifecycle events.
///
/// Two paths exist for the minimised-state "Accept" flow:
///   1. Native pushes `onIncomingCallAction` immediately via [setMethodCallHandler]
///      (fast path — used when the Flutter engine is already alive).
///   2. Flutter polls via [getPendingCall] on every app-resume (fallback path).
class NativeCallBridge {
  static const MethodChannel _channel =
      MethodChannel('com.shahir.titra/call_lifecycle');

  // Streams the payload+actionId sent by native via invokeMethod.
  static final StreamController<Map<String, dynamic>> _incomingCallActionController =
      StreamController<Map<String, dynamic>>.broadcast();

  static bool _handlerInstalled = false;

  /// Call once during app startup to begin receiving native-push events.
  static void installMethodCallHandler() {
    if (_handlerInstalled) return;
    _handlerInstalled = true;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onIncomingCallAction') {
        final args = call.arguments;
        if (args is Map) {
          _incomingCallActionController.add(Map<String, dynamic>.from(args));
        }
      }
    });
  }

  /// Stream of incoming call actions pushed directly from native (fast path).
  static Stream<Map<String, dynamic>> get onIncomingCallAction =>
      _incomingCallActionController.stream;

  // Get pending call from native (with stale-check)
  static Future<Map<String, dynamic>?> getPendingCall() async {
    try {
      final result = await _channel.invokeMethod<Map>('getPendingCall');
      if (result == null || result['payloadJson'] == null) return null;

      final payload = jsonDecode(result['payloadJson'] as String) as Map;
      return {
        'payload': Map<String, String>.from(payload),
        'actionId': result['actionId'] as String?,
        'timestamp': result['timestamp'] as int?,
      };
    } catch (e, st) {
      debugPrint('[NativeCallBridge] getPendingCall failed: $e\n$st');
      return null;
    }
  }

  // Notify native that Flutter has handled the call
  static Future<void> notifyCallHandled() async {
    try {
      await _channel.invokeMethod('onCallHandled');
    } catch (e, st) {
      debugPrint('[NativeCallBridge] notifyCallHandled failed: $e\n$st');
    }
  }

  // Clear pending call from native storage
  static Future<void> clearPendingCall() async {
    try {
      await _channel.invokeMethod('clearPendingCall');
    } catch (e, st) {
      debugPrint('[NativeCallBridge] clearPendingCall failed: $e\n$st');
    }
  }
}