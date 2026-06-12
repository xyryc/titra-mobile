import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:titra/features/call/data/incoming_call_coordinator.dart';
import 'package:titra/features/call/presentation/view_models/audio_call_view_model.dart';
import 'package:titra/features/call/presentation/view_models/group_audio_call_view_model.dart';
import 'package:titra/features/call/presentation/view_models/group_video_call_view_model.dart';
import 'package:titra/features/call/presentation/view_models/video_call_view_model.dart';

/// Global overlay bar at [MaterialApp.builder] level.
/// Shows a Messenger-style green bar when a call is active but the
/// full call screen is not currently visible.
class CallStatusOverlay extends StatefulWidget {
  const CallStatusOverlay({super.key, required this.child});

  final Widget child;

  @override
  State<CallStatusOverlay> createState() => _CallStatusOverlayState();
}

class _CallStatusOverlayState extends State<CallStatusOverlay> {
  Timer? _durationTimer;
  String _duration = '';
  IncomingCallCoordinator? _coordinator;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final coord = Provider.of<IncomingCallCoordinator>(context);
    if (_coordinator != coord) {
      _coordinator?.removeListener(_handleCoordinatorChanged);
      _coordinator = coord;
      _coordinator?.addListener(_handleCoordinatorChanged);
      _handleCoordinatorChanged();
    }
  }

  @override
  void dispose() {
    _coordinator?.removeListener(_handleCoordinatorChanged);
    _durationTimer?.cancel();
    super.dispose();
  }

  void _handleCoordinatorChanged() {
    final coord = _coordinator;
    if (coord == null) return;

    final active = coord.activeCall;
    final show = active != null && !coord.isCallScreenVisible;

    if (show && _durationTimer == null) {
      _startDurationUpdates(coord);
    } else if (!show && _durationTimer != null) {
      _stopDurationUpdates();
    }
  }

  void _startDurationUpdates(IncomingCallCoordinator coord) {
    _durationTimer?.cancel();
    _updateDuration(coord);
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) _updateDuration(coord);
    });
  }

  void _stopDurationUpdates() {
    _durationTimer?.cancel();
    _durationTimer = null;
    if (mounted) {
      setState(() {
        _duration = '';
      });
    }
  }

  void _updateDuration(IncomingCallCoordinator coord) {
    final vm = coord.activeViewModel;
    final duration = switch (vm) {
      AudioCallViewModel v => v.durationFormatted,
      VideoCallViewModel v => v.durationFormatted,
      GroupAudioCallViewModel v => v.durationFormatted,
      GroupVideoCallViewModel v => v.durationFormatted,
      _ => '',
    };
    if (_duration != duration) {
      setState(() => _duration = duration);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<IncomingCallCoordinator>(
      builder: (context, coord, _) {
        final active = coord.activeCall;
        final show = active != null && !coord.isCallScreenVisible;

        return Column(
          children: [
            if (show)
              _CallStatusBar(
                contactName: active.contactName,
                isVideo: active.isVideo,
                duration: _duration,
                onTap: () => coord.restoreActiveCallFromOverlay(),
              ),
            Expanded(child: widget.child),
          ],
        );
      },
    );
  }
}

class _CallStatusBar extends StatelessWidget {
  const _CallStatusBar({
    required this.contactName,
    required this.isVideo,
    required this.duration,
    required this.onTap,
  });

  final String contactName;
  final bool isVideo;
  final String duration;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: GestureDetector(
        onTap: onTap,
        onVerticalDragEnd: (details) {
          // Swipe up to restore call screen
          if (details.primaryVelocity != null &&
              details.primaryVelocity! < -300) {
            onTap();
          }
        },
        child: Container(
          color: const Color(0xFF22C68A),
          child: SafeArea(
            bottom: false,
            child: Container(
              height: 48,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      isVideo
                          ? Icons.videocam_rounded
                          : Icons.phone_in_talk_rounded,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          contactName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.none,
                          ),
                        ),
                        Text(
                          duration.isNotEmpty ? 'On call • $duration' : 'On call',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.85),
                            fontSize: 11,
                            fontWeight: FontWeight.w500,
                            decoration: TextDecoration.none,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_up_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
