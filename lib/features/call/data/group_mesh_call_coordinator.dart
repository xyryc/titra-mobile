import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/features/call/data/web_rtc_call_session.dart';

/// Full mesh: one [WebRtcCallSession] per remote participant. Uses [toUserId] on every signal.
class GroupMeshCallCoordinator {
  GroupMeshCallCoordinator({
    required this.callSessionId,
    required this.conversationId,
    required this.myUserId,
    required this.video,
    required this.iceServers,
    required this.realtime,
    this.preferSpeakerOutput = true,
  });

  final String callSessionId;
  final String conversationId;
  final String myUserId;
  final bool video;
  final List<Map<String, dynamic>> iceServers;
  final RealtimeService realtime;
  final bool preferSpeakerOutput;

  final Map<String, WebRtcCallSession> _sessions = {};
  WebRtcCallSession? _previewSession;

  /// First live peer session shares the preview stream when available.
  WebRtcCallSession? _firstSession;

  void _emit(String signalType, Map<String, dynamic> payload, String toUserId) {
    realtime.emitCallSignal(
      conversationId: conversationId,
      callSessionId: callSessionId,
      signalType: signalType,
      toUserId: toUserId,
      payload: payload,
    );
  }

  Future<WebRtcCallSession> _sessionForPeer(String peerUserId) async {
    final existing = _sessions[peerUserId];
    if (existing != null) return existing;

    MediaStream? sharedLocalStream;
    if (_firstSession != null && _firstSession!.localStream != null) {
      sharedLocalStream = _firstSession!.localStream;
    } else if (_previewSession?.localStream != null) {
      sharedLocalStream = _previewSession!.localStream;
    }

    final rtc = WebRtcCallSession(
      callSessionId: callSessionId,
      conversationId: conversationId,
      peerUserId: peerUserId,
      myUserId: myUserId,
      video: video,
      iceServers: iceServers,
      preferSpeakerOutput: preferSpeakerOutput,
      mediaStream: sharedLocalStream,
      sendSignal: (type, payload) async {
        _emit(type, payload, peerUserId);
      },
    );
    _sessions[peerUserId] = rtc;
    _firstSession ??= rtc;
    return rtc;
  }

  Future<MediaStream?> ensurePrimaryLocalStream() async {
    if (_firstSession?.localStream != null) {
      return _firstSession!.localStream;
    }
    _previewSession ??= WebRtcCallSession(
      callSessionId: callSessionId,
      conversationId: conversationId,
      peerUserId: '__preview__',
      myUserId: myUserId,
      video: video,
      iceServers: iceServers,
      preferSpeakerOutput: preferSpeakerOutput,
      sendSignal: (_, _) async {},
    );
    await _previewSession!.prepareLocalMedia();
    return _previewSession!.localStream;
  }

  Future<void> closePeerSession(String peerUserId) async {
    final session = _sessions.remove(peerUserId);
    if (session == null) return;
    if (_firstSession == session) {
      _firstSession = _sessions.values.firstOrNull;
    }
    await session.dispose();
  }

  bool hasSessionForPeer(String peerUserId) =>
      _sessions.containsKey(peerUserId);

  Future<void> resendOfferToPeer(String peerUserId) async {
    if (peerUserId.isEmpty || peerUserId == myUserId) return;
    final existing = _sessions[peerUserId];
    if (existing == null) {
      await startOfferToPeer(peerUserId);
      return;
    }
    await existing.resendLastOfferAndCachedIceOrCreate();
  }

  Future<void> startOfferToPeer(String peerUserId) async {
    if (peerUserId.isEmpty || peerUserId == myUserId) return;
    final existing = _sessions[peerUserId];
    if (existing != null) {
      await existing.resendLastOfferAndCachedIceOrCreate();
      return;
    }
    final rtc = await _sessionForPeer(peerUserId);
    await rtc.startAsCaller();
  }

  /// Outgoing call: after [startCall] + [joinCall], offer every remote peer (max 4 remotes).
  Future<void> startOffersToRemotes(List<String> remoteUserIds) async {
    for (final peer in remoteUserIds) {
      await startOfferToPeer(peer);
    }
  }

  /// Route WebSocket `call.signal` payloads (must include `fromUserId`, `signalType`, `payload`).
  Future<void> handleSignal(Map<String, dynamic> p) async {
    if (p['callSessionId']?.toString() != callSessionId) return;
    final from = p['fromUserId']?.toString();
    if (from == null || from.isEmpty || from == myUserId) return;
    final signalType = p['signalType']?.toString();
    final raw = p['payload'];
    if (raw is! Map) return;
    final payload = Map<String, dynamic>.from(raw);

    try {
      switch (signalType) {
        case 'offer':
          final existing = _sessions[from];
          if (existing != null && existing.hasPendingLocalOffer) {
            debugPrint(
              '[GroupMesh] offer collision from $from, restarting peer session as callee',
            );
            await existing.restartAsCallee(payload);
          } else {
            final rtc = await _sessionForPeer(from);
            await rtc.startAsCallee(payload);
          }
          break;
        case 'answer':
          final rtc = _sessions[from];
          if (rtc != null) {
            await rtc.applyAnswer(payload);
          }
          break;
        case 'offer-request':
          final rtc = _sessions[from];
          if (rtc != null) {
            debugPrint('[GroupMesh] resend cached offer to $from on request');
            await rtc.resendLastOfferAndCachedIceOrCreate();
          }
          break;
        case 'ice-candidate':
          final rtc = _sessions[from];
          if (rtc != null) {
            await rtc.addRemoteIceCandidate(payload);
          }
          break;
        default:
          break;
      }
    } catch (e, st) {
      debugPrint('[GroupMesh] signal $signalType from $from: $e\n$st');
    }
  }

  Future<void> setMutedAll(bool muted) async {
    await _previewSession?.setMuted(muted);
    for (final s in _sessions.values) {
      await s.setMuted(muted);
    }
  }

  Future<void> setVideoEnabledAll(bool on) async {
    await _previewSession?.setVideoEnabled(on);
    for (final s in _sessions.values) {
      await s.setVideoEnabled(on);
    }
  }

  Future<void> dispose() async {
    final copy = List<WebRtcCallSession>.from(_sessions.values);
    _sessions.clear();
    _firstSession = null;
    for (final s in copy) {
      await s.dispose();
    }
    await _previewSession?.dispose();
    _previewSession = null;
  }

  List<WebRtcCallSession> get sessions => _sessions.values.toList();

  Map<String, WebRtcCallSession> get sessionsByPeer =>
      Map<String, WebRtcCallSession>.unmodifiable(_sessions);

  MediaStream? get primaryLocalStream =>
      _firstSession?.localStream ?? _previewSession?.localStream;
}
