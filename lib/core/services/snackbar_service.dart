import 'package:flutter/material.dart';

import '../widgets/SuccessBar/successbar.dart';
import '../widgets/custom_snackbar.dart';

/// Global error and success handler. Shows custom snackbars via [ScaffoldMessenger].
/// Must be initialized with [init] from the app (e.g. after MaterialApp is built)
/// or by providing [navigatorKey] so we can get context.
class SnackbarService {
  SnackbarService({GlobalKey<NavigatorState>? navigatorKey})
    : _navigatorKey = navigatorKey;

  final GlobalKey<NavigatorState>? _navigatorKey;

  BuildContext? get _context => _navigatorKey?.currentContext;

  void showSuccess(String message, {Duration? duration}) {
    _show(message: message, type: SnackbarType.success, duration: duration);
  }

  void showFloatingSuccess(String message, {Duration? duration}) {
    final ctx = _context;
    if (ctx == null) return;
    FloatingSuccessBar.show(
      ctx,
      message: message,
    );
  }

  void showError(String message, {Duration? duration}) {
    _show(message: message, type: SnackbarType.error, duration: duration);
  }

  void showInfo(String message, {Duration? duration}) {
    _show(message: message, type: SnackbarType.info, duration: duration);
  }

  void _show({
    required String message,
    required SnackbarType type,
    Duration? duration,
  }) {
    final ctx = _context;
    if (ctx == null) return;
    ScaffoldMessenger.of(ctx).clearSnackBars();
    ScaffoldMessenger.of(ctx).showSnackBar(
      CustomSnackbar(
        message: message,
        type: type,
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
}
