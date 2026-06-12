import 'dart:io';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class NativeCallOverlayManager {
  NativeCallOverlayManager._();
  static final NativeCallOverlayManager instance = NativeCallOverlayManager._();

  /// Checks and requests "Display over other apps" permission.
  Future<bool> checkAndRequestPermission() async {
    if (!Platform.isAndroid) return false;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (granted) return true;
    return await FlutterOverlayWindow.requestPermission() ?? false;
  }

  /// Activates the native system overlay window.
  Future<void> show({
    String? callSessionId,
    String? callerName,
    String? duration,
    bool? isVideo,
    String? avatarUrl,
    bool? isMuted,
  }) async {
    if (!Platform.isAndroid) return;
    final granted = await FlutterOverlayWindow.isPermissionGranted();
    if (!granted) return;

    final active = await FlutterOverlayWindow.isActive();
    if (!active) {
      await FlutterOverlayWindow.showOverlay(
        height: 500,
        width: 400,
        alignment: OverlayAlignment.centerRight,
        flag: OverlayFlag.defaultFlag,
        enableDrag: true,

        positionGravity: PositionGravity.none,
        visibility: NotificationVisibility.visibilityPublic,
        overlayTitle: callerName?.isNotEmpty == true
            ? 'Call with $callerName'
            : 'Titra active call',
        overlayContent: duration?.isNotEmpty == true
            ? 'Tap to return • $duration'
            : 'Tap to return to call',
      );
    }

    await FlutterOverlayWindow.shareData({
      'action': 'update_call_overlay',
      'callSessionId': callSessionId ?? '',
      'callerName': callerName ?? '',
      'duration': duration ?? '',
      'isVideo': isVideo == true ? '1' : '0',
      'avatarUrl': avatarUrl ?? '',
      'isMuted': isMuted == true ? '1' : '0',
    });
  }

  /// Dismisses the native system overlay window.
  Future<void> dismiss() async {
    if (!Platform.isAndroid) return;
    if (await FlutterOverlayWindow.isActive()) {
      await FlutterOverlayWindow.closeOverlay();
    }
  }

  /// Action to signal the main app to bring itself to foreground.
  static void signalLaunchApp() {
    FlutterOverlayWindow.shareData({'action': 'return_to_call'});
  }
}
