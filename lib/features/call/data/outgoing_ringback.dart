import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Outgoing ringback: play [asset/calling.mp3], then **2.5s silence**, repeat until [stop].
///
/// Uses [just_audio] with Android [voiceCommunicationSignalling] so tone can play
/// while WebRTC holds the mic. Replace `asset/calling.mp3` with your own clip
/// (typically ~1s “ring”); silence between plays is fixed here for telephony-like cadence.
class OutgoingRingback {
  static const String _callingAsset = 'asset/calling.mp3';
  static const int _silenceMs = 2500;

  AudioPlayer? _player;
  bool _stopRequested = false;
  Future<void>? _cadenceTask;

  Future<void> start() async {
    if (kIsWeb) return;
    await stop();
    _stopRequested = false;

    final p = AudioPlayer();
    _player = p;
    try {
      await p.setAsset(_callingAsset);
      await p.setLoopMode(LoopMode.off);
      if (!kIsWeb && Platform.isAndroid) {
        await p.setAndroidAudioAttributes(
          const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.voiceCommunicationSignalling,
          ),
        );
      }
    } catch (e, st) {
      debugPrint('[OutgoingRingback] load $e\n$st');
      await p.dispose();
      _player = null;
      return;
    }

    _cadenceTask = _runCadence(p);
  }

  Future<void> _runCadence(AudioPlayer p) async {
    const step = Duration(milliseconds: 100);
    while (!_stopRequested) {
      try {
        await p.seek(Duration.zero);
        await p.play();
        await p.processingStateStream.firstWhere(
          (s) =>
              s == ProcessingState.completed ||
              s == ProcessingState.idle ||
              _stopRequested,
        );
        if (_stopRequested) break;

        var waited = 0;
        while (!_stopRequested && waited < _silenceMs) {
          await Future<void>.delayed(step);
          waited += step.inMilliseconds;
        }
      } catch (e, st) {
        debugPrint('[OutgoingRingback] cadence $e\n$st');
        break;
      }
    }
  }

  Future<void> stop() async {
    if (kIsWeb) return;
    _stopRequested = true;
    try {
      await _player?.stop();
    } catch (_) {}
    final t = _cadenceTask;
    _cadenceTask = null;
    if (t != null) {
      try {
        await t.timeout(const Duration(seconds: 3));
      } catch (_) {}
    }
    final p = _player;
    _player = null;
    if (p != null) {
      try {
        await p.dispose();
      } catch (_) {}
    }
  }
}
