import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:titra/core/api/api_client.dart';
import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/features/call/data/active_call_guard.dart';
import 'package:titra/features/call/data/calls_repository.dart';
import 'package:titra/features/call/data/call_end_tone.dart';
import 'package:titra/features/call/data/call_foreground_service.dart';
import 'package:titra/features/call/data/incoming_call_coordinator.dart';
import 'package:titra/features/call/data/outgoing_ringback.dart';
import 'package:titra/features/call/data/web_rtc_call_session.dart';

class AudioCallViewModel extends ChangeNotifier {
  AudioCallViewModel({
    required CallsRepository callsRepository,
    required RealtimeService realtimeService,
    required SessionController sessionController,
    required this.contactName,
    required this.contactId,
    required this.conversationId,
    required this.peerUserId,
    required this.isOutgoing,
    this.avatarUrl,
    this.showTitraId = true,
    this.callSessionId,
    this.remoteOffer,
    this.preBufferedIceCandidates,
    this.incomingCallCoordinator,
  }) : _calls = callsRepository,
       _realtime = realtimeService,
       _session = sessionController {
    _preBufferedIce = preBufferedIceCandidates != null
        ? List<Map<String, dynamic>>.from(preBufferedIceCandidates!)
        : <Map<String, dynamic>>[];
    unawaited(_bootstrap());
  }

  final CallsRepository _calls;
  final RealtimeService _realtime;
  final SessionController _session;

  final String contactName;
  final String contactId;
  final String conversationId;
  final String peerUserId;
  final bool isOutgoing;
  final String? avatarUrl;
  final bool showTitraId;

  /// Callee: server call session id (from incoming flow).
  final String? callSessionId;

  /// Callee: buffered SDP offer, if any.
  final Map<String, dynamic>? remoteOffer;

  /// ICE received during ring; applied after remote SDP is set.
  final List<Map<String, dynamic>>? preBufferedIceCandidates;
  final IncomingCallCoordinator? incomingCallCoordinator;

  late final List<Map<String, dynamic>> _preBufferedIce;

  Timer? _timer;
  int _durationSeconds = 0;
  int get durationSeconds => _durationSeconds;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isSpeakerOn = false;
  bool get isSpeakerOn => _isSpeakerOn;

  String? _error;
  String? get error => _error;

  bool _connecting = true;
  bool get connecting => _connecting;

  /// Outgoing: true after local offer is sent; UI shows "Ringing" and plays ringback until connect.
  bool _outgoingOfferSent = false;
  bool get callerSetupPhase => isOutgoing && connecting && !_outgoingOfferSent;
  bool get callerRingingPhase => isOutgoing && connecting && _outgoingOfferSent;

  final OutgoingRingback _ringback = OutgoingRingback();

  bool _connected = false;
  bool get connected => _connected;

  /// True after [call.state] `ended` (or peer left); UI should pop the route.
  bool _remoteEnded = false;
  bool get remoteEnded => _remoteEnded;

  bool _localEnded = false;
  bool get localEnded => _localEnded;

  bool _shutdownStarted = false;
  bool _actuallyDisposed = false;
  bool _uiDetached = false;

  String? _activeCallSessionId;
  String? get activeCallSessionId => _activeCallSessionId;
  WebRtcCallSession? _rtc;
  StreamSubscription<Map<String, dynamic>>? _signalSub;
  StreamSubscription<Map<String, dynamic>>? _callStateSub;
  StreamSubscription<MediaStream>? _remoteStreamSub;
  StreamSubscription<void>? _connectionEstablishedSub;
  StreamSubscription<void>? _connectionFailedSub;

  bool _waitingRemoteOffer = false;
  bool _incomingTransportReady = false;
  bool _calleeBootstrapStarted = false;
  Map<String, dynamic>? _pendingIncomingOffer;
  Timer? _offerRecoveryTimer;
  int _offerRecoveryAttempts = 0;
  Timer? _outgoingOfferReplayTimer;
  int _outgoingOfferReplayAttempts = 0;

  /// Plays remote audio on iOS/Android (audio-only calls have no visible video view otherwise).
  final RTCVideoRenderer remoteAudioRenderer = RTCVideoRenderer();
  bool _remoteAudioRendererReady = false;
  bool get remoteAudioRendererReady => _remoteAudioRendererReady;

  String get durationFormatted {
    final m = _durationSeconds ~/ 60;
    final s = _durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _notifySafe() {
    if (_actuallyDisposed) return;
    notifyListeners();
  }

  Future<void> _bootstrap() async {
    final myId = _session.user?.id;
    if (myId == null || myId.isEmpty) {
      _error = 'Not signed in';
      _connecting = false;
      _notifySafe();
      return;
    }

    final mic = await Permission.microphone.request();
    if (!mic.isGranted) {
      _error = 'Microphone permission is required';
      _connecting = false;
      _notifySafe();
      return;
    }

    try {
      await remoteAudioRenderer.initialize();
      _remoteAudioRendererReady = true;
      _notifySafe();

      final ice = await _calls.fetchIceServers();

      Future<void> sendSignal(
        String signalType,
        Map<String, dynamic> payload,
      ) async {
        final sid = _activeCallSessionId;
        if (sid == null) return;
        debugPrint(
          '[AudioCall] sendSignal sid=$sid type=$signalType realtimeConnected=${_realtime.isConnected}',
        );
        _realtime.emitCallSignal(
          conversationId: conversationId,
          callSessionId: sid,
          signalType: signalType,
          toUserId: peerUserId,
          payload: payload,
        );
      }

      if (isOutgoing) {
        final created = await _calls.startCall(
          conversationId: conversationId,
          type: 'AUDIO',
        );
        _activeCallSessionId = created['id']?.toString();
        if (_activeCallSessionId == null || _activeCallSessionId!.isEmpty) {
          throw StateError('No call id from server');
        }
        ActiveCallGuard.enter(_activeCallSessionId!);
        
        // Register for overlay immediately
        incomingCallCoordinator?.setActiveCall(
          ActiveCallInfo(
            callSessionId: _activeCallSessionId!,
            conversationId: conversationId,
            contactId: contactId,
            peerUserId: peerUserId,
            contactName: contactName,
            isVideo: false,
            avatarUrl: avatarUrl,
          ),
          viewModel: this,
        );

        _signalSub = _realtime.onCallSignal.listen(_onSignal);
        _callStateSub = _realtime.onCallState.listen(_onCallState);

        _rtc = WebRtcCallSession(
          callSessionId: _activeCallSessionId!,
          conversationId: conversationId,
          peerUserId: peerUserId,
          myUserId: myId,
          video: false,
          iceServers: ice,
          preferSpeakerOutput: _isSpeakerOn,
          sendSignal: sendSignal,
        );
        _bindPeerConnectionState(_rtc!);
        _remoteStreamSub = _rtc!.onRemoteStream.listen((s) {
          remoteAudioRenderer.srcObject = s;
          if (!_connected) {
            debugPrint(
              '[AudioCall] remote media received before connection event sid=$_activeCallSessionId outgoing=$isOutgoing',
            );
            _markConnected();
          }
          _notifySafe();
        });
        await _rtc!.startAsCaller();
        _outgoingOfferSent = true;
        _startOutgoingOfferReplay();
        _notifySafe();
        unawaited(_ringback.start());
      } else {
        final sid = callSessionId;
        if (sid == null || sid.isEmpty) {
          throw StateError('Missing call session');
        }
        _incomingTransportReady = false;
        _calleeBootstrapStarted = false;
        _pendingIncomingOffer = null;
        _activeCallSessionId = sid;
        ActiveCallGuard.enter(sid);

        // Register for overlay immediately
        incomingCallCoordinator?.setActiveCall(
          ActiveCallInfo(
            callSessionId: sid,
            conversationId: conversationId,
            contactId: contactId,
            peerUserId: peerUserId,
            contactName: contactName,
            isVideo: false,
            avatarUrl: avatarUrl,
          ),
          viewModel: this,
        );

        _rtc = WebRtcCallSession(
          callSessionId: sid,
          conversationId: conversationId,
          peerUserId: peerUserId,
          myUserId: myId,
          video: false,
          iceServers: ice,
          preferSpeakerOutput: _isSpeakerOn,
          sendSignal: sendSignal,
        );

        _signalSub = _realtime.onCallSignal.listen(_onSignal);
        _callStateSub = _realtime.onCallState.listen(_onCallState);
        _bindPeerConnectionState(_rtc!);
        _remoteStreamSub = _rtc!.onRemoteStream.listen((s) {
          remoteAudioRenderer.srcObject = s;
          if (!_connected) {
            debugPrint(
              '[AudioCall] remote media received before connection event sid=$_activeCallSessionId outgoing=$isOutgoing',
            );
            _markConnected();
          }
          _notifySafe();
        });

        final bootstrap = incomingCallCoordinator?.consumeAcceptedJoinBootstrap(
          sid,
        );
        Map<String, dynamic>? initialOffer = remoteOffer != null
            ? Map<String, dynamic>.from(remoteOffer!)
            : null;
        if ((initialOffer == null || initialOffer.isEmpty) &&
            bootstrap?.offer != null) {
          initialOffer = Map<String, dynamic>.from(bootstrap!.offer!);
        }
        if (bootstrap != null && bootstrap.preIce.isNotEmpty) {
          _preBufferedIce.addAll(
            bootstrap.preIce.map(Map<String, dynamic>.from),
          );
        }

        final token = _session.sessionToken;
        var realtimeReady = _realtime.isConnected;
        if (!realtimeReady) {
          debugPrint(
            '[AudioCall] incoming join sid=$sid waiting for realtime before transport bootstrap',
          );
          realtimeReady = await _realtime.waitUntilConnected(
            token: token,
            timeout: const Duration(seconds: 8),
          );
          debugPrint(
            '[AudioCall] incoming join sid=$sid realtimeReady=$realtimeReady',
          );
        }

        _realtime.joinConversation(conversationId);
        await _calls.joinCallWithRetry(sid, conversationId: conversationId);
        _incomingTransportReady = true;

        if ((initialOffer == null || initialOffer.isEmpty) &&
            _pendingIncomingOffer != null) {
          initialOffer = Map<String, dynamic>.from(_pendingIncomingOffer!);
          _pendingIncomingOffer = null;
          debugPrint(
            '[AudioCall] incoming join sid=$sid using queued offer captured before transport was ready',
          );
        }

        if (initialOffer != null && initialOffer.isNotEmpty) {
          if (!realtimeReady) {
            debugPrint(
              '[AudioCall] incoming join sid=$sid proceeding with bootstrap offer after realtime wait timeout',
            );
          }
          debugPrint(
            '[AudioCall] incoming join sid=$sid startAsCallee with push/bootstrap offer preIce=${_preBufferedIce.length}',
          );
          _calleeBootstrapStarted = true;
          await _rtc!.startAsCallee(initialOffer);
          await _replayPreBufferedIce();
        } else {
          debugPrint(
            '[AudioCall] incoming join sid=$sid waiting for remote offer over realtime',
          );
          _waitingRemoteOffer = true;
          _startOfferRecovery();
        }
      }

      unawaited(Helper.setSpeakerphoneOn(_isSpeakerOn));
    } catch (e, st) {
      unawaited(_ringback.stop());
      debugPrint('[AudioCall] $e\n$st');
      if (e is DioException) {
        _error = ApiClient.parseErrorMessage(e);
      } else if (e is StateError) {
        _error = e.message;
      } else {
        _error = 'Could not start call';
      }
      _connecting = false;
      if (_activeCallSessionId != null) {
        ActiveCallGuard.clearIfMatches(_activeCallSessionId!);
      }
      if (_remoteAudioRendererReady) {
        try {
          remoteAudioRenderer.srcObject = null;
          await remoteAudioRenderer.dispose();
        } catch (_) {}
        _remoteAudioRendererReady = false;
      }
      _notifySafe();
    }
  }

  Future<void> _replayPreBufferedIce() async {
    final rtc = _rtc;
    if (rtc == null || _preBufferedIce.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_preBufferedIce);
    _preBufferedIce.clear();
    for (final m in batch) {
      try {
        await rtc.addRemoteIceCandidate(m);
      } catch (e, st) {
        debugPrint('[AudioCall] replay ICE: $e\n$st');
      }
    }
  }

  void _bindPeerConnectionState(WebRtcCallSession rtc) {
    unawaited(_connectionEstablishedSub?.cancel());
    unawaited(_connectionFailedSub?.cancel());
    _connectionEstablishedSub = rtc.onConnectionEstablished.listen((_) {
      _markConnected();
    });
    _connectionFailedSub = rtc.onConnectionFailed.listen((_) {
      if (_shutdownStarted || _connected) return;
      unawaited(_ringback.stop());
      _error ??= 'Could not connect. Check network and TURN server.';
      _connecting = false;
      _notifySafe();
    });
  }

  void _markConnected() {
    if (_connected) return;
    _cancelOfferRecovery();
    _cancelOutgoingOfferReplay();
    unawaited(_ringback.stop());
    _connected = true;
    _connecting = false;
    _startTimer();

    // Register active call for background service
    if (_activeCallSessionId != null) {
      startBackgroundCall(BackgroundCallInfo(
        callSessionId: _activeCallSessionId!,
        callerName: contactName,
        handle: contactName,
        isVideo: false,
      ));
    }

    _notifySafe();
  }

  void _onCallState(Map<String, dynamic> p) {
    final sid = p['callSessionId']?.toString() ?? '';
    if (sid.isEmpty || sid != _activeCallSessionId) return;
    final type = p['type']?.toString().trim();
    debugPrint(
      '[AudioCall] call.state sid=$sid type=$type reason=${p['reason']} userId=${p['userId']} connected=$_connected',
    );
    if (type == 'ended') {
      final reason = p['reason']?.toString();
      unawaited(_hangupLocal(fromRemote: true, remoteEndReason: reason));
      return;
    }
    if (type == 'participant_left') {
      final myId = _session.user?.id;
      final leftUser = p['userId']?.toString();
      if (leftUser == null || leftUser.isEmpty) return;
      if (isOutgoing && !_connected) {
        if (myId != null && myId.isNotEmpty && leftUser != myId) {
          unawaited(
            _hangupLocal(fromRemote: true, remoteEndReason: 'declined'),
          );
        }
        return;
      }
      if (leftUser == peerUserId) {
        unawaited(_hangupLocal(fromRemote: true, remoteEndReason: 'peer_left'));
      }
    }
  }

  void _onSignal(Map<String, dynamic> p) {
    if (p['callSessionId']?.toString() != _activeCallSessionId) return;
    if (p['fromUserId']?.toString() != peerUserId) return;
    final signalType = p['signalType']?.toString();
    final payload = p['payload'];
    debugPrint(
      '[AudioCall] signal sid=$_activeCallSessionId type=$signalType waitingRemoteOffer=$_waitingRemoteOffer',
    );
    if (payload is! Map) return;
    final map = Map<String, dynamic>.from(payload);
    unawaited(_handleSignal(signalType, map));
  }

  void _cancelOfferRecovery() {
    _offerRecoveryTimer?.cancel();
    _offerRecoveryTimer = null;
    _offerRecoveryAttempts = 0;
  }

  void _cancelOutgoingOfferReplay() {
    _outgoingOfferReplayTimer?.cancel();
    _outgoingOfferReplayTimer = null;
    _outgoingOfferReplayAttempts = 0;
  }

  Future<void> _replayOutgoingOffer() async {
    if (!isOutgoing || _shutdownStarted || _connected) return;
    final rtc = _rtc;
    if (rtc == null) return;
    _outgoingOfferReplayAttempts++;
    debugPrint(
      '[AudioCall] replay outgoing offer sid=$_activeCallSessionId attempt=$_outgoingOfferReplayAttempts',
    );
    await rtc.resendLastOfferAndCachedIceOrCreate();
    _outgoingOfferSent = true;
  }

  void _startOutgoingOfferReplay() {
    _cancelOutgoingOfferReplay();
    _outgoingOfferReplayTimer = Timer.periodic(const Duration(seconds: 2), (
      timer,
    ) {
      if (!isOutgoing || _shutdownStarted || _connected) {
        timer.cancel();
        return;
      }
      if (_outgoingOfferReplayAttempts >= 6) {
        timer.cancel();
        return;
      }
      unawaited(_replayOutgoingOffer());
    });
  }

  Future<void> _requestOfferReplay() async {
    final sid = _activeCallSessionId;
    if (sid == null ||
        sid.isEmpty ||
        !_waitingRemoteOffer ||
        _shutdownStarted) {
      return;
    }
    _offerRecoveryAttempts++;
    debugPrint(
      '[AudioCall] request offer replay sid=$sid attempt=$_offerRecoveryAttempts',
    );
    _realtime.emitCallSignal(
      conversationId: conversationId,
      callSessionId: sid,
      signalType: 'offer-request',
      toUserId: peerUserId,
      payload: {
        'reason': 'callee_waiting_for_offer',
        'attempt': _offerRecoveryAttempts,
      },
    );
  }

  void _startOfferRecovery() {
    _cancelOfferRecovery();
    unawaited(_requestOfferReplay());
    _offerRecoveryTimer = Timer.periodic(const Duration(seconds: 2), (timer) {
      if (!_waitingRemoteOffer || _shutdownStarted || _connected) {
        timer.cancel();
        return;
      }
      if (_offerRecoveryAttempts >= 4) {
        timer.cancel();
        return;
      }
      unawaited(_requestOfferReplay());
    });
  }

  Future<void> _handleSignal(
    String? signalType,
    Map<String, dynamic> map,
  ) async {
    final rtc = _rtc;
    if (rtc == null) return;
    try {
      switch (signalType) {
        case 'offer':
          if (!isOutgoing &&
              !_incomingTransportReady &&
              !_calleeBootstrapStarted) {
            _pendingIncomingOffer = Map<String, dynamic>.from(map);
            debugPrint(
              '[AudioCall] incoming offer queued until transport is ready sid=$_activeCallSessionId',
            );
            break;
          }
          if (!isOutgoing && !_calleeBootstrapStarted) {
            _cancelOfferRecovery();
            _waitingRemoteOffer = false;
            _calleeBootstrapStarted = true;
            await rtc.startAsCallee(map);
            await _replayPreBufferedIce();
          } else if (!isOutgoing) {
            debugPrint(
              '[AudioCall] duplicate incoming offer ignored sid=$_activeCallSessionId',
            );
          }
          break;
        case 'offer-request':
          if (isOutgoing && !_connected) {
            debugPrint(
              '[AudioCall] outgoing sid=$_activeCallSessionId resend cached offer on request',
            );
            await rtc.resendLastOfferAndCachedIceOrCreate();
            _outgoingOfferSent = true;
            _notifySafe();
          }
          break;
        case 'answer':
          if (isOutgoing) {
            _cancelOutgoingOfferReplay();
            await rtc.applyAnswer(map);
          }
          break;
        case 'ice-candidate':
          await rtc.addRemoteIceCandidate(map);
          break;
        default:
          break;
      }
    } catch (e, st) {
      debugPrint('[AudioCall] signal $signalType: $e\n$st');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _durationSeconds++;
      _notifySafe();
    });
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _rtc?.setMuted(_isMuted);
    _notifySafe();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await Helper.setSpeakerphoneOn(_isSpeakerOn);
    if (WebRTC.platformIsIOS) {
      try {
        await Helper.setAppleAudioIOMode(
          AppleAudioIOMode.localAndRemote,
          preferSpeakerOutput: _isSpeakerOn,
        );
        await Helper.ensureAudioSession();
      } catch (_) {}
    }
    _notifySafe();
  }

  Future<void> endCall() async {
    await _hangupLocal(fromRemote: false, remoteEndReason: null);

  }

  Future<void> _hangupLocal({
    required bool fromRemote,
    String? remoteEndReason,
  }) async {
    if (_shutdownStarted) return;
    debugPrint(
      '[AudioCall] hangup sid=$_activeCallSessionId fromRemote=$fromRemote remoteEndReason=$remoteEndReason connected=$_connected waitingRemoteOffer=$_waitingRemoteOffer',
    );
    _shutdownStarted = true;
    _connecting = false;

    final playEndTone = shouldPlayCallEndedTone(
      isOutgoing: isOutgoing,
      wasCallConnected: _connected,
      remoteEndReason: remoteEndReason,
    );
    await _ringback.stop();
    if (playEndTone) {
      await playCallEndedTone();
    }

    _timer?.cancel();
    _timer = null;
    _cancelOfferRecovery();
    _cancelOutgoingOfferReplay();
    await _signalSub?.cancel();
    await _callStateSub?.cancel();
    await _remoteStreamSub?.cancel();
    await _connectionEstablishedSub?.cancel();
    await _connectionFailedSub?.cancel();
    _signalSub = null;
    _callStateSub = null;
    _remoteStreamSub = null;
    _connectionEstablishedSub = null;
    _connectionFailedSub = null;
    _incomingTransportReady = false;
    _calleeBootstrapStarted = false;
    _pendingIncomingOffer = null;
    await _rtc?.dispose();
    _rtc = null;

    try {
      remoteAudioRenderer.srcObject = null;
      if (_remoteAudioRendererReady) {
        _remoteAudioRendererReady = false;
        await remoteAudioRenderer.dispose();
      }
    } catch (_) {}

    final sid = _activeCallSessionId;
    if (sid != null) {
      incomingCallCoordinator?.clearActiveCall(sid);
      await stopBackgroundCall(callSessionId: sid);
      if (!fromRemote) {
        try {
          if (isOutgoing) {
            await _calls.endCall(sid, reason: 'completed');
          } else {
            await _calls.leaveCall(sid);
          }
        } catch (_) {}
      }
      ActiveCallGuard.clearIfMatches(sid);
      _activeCallSessionId = null;
    }

    if (fromRemote) {
      _remoteEnded = true;
      _error ??= 'Call ended';
    } else {
      _localEnded = true;
    }

    _notifySafe();

    _actuallyDisposed = true;
    if (_uiDetached) {
      super.dispose();
    }
  }

  @override
  void dispose() {
    if (_connected && !_shutdownStarted) {
      _uiDetached = true;
      return;
    }
    _actuallyDisposed = true;
    unawaited(_hangupLocal(fromRemote: false, remoteEndReason: null));
    super.dispose();
  }
}
