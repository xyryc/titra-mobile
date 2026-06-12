import 'package:flutter/material.dart';

/// Messenger-style call status header for call screens.
/// Shows contact/group name, status dot + text, live duration, back button.
class CallStatusHeader extends StatelessWidget {
  const CallStatusHeader({
    super.key,
    required this.title,
    required this.statusText,
    required this.durationText,
    required this.isConnected,
    required this.isError,
    this.onBack,
    this.onMoreTap,
    this.darkStyle = false,
    this.actions,
  });

  final String title;
  final String statusText;
  final String durationText;
  final bool isConnected;
  final bool isError;
  final VoidCallback? onBack;
  final VoidCallback? onMoreTap;
  final bool darkStyle;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    final dotColor = isError
        ? Colors.red
        : isConnected
            ? const Color(0xFF22C68A)
            : Colors.amber;

    final bgColor = darkStyle ? Colors.transparent : Colors.white;
    final textColor = darkStyle ? Colors.white : const Color(0xFF0F1923);
    final subtextColor = darkStyle
        ? Colors.white.withValues(alpha: 0.7)
        : const Color(0xFF5C6878);

    return Container(
      color: bgColor,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 4,
        bottom: 4,
      ),
      child: Row(
        children: [
          if (onBack != null)
            IconButton(
              icon: Icon(
                Icons.arrow_back_rounded,
                color: textColor,
              ),
              onPressed: onBack,
            ),
          const SizedBox(width: 4),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: dotColor,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      durationText.isNotEmpty
                          ? '$statusText • $durationText'
                          : statusText,
                      style: TextStyle(
                        color: subtextColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ...?actions,
          ...[IconButton(
            icon: Icon(
              Icons.more_horiz_rounded,
              color: textColor,
            ),
            onPressed: onMoreTap,
          )],
        ],
      ),
    );
  }
}
