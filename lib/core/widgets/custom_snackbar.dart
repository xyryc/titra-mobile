import 'package:flutter/material.dart';

enum SnackbarType { success, error, info }

/// Global custom snackbar for success and error feedback.
class CustomSnackbar extends SnackBar {
  CustomSnackbar({
    required String message,
    required SnackbarType type,
    super.duration = const Duration(seconds: 3),
    super.key,
  }) : super(
          content: _SnackbarContent(message: message, type: type),
          backgroundColor: Colors.transparent,
          elevation: 0,
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(16),
          padding: EdgeInsets.zero,
        );
}

class _SnackbarContent extends StatelessWidget {
  const _SnackbarContent({required this.message, required this.type});

  final String message;
  final SnackbarType type;

  Color get _backgroundColor {
    switch (type) {
      case SnackbarType.success:
        return const Color(0xFF2E7D32); // green
      case SnackbarType.error:
        return const Color(0xFFC62828); // red
      case SnackbarType.info:
        return const Color(0xFF1565C0); // blue
    }
  }

  IconData get _icon {
    switch (type) {
      case SnackbarType.success:
        return Icons.check_circle_outline;
      case SnackbarType.error:
        return Icons.error_outline;
      case SnackbarType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(_icon, color: Colors.white, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
