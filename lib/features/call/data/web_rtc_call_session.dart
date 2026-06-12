import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

/// 1:1 WebRTC session: offer/answer + trickle ICE via [sendSignal] callback.
class WebRtcCallSession {
  WebRtcCallSession({
    required this.callSessionId,
    required this.conversationId,
    required this.peerUserId,
    required this.myUserId,
    required this.video,
    required this.iceServers,
    this.preferSpeakerOutput = true,
    required Future<void> Function(
      String signalType,
      Map<String, dynamic> payload,
    )
    sendSignal,
    this.mediaStream,
  }) : _sendSignal = sendSignal,
       _ownsLocalTracks = mediaStream == null;

  /// If set, used instead of [getUserMedia] (mesh: clone per peer).
  final MediaStream? mediaStream;
  final bool _ownsLocalTracks;

  final String callSessionId;
  final String conversationId;
  final String peerUserId;
  final String myUserId;
  final bool video;
  final List<Map<String, dynamic>> iceServers;

  /// iOS: maps to voice vs video chat audio mode; should match default speaker intent.
  final bool preferSpeakerOutput;
  final Future<void> Function(String signalType, Map<String, dynamic> payload)
  _sendSignal;

  RTCPeerConnection? _pc;
  MediaStream? _local;
  MediaStream? _remote;

  MediaStream? get localStream => _local;
  MediaStream? get remoteStream => _remote;

  final _pendingRemoteIce = <RTCIceCandidate>[];
  bool _remoteDescSet = false;
  Map<String, dynamic>? _lastLocalOfferPayload;
  final List<Map<String, dynamic>> _cachedLocalIcePayloads = [];
  Completer<bool>? _pendingConnectionWait;
  bool _localTracksAttachedToCurrentPc = false;

  final _remoteStreamController = StreamController<MediaStream>.broadcast();
  Stream<MediaStream> get onRemoteStream => _remoteStreamController.stream;

  final _connectionEstablishedController = StreamController<void>.broadcast();

  /// Fires once when [RTCPeerConnectionState] becomes connected (media path ready).
  Stream<void> get onConnectionEstablished =>
      _connectionEstablishedController.stream;

  final _connectionFailedController = StreamController<void>.broadcast();

  /// Fires once when the peer connection fails (e.g. ICE / DTLS).
  Stream<void> get onConnectionFailed => _connectionFailedController.stream;

  bool _establishedEventSent = false;
  bool _failedEventSent = false;
  bool _disposeRequested = false;

  bool get hasPendingLocalOffer =>
      _lastLocalOfferPayload != null && !_remoteDescSet;

  Map<String, dynamic> get _pcConfig => {
    'iceServers': iceServers,
    'sdpSemantics': 'unified-plan',
    'bundlePolicy': 'max-bundle',
    'rtcpMuxPolicy': 'require',
    // Helps when UDP is filtered; pool size >0 can interact badly with trickle timing on some devices.
    'tcpCandidatePolicy': 'enabled',
  };

  static void logIceConfigDebug(List<Map<String, dynamic>> servers) {
    if (!kDebugMode) return;
    final n = servers.length;
    final summary = servers
        .map((e) {
          final urls = e['urls'];
          final hasCreds = e['username'] != null || e['credential'] != null;
          String urlStr;
          if (urls is List) {
            urlStr = urls.map((x) => x?.toString() ?? '').join(', ');
          } else {
            urlStr = urls?.toString() ?? '';
          }
          return '$urlStr${hasCreds ? ' (TURN)' : ''}';
        })
        .join(' | ');
    debugPrint('[WebRtc] iceServers count=$n: $summary');
  }

  Map<String, dynamic> get _sdpConstraints => {
    'mandatory': {'OfferToReceiveAudio': true, 'OfferToReceiveVideo': video},
    'optional': <dynamic>[],
  };

  Future<void> _emitIce(RTCIceCandidate? c) async {
    if (c == null || c.candidate == null || c.candidate!.isEmpty) return;
    final payload = <String, dynamic>{
      'candidate': c.candidate,
      'sdpMid': c.sdpMid,
      'sdpMLineIndex': c.sdpMLineIndex,
    };
    final signature =
        '${payload['candidate']}|${payload['sdpMid']}|${payload['sdpMLineIndex']}';
    final exists = _cachedLocalIcePayloads.any((item) {
      final itemSignature =
          '${item['candidate']}|${item['sdpMid']}|${item['sdpMLineIndex']}';
      return itemSignature == signature;
    });
    if (!exists) {
      _cachedLocalIcePayloads.add(Map<String, dynamic>.from(payload));
    }
    await _sendSignal('ice-candidate', payload);
  }

  Future<void> _initPc() async {
    if (_pc != null) return;
    WebRtcCallSession.logIceConfigDebug(iceServers);
    _pc = await createPeerConnection(_pcConfig);
    _localTracksAttachedToCurrentPc = false;
    _pc!.onIceCandidate = (c) {
      unawaited(_emitIce(c));
    };
    _pc!.onTrack = (RTCTrackEvent e) {
      unawaited(_handleInboundTrack(e));
    };
    _pc!.onIceConnectionState = (RTCIceConnectionState s) {
      debugPrint('[WebRtc] iceConnectionState=$s');
      if (s == RTCIceConnectionState.RTCIceConnectionStateConnected ||
          s == RTCIceConnectionState.RTCIceConnectionStateCompleted) {
        _emitConnectionEstablished('ice:$s');
      } else if (s == RTCIceConnectionState.RTCIceConnectionStateFailed) {
        _emitConnectionFailed();
      }
    };
    _pc!.onConnectionState = (RTCPeerConnectionState s) {
      debugPrint('[WebRtc] connectionState=$s');
      if (s == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _emitConnectionEstablished('pc:$s');
      } else if (s == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _emitConnectionFailed();
      }
    };
  }

  void _emitConnectionEstablished(String source) {
    debugPrint('[WebRtc] established source=$source');
    if (!_establishedEventSent && !_connectionEstablishedController.isClosed) {
      _establishedEventSent = true;
      _connectionEstablishedController.add(null);
    }
    final completer = _pendingConnectionWait;
    if (completer != null && !completer.isCompleted) {
      completer.complete(true);
    }
  }

  void _emitConnectionFailed() {
    if (!_disposeRequested &&
        !_failedEventSent &&
        !_connectionFailedController.isClosed) {
      _failedEventSent = true;
      _connectionFailedController.add(null);
    }
    final completer = _pendingConnectionWait;
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
  }

  Future<void> _configurePlatformAudio() async {
    if (kIsWeb) return;
    try {
      if (WebRTC.platformIsAndroid) {
        await Helper.setAndroidAudioConfiguration(
          AndroidAudioConfiguration.communication,
        );
      } else if (WebRTC.platformIsIOS) {
        await Helper.setAppleAudioIOMode(
          AppleAudioIOMode.localAndRemote,
          preferSpeakerOutput: preferSpeakerOutput,
        );
        await Helper.ensureAudioSession();
      }
    } catch (e, st) {
      debugPrint('[WebRtc] audio configuration: $e\n$st');
    }
  }

  Future<void> _handleInboundTrack(RTCTrackEvent e) async {
    late final MediaStream stream;
    if (e.streams.isNotEmpty) {
      stream = e.streams.first;
    } else {
      try {
        stream = await createLocalMediaStream('remote_inbound');
        await stream.addTrack(e.track, addToNative: false);
      } catch (err, st) {
        debugPrint('[WebRtc] inbound track (no stream): $err\n$st');
        return;
      }
    }
    _remote = stream;
    _emitConnectionEstablished('remote-track');
    if (!_remoteStreamController.isClosed) {
      _remoteStreamController.add(stream);
    }
  }

  Future<void> _ensureLocalMedia() async {
    await _configurePlatformAudio();
    if (_local != null) {
      await _attachLocalTracksToCurrentPc();
      return;
    }
    if (mediaStream != null) {
      _local = mediaStream;
      await _attachLocalTracksToCurrentPc();
      return;
    }
    final constraints = <String, dynamic>{
      'audio': true,
      'video': video
          ? {
              'facingMode': 'user',
              'width': {'ideal': 640, 'max': 1280},
              'height': {'ideal': 480, 'max': 720},
              'frameRate': {'ideal': 30, 'max': 30},
            }
          : false,
    };
    _local = await navigator.mediaDevices.getUserMedia(constraints);
    await _attachLocalTracksToCurrentPc();
  }

  Future<void> _attachLocalTracksToCurrentPc() async {
    if (_pc == null || _local == null || _localTracksAttachedToCurrentPc) {
      return;
    }
    for (final t in _local!.getTracks()) {
      await _pc!.addTrack(t, _local!);
    }
    _localTracksAttachedToCurrentPc = true;
  }

  Future<void> prepareLocalMedia() async {
    await _initPc();
    await _ensureLocalMedia();
  }

  Future<void> startAsCaller() async {
    await _initPc();
    await _ensureLocalMedia();
    final offer = await _pc!.createOffer(_sdpConstraints);
    await _pc!.setLocalDescription(offer);

    final payload = <String, dynamic>{'sdp': offer.sdp, 'type': offer.type};
    _lastLocalOfferPayload = Map<String, dynamic>.from(payload);
    await _sendSignal('offer', payload);
  }

  Future<void> resendLastOfferOrCreate() async {
    final cached = _lastLocalOfferPayload;
    if (cached != null && cached.isNotEmpty) {
      await _sendSignal('offer', Map<String, dynamic>.from(cached));
      return;
    }
    await startAsCaller();
  }

  Future<void> resendLastOfferAndCachedIceOrCreate() async {
    final cached = _lastLocalOfferPayload;
    if (cached != null && cached.isNotEmpty) {
      debugPrint(
        '[WebRtc] replay caller bootstrap offer + ${_cachedLocalIcePayloads.length} cached ICE',
      );
      await _sendSignal('offer', Map<String, dynamic>.from(cached));
      for (final payload in _cachedLocalIcePayloads) {
        await _sendSignal('ice-candidate', Map<String, dynamic>.from(payload));
      }
      return;
    }
    await startAsCaller();
  }

  Future<void> startAsCallee(Map<String, dynamic> offerPayload) async {
    await _initPc();
    await _ensureLocalMedia();
    await _acceptIncomingOffer(offerPayload);
  }

  Future<void> restartAsCallee(Map<String, dynamic> offerPayload) async {
    await _resetPeerConnection(preserveLocalStream: true);
    await _initPc();
    await _ensureLocalMedia();
    await _acceptIncomingOffer(offerPayload);
  }

  Future<void> _acceptIncomingOffer(Map<String, dynamic> offerPayload) async {
    final sdp = offerPayload['sdp']?.toString() ?? '';
    final type = offerPayload['type']?.toString() ?? 'offer';
    final remote = RTCSessionDescription(sdp, type);
    await _pc!.setRemoteDescription(remote);
    _remoteDescSet = true;

    // Wait for ICE candidates with timeout
    await _waitForIceWithTimeout();

    await _flushRemoteIce();
    final answer = await _pc!.createAnswer(_sdpConstraints);
    await _pc!.setLocalDescription(answer);

    // Send answer FIRST
    await _sendSignal('answer', {'sdp': answer.sdp, 'type': answer.type});
    debugPrint('[WebRtc] startAsCallee answer sent');

    await _waitForConnectionWithTimeout();
  }

  Future<void> _resetPeerConnection({required bool preserveLocalStream}) async {
    final completer = _pendingConnectionWait;
    if (completer != null && !completer.isCompleted) {
      completer.complete(false);
    }
    _pendingConnectionWait = null;

    try {
      await _pc?.close();
    } catch (_) {}
    _pc = null;
    _localTracksAttachedToCurrentPc = false;

    for (final t in _remote?.getTracks() ?? <MediaStreamTrack>[]) {
      try {
        await t.stop();
      } catch (_) {}
    }
    try {
      await _remote?.dispose();
    } catch (_) {}
    _remote = null;

    if (!preserveLocalStream) {
      if (_ownsLocalTracks) {
        for (final t in _local?.getTracks() ?? <MediaStreamTrack>[]) {
          try {
            await t.stop();
          } catch (_) {}
        }
        try {
          await _local?.dispose();
        } catch (_) {}
      }
      _local = null;
    }

    _pendingRemoteIce.clear();
    _remoteDescSet = false;
    _lastLocalOfferPayload = null;
    _cachedLocalIcePayloads.clear();
    _establishedEventSent = false;
    _failedEventSent = false;
  }

  Future<void> _waitForIceWithTimeout({
    Duration timeout = const Duration(milliseconds: 350),
  }) async {
    if (_pendingRemoteIce.isNotEmpty) {
      return;
    }
    await Future<void>.delayed(timeout);
  }

  Future<bool> _waitForConnectionWithTimeout({
    Duration timeout = const Duration(seconds: 10),
  }) async {
    if (_pc?.connectionState ==
            RTCPeerConnectionState.RTCPeerConnectionStateConnected ||
        _pc?.iceConnectionState ==
            RTCIceConnectionState.RTCIceConnectionStateConnected ||
        _pc?.iceConnectionState ==
            RTCIceConnectionState.RTCIceConnectionStateCompleted ||
        (_remote?.getTracks().isNotEmpty ?? false)) {
      return true;
    }

    final completer = Completer<bool>();
    _pendingConnectionWait = completer;
    Timer? timer;

    // Timeout fallback
    timer = Timer(timeout, () {
      if (!completer.isCompleted) {
        debugPrint('[WebRtc] Connection wait timeout, checking current state');
        final connected =
            _pc?.connectionState ==
                RTCPeerConnectionState.RTCPeerConnectionStateConnected ||
            _pc?.iceConnectionState ==
                RTCIceConnectionState.RTCIceConnectionStateConnected ||
            _pc?.iceConnectionState ==
                RTCIceConnectionState.RTCIceConnectionStateCompleted ||
            (_remote?.getTracks().isNotEmpty ?? false);
        completer.complete(connected);
      }
    });

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      if (identical(_pendingConnectionWait, completer)) {
        _pendingConnectionWait = null;
      }
    }
  }

  /// Caller: run after remote answer. Callee already set remote in [startAsCallee].
  Future<void> applyAnswer(Map<String, dynamic> answerPayload) async {
    final sdp = answerPayload['sdp']?.toString() ?? '';
    final type = answerPayload['type']?.toString() ?? 'answer';
    await _pc!.setRemoteDescription(RTCSessionDescription(sdp, type));
    _remoteDescSet = true;
    await _flushRemoteIce();
  }

  Future<void> _flushRemoteIce() async {
    final pc = _pc;
    if (pc == null) return;
    for (final c in _pendingRemoteIce) {
      try {
        await pc.addCandidate(c);
      } catch (e, st) {
        debugPrint('[WebRtc] addCandidate failed: $e\n$st');
      }
    }
    _pendingRemoteIce.clear();
  }

  Future<void> addRemoteIceCandidate(Map<String, dynamic> payload) async {
    final cand = payload['candidate']?.toString();
    if (cand == null || cand.isEmpty) return;
    final midRaw = payload['sdpMid'];
    String? mid;
    if (midRaw != null && midRaw.toString() != 'null') {
      final s = midRaw.toString();
      mid = s.isEmpty ? null : s;
    }
    final idxRaw = payload['sdpMLineIndex'];
    final int? idx = idxRaw == null
        ? null
        : (idxRaw is int
              ? idxRaw
              : (idxRaw is num
                    ? idxRaw.toInt()
                    : int.tryParse(idxRaw.toString())));
    final c = RTCIceCandidate(cand, mid, idx ?? 0);
    if (!_remoteDescSet) {
      _pendingRemoteIce.add(c);
      return;
    }
    try {
      await _pc?.addCandidate(c);
    } catch (e, st) {
      debugPrint('[WebRtc] addCandidate: $e\n$st');
    }
  }

  Future<void> setMuted(bool muted) async {
    final audio = _local?.getAudioTracks();
    if (audio == null) return;
    for (final t in audio) {
      t.enabled = !muted;
    }
  }

  Future<void> setVideoEnabled(bool on) async {
    final tracks = _local?.getVideoTracks();
    if (tracks == null) return;
    for (final t in tracks) {
      t.enabled = on;
    }
  }

  Future<void> switchCamera() async {
    if (!video || _local == null) return;
    final tracks = _local!.getVideoTracks();
    if (tracks.isEmpty) return;
    await Helper.switchCamera(tracks.first);
  }

  Future<void> dispose() async {
    _disposeRequested = true;
    try {
      await _resetPeerConnection(preserveLocalStream: false);
    } catch (_) {}
    await _remoteStreamController.close();
    await _connectionEstablishedController.close();
    await _connectionFailedController.close();
  }
}
