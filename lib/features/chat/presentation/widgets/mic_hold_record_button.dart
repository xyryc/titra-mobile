import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:titra/core/theme/app_colors.dart';

const Duration _kHoldDelay = Duration(milliseconds: 280);
const double _kCancelSlideDx = -56;

/// Mic control: short tap → [onShortTap]; hold → record with overlay, release → [onVoiceCommitted] unless slid left to cancel.
class MicHoldRecordButton extends StatefulWidget {
  const MicHoldRecordButton({
    super.key,
    required this.enabled,
    required this.busy,
    required this.onShortTap,
    required this.onVoiceCommitted,
    required this.onPermissionDenied,
  });

  final bool enabled;
  final bool busy;
  final VoidCallback onShortTap;
  final Future<void> Function(String filePath, int durationMs) onVoiceCommitted;
  final VoidCallback onPermissionDenied;

  @override
  State<MicHoldRecordButton> createState() => _MicHoldRecordButtonState();
}

class _MicHoldRecordButtonState extends State<MicHoldRecordButton> {
  final AudioRecorder _recorder = AudioRecorder();
  Timer? _holdTimer;
  bool _armed = false;
  bool _recording = false;
  bool _slideCancel = false;
  Offset? _pressLocalOrigin;
  OverlayEntry? _overlay;
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);
  final ValueNotifier<double> _level = ValueNotifier(0);
  Timer? _pulseTimer;
  Stopwatch? _stopwatch;

  @override
  void dispose() {
    _holdTimer?.cancel();
    _pulseTimer?.cancel();
    _removeOverlay();
    unawaited(_recorder.dispose());
    _elapsed.dispose();
    _level.dispose();
    super.dispose();
  }

  void _removeOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  Future<void> _requestMic() async {
    final status = await Permission.microphone.request();
    if (!status.isGranted && mounted) {
      widget.onPermissionDenied();
    }
  }

  Future<void> _startRecording() async {
    if (!widget.enabled || widget.busy || !mounted) return;
    await _requestMic();
    if (!mounted) return;
    if (!await Permission.microphone.isGranted) {
      return;
    }
    if (!await _recorder.hasPermission()) {
      widget.onPermissionDenied();
      return;
    }

    final dir = await getTemporaryDirectory();
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );

    if (!mounted) return;
    setState(() {
      _recording = true;
      _slideCancel = false;
    });
    _stopwatch = Stopwatch()..start();
    _elapsed.value = Duration.zero;
    _pulseTimer?.cancel();
    _pulseTimer = Timer.periodic(const Duration(milliseconds: 120), (_) async {
      if (!_recording || !mounted) return;
      _elapsed.value = _stopwatch?.elapsed ?? Duration.zero;
      try {
        final amp = await _recorder.getAmplitude();
        final cur = amp.current;
        final max = amp.max;
        final n = max > -20 ? ((cur - max).abs() / 40).clamp(0.0, 1.0) : 0.15;
        _level.value = n;
      } catch (_) {
        _level.value = 0.2;
      }
    });

    _overlay = OverlayEntry(
      builder: (ctx) => _RecordingOverlay(
        elapsed: _elapsed,
        level: _level,
        slideCancel: () => _slideCancel,
      ),
    );
    if (mounted) {
      Overlay.of(context).insert(_overlay!);
    }
  }

  Future<void> _stopRecording({required bool discard}) async {
    _holdTimer?.cancel();
    _holdTimer = null;
    _pulseTimer?.cancel();
    _pulseTimer = null;
    _removeOverlay();

    if (!_recording) {
      setState(() => _armed = false);
      return;
    }

    _recording = false;
    final sw = _stopwatch;
    _stopwatch = null;
    final ms = sw?.elapsedMilliseconds ?? 0;

    String? path;
    try {
      path = await _recorder.stop();
    } catch (_) {}

    if (mounted) setState(() => _armed = false);

    if (discard || path == null) {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      return;
    }

    if (ms < 600) {
      try {
        await File(path).delete();
      } catch (_) {}
      return;
    }

    await widget.onVoiceCommitted(path, ms);
  }

  void _onPointerDown(PointerDownEvent e) {
    if (!widget.enabled || widget.busy) return;
    _pressLocalOrigin = e.localPosition;
    _armed = true;
    _holdTimer?.cancel();
    _holdTimer = Timer(_kHoldDelay, () {
      if (_armed && mounted) {
        unawaited(_startRecording());
      }
    });
  }

  void _onPointerMove(PointerMoveEvent e) {
    if (!_recording || _pressLocalOrigin == null) return;
    final dx = e.localPosition.dx - _pressLocalOrigin!.dx;
    final next = dx < _kCancelSlideDx;
    if (next != _slideCancel) {
      setState(() => _slideCancel = next);
      _overlay?.markNeedsBuild();
    }
  }

  void _onPointerUp(PointerUpEvent e) {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (!_recording) {
      if (_armed) {
        widget.onShortTap();
      }
      _armed = false;
      return;
    }
    unawaited(_stopRecording(discard: _slideCancel));
  }

  void _onPointerCancel(PointerCancelEvent e) {
    _holdTimer?.cancel();
    _holdTimer = null;
    if (_recording) {
      unawaited(_stopRecording(discard: true));
    } else {
      _armed = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      onPointerUp: _onPointerUp,
      onPointerCancel: _onPointerCancel,
      child: Material(
        color: AppColors.primary,
        shape: const CircleBorder(),
        elevation: 2,
        child: SizedBox(
          width: 40,
          height: 40,
          child: widget.busy
              ? const Padding(
                  padding: EdgeInsets.all(10),
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.mic_rounded, color: Colors.white, size: 22),
        ),
      ),
    );
  }
}

class _RecordingOverlay extends StatelessWidget {
  const _RecordingOverlay({
    required this.elapsed,
    required this.level,
    required this.slideCancel,
  });

  final ValueNotifier<Duration> elapsed;
  final ValueNotifier<double> level;
  final bool Function() slideCancel;

  String _fmt(Duration d) {
    final s = d.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: IgnorePointer(
            child: ColoredBox(color: Colors.black.withValues(alpha: 0.45)),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: MediaQuery.paddingOf(context).bottom + 100,
          child: ValueListenableBuilder<Duration>(
            valueListenable: elapsed,
            builder: (context, d, _) {
              final cancel = slideCancel();
              return Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(20),
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            cancel ? Icons.cancel_rounded : Icons.mic_rounded,
                            color: cancel ? Colors.red : AppColors.primary,
                            size: 28,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            cancel ? 'Release to cancel' : 'Release to send',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: cancel ? Colors.red : const Color(0xFF334155),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            _fmt(d),
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                              fontFeatures: const [FontFeature.tabularFigures()],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      ValueListenableBuilder<double>(
                        valueListenable: level,
                        builder: (context, lv, _) {
                          return SizedBox(
                            height: 36,
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: List.generate(28, (i) {
                                final phase = (i / 28 * 6.28) + lv * 3.14;
                                final h = 8.0 + (lv * 28 * (0.5 + 0.5 * (1 + math.sin(phase)) / 2));
                                return Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 1),
                                    child: DecoratedBox(
                                      decoration: BoxDecoration(
                                        color: AppColors.primary.withValues(alpha: 0.35 + lv * 0.4),
                                        borderRadius: BorderRadius.circular(3),
                                      ),
                                      child: SizedBox(height: h.clamp(4, 36)),
                                    ),
                                  ),
                                );
                              }),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Slide left to cancel',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
