import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:titra/core/theme/app_colors.dart';

/// Inline play/pause + progress for a voice attachment (URL or local file path).
class VoiceMessageBar extends StatefulWidget {
  const VoiceMessageBar({
    super.key,
    required this.source,
    required this.durationMs,
    required this.isOutgoing,
  });

  /// `https://...` or absolute local file path.
  final String source;
  final int durationMs;
  final bool isOutgoing;

  @override
  State<VoiceMessageBar> createState() => _VoiceMessageBarState();
}

class _VoiceMessageBarState extends State<VoiceMessageBar> {
  late final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _posSub;
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _opening = false;
  String? _loadError;

  /// After natural completion, some platforms still report `playing == true`; use processingState too.
  bool get _isActivelyPlaying {
    final ps = _player.processingState;
    if (ps == ProcessingState.completed) return false;
    return _player.playing;
  }

  Duration get _total => _duration ?? Duration(milliseconds: widget.durationMs);

  Duration get _displayPosition {
    if (_player.processingState == ProcessingState.completed) {
      return _total;
    }
    return _position;
  }

  @override
  void initState() {
    super.initState();
    _duration = Duration(milliseconds: widget.durationMs);
    _player.durationStream.listen((d) {
      if (d != null && mounted) {
        setState(() => _duration = d);
      }
    });
    _player.processingStateStream.listen((ps) {
      if (!mounted) return;
      if (ps == ProcessingState.completed) {
        setState(() {
          _position = _total;
        });
      } else {
        setState(() {});
      }
    });
    _player.playerStateStream.listen((_) {
      if (mounted) setState(() {});
    });
    _posSub = _player.positionStream.listen((p) {
      if (mounted) setState(() => _position = p);
    });
  }

  Future<void> _toggle() async {
    if (_loadError != null) return;
    if (_opening) return;
    try {
      if (!_isActivelyPlaying) {
        _opening = true;
        final ps = _player.processingState;
        if (ps == ProcessingState.idle) {
          final s = widget.source;
          if (s.startsWith('http://') || s.startsWith('https://')) {
            await _player.setUrl(s);
          } else {
            await _player.setFilePath(s);
          }
        } else if (ps == ProcessingState.completed) {
          await _player.seek(Duration.zero);
        }
        await _player.play();
      } else {
        await _player.pause();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadError = 'Playback failed');
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    unawaited(_posSub?.cancel());
    unawaited(_player.dispose());
    super.dispose();
  }

  String _fmt(Duration d) {
    final s = d.inSeconds;
    final m = s ~/ 60;
    final r = s % 60;
    return '$m:${r.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final total = _total;
    final maxMs = total.inMilliseconds.clamp(1, 1 << 30);
    final disp = _displayPosition;
    final progress = (disp.inMilliseconds / maxMs).clamp(0.0, 1.0);
    final fg = widget.isOutgoing ? AppColors.onBackgroundLight : const Color(0xFF334155);
    final subtle = widget.isOutgoing ? fg.withValues(alpha: 0.75) : Colors.grey.shade600;

    if (_loadError != null) {
      return Text(_loadError!, style: TextStyle(fontSize: 13, color: fg));
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          onPressed: _toggle,
          icon: Icon(
            _isActivelyPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
            color: fg,
            size: 28,
          ),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 4,
                  backgroundColor: widget.isOutgoing
                      ? Colors.white.withValues(alpha: 0.35)
                      : Colors.grey.shade300,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    widget.isOutgoing ? fg : AppColors.primary,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_fmt(disp)} / ${_fmt(total)}',
                style: TextStyle(fontSize: 11, color: subtle, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
