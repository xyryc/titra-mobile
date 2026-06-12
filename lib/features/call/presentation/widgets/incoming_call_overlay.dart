import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/features/call/data/incoming_call_coordinator.dart';

/// Full-width banner when [IncomingCallCoordinator.ringing] is non-null.
class IncomingCallOverlay extends StatelessWidget {
  const IncomingCallOverlay({super.key, required this.child});

  final Widget child;

  static String _initial(String? name) {
    if (name == null) return '?';
    final t = name.trim();
    if (t.isEmpty) return '?';
    return t[0].toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        Consumer<IncomingCallCoordinator>(
          builder: (context, coord, _) {
            final r = coord.ringing;
            if (r == null) return const SizedBox.shrink();
            final title = r.isVideo ? 'Incoming video call' : 'Incoming call';
            final subtitle = r.callerName ?? 'Someone';
            final hasPhoto =
                r.callerAvatarUrl != null && r.callerAvatarUrl!.isNotEmpty;

            return Material(
              color: Colors.black54,
              child: SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Material(
                      elevation: 8,
                      borderRadius: BorderRadius.circular(16),
                      color: Theme.of(context).colorScheme.surface,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 32,
                                  backgroundColor: AppColors.primary.withValues(alpha: 0.12),
                                  backgroundImage:
                                      hasPhoto ? NetworkImage(r.callerAvatarUrl!) : null,
                                  child: !hasPhoto
                                      ? Text(
                                          _initial(r.callerName),
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.primary,
                                          ),
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.onBackgroundLight,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        subtitle,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey.shade900,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton(
                                    onPressed: () => coord.decline(),
                                    child: const Text('Decline'),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: FilledButton(
                                    onPressed: () => coord.accept(),
                                    child: const Text('Accept'),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
