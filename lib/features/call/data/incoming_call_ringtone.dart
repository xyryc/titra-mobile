import 'dart:async';
import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

/// Loops [asset/ringtone.mp3] for incoming audio/video calls until [stop].
class IncomingCallAssetRingtone {
  static const String _asset = 'asset/ringtone.mp3';

  AudioPlayer? _player;
  // Incremented on every stop() so an in-flight start() knows to abort.
  int _generation = 0;

  Future<void> start() async {
    if (kIsWeb) return;
    // Cancel any previous player without awaiting (avoids the future-chain crash).
    _disposePlayer(_player);
    _player = null;
    _generation++;
    final gen = _generation;

    final p = AudioPlayer();
    _player = p;
    try {
      await p.setAsset(_asset);
      if (gen != _generation) { _disposePlayer(p); return; }
      await p.setLoopMode(LoopMode.one);
      if (gen != _generation) { _disposePlayer(p); return; }
      if (!kIsWeb && Platform.isAndroid) {
        await p.setAndroidAudioAttributes(
          const AndroidAudioAttributes(
            contentType: AndroidAudioContentType.sonification,
            usage: AndroidAudioUsage.voiceCommunicationSignalling,
          ),
        );
        if (gen != _generation) { _disposePlayer(p); return; }
      }
      await p.play();
    } catch (e, st) {
      debugPrint('[IncomingCallRingtone] $e\n$st');
      if (gen == _generation) _player = null;
      _disposePlayer(p);
    }
  }

  Future<void> stop() async {
    _generation++;
    _disposePlayer(_player);
    _player = null;
  }

  /// Fire-and-forget dispose — deferred so any in-flight futures on [p] can
  /// settle before the platform channel is torn down.
  void _disposePlayer(AudioPlayer? p) {
    if (p == null) return;
    Future<void>.delayed(const Duration(milliseconds: 200), () async {
      try { await p.dispose(); } catch (_) {}
    });
  }
}
