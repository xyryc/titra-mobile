import 'dart:io' show Platform;

import 'package:audio_session/audio_session.dart';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

const String _callEndAsset = 'asset/callEnd.mp3';

/// Whether to play [asset/callEnd.mp3] when the **remote** ends an **outgoing** call
/// before media was established (missed / declined / peer left while ringing).
bool shouldPlayCallEndedTone({
  required bool isOutgoing,
  required bool wasCallConnected,
  String? remoteEndReason,
}) {
  if (!isOutgoing || wasCallConnected) return false;
  switch (remoteEndReason) {
    case 'no_answer':
    case 'declined':
    case 'peer_left':
      return true;
    default:
      return false;
  }
}

/// Plays [asset/callEnd.mp3] once (await until finished or error).
Future<void> playCallEndedTone() async {
  if (kIsWeb) return;
  final p = AudioPlayer();
  try {
    await p.setAsset(_callEndAsset);
    if (!kIsWeb && Platform.isAndroid) {
      await p.setAndroidAudioAttributes(
        const AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.voiceCommunicationSignalling,
        ),
      );
    }
    await p.play();
    await p.processingStateStream.firstWhere(
      (s) => s == ProcessingState.completed || s == ProcessingState.idle,
    );
  } catch (e, st) {
    debugPrint('[CallEndTone] $e\n$st');
  } finally {
    try {
      await p.dispose();
    } catch (_) {}
  }
}
