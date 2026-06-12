import 'package:flutter_webrtc/flutter_webrtc.dart';

/// Clones tracks into a new stream so each [RTCPeerConnection] can own its tracks (mesh).
Future<MediaStream> cloneMediaStreamForPeer(MediaStream source) async {
  final out = await createLocalMediaStream('mesh_${source.id}_${DateTime.now().microsecondsSinceEpoch}');
  for (final t in source.getTracks()) {
    final c = await t.clone();
    await out.addTrack(c);
  }
  return out;
}
