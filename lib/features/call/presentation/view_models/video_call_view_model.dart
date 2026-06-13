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

class VideoCallViewModel extends ChangeNotifier {
  VideoCallViewModel({
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
  final String? callSessionId;
  final Map<String, dynamic>? remoteOffer;
  final List<Map<String, dynamic>>? preBufferedIceCandidates;
  final IncomingCallCoordinator? incomingCallCoordinator;

  late final List<Map<String, dynamic>> _preBufferedIce;

  final RTCVideoRenderer localRenderer = RTCVideoRenderer();
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _renderersReady = false;
  bool get renderersReady => _renderersReady;

  Timer? _timer;
  int _durationSeconds = 0;
  int get durationSeconds => _durationSeconds;

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isVideoOn = true;
  bool get isVideoOn => _isVideoOn;

  String? _error;
  String? get error => _error;

  bool _connecting = true;
  bool get connecting => _connecting;

  bool _outgoingOfferSent = false;
  bool get callerSetupPhase => isOutgoing && connecting && !_outgoingOfferSent;
  bool get callerRingingPhase => isOutgoing && connecting && _outgoingOfferSent;

  final OutgoingRingback _ringback = OutgoingRingback();

  bool _connected = false;
  bool get connected => _connected;

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

  /// Drives [RTCVideoView] key so the texture rebinds when the remote stream arrives.
  String? _remoteVideoStreamKey;
  String? get remoteVideoStreamKey => _remoteVideoStreamKey;

  String get durationFormatted {
    final m = _durationSeconds ~/ 60;
    final s = _durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _notifySafe() {
    if (!_actuallyDisposed) notifyListeners();
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
    final cam = await Permission.camera.request();
    if (!mic.isGranted || !cam.isGranted) {
      _error = 'Camera and microphone are required';
      _connecting = false;
      _notifySafe();
      return;
    }

    try {
      await localRenderer.initialize();
      await remoteRenderer.initialize();
      _renderersReady = true;

      final ice = await _calls.fetchIceServers();

      Future<void> sendSignal(
        String signalType,
        Map<String, dynamic> payload,
      ) async {
        final sid = _activeCallSessionId;
        if (sid == null) return;
        debugPrint(
          '[VideoCall] sendSignal sid=$sid type=$signalType realtimeConnected=${_realtime.isConnected}',
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
          type: 'VIDEO',
        );
        _activeCallSessionId = created['id']?.toString();
        if (_activeCallSessionId == null || _activeCallSessionId!.isEmpty) {
          throw StateError('No call id from server');
        }
        ActiveCallGuard.enter(_activeCallSessionId!);
        // Set active call + start foreground service immediately (outgoing)
        incomingCallCoordinator?.setActiveCall(
          ActiveCallInfo(
            callSessionId: _activeCallSessionId!,
            conversationId: conversationId,
            contactId: contactId,
            peerUserId: peerUserId,
            contactName: contactName,
            isVideo: true,
            avatarUrl: avatarUrl,
          ),
          viewModel: this,
        );
        startBackgroundCall(BackgroundCallInfo(
          callSessionId: _activeCallSessionId!,
          callerName: contactName,
          handle: contactName,
          isVideo: true,
        ));

        _signalSub = _realtime.onCallSignal.listen(_onSignal);
        _callStateSub = _realtime.onCallState.listen(_onCallState);

        _rtc = WebRtcCallSession(
          callSessionId: _activeCallSessionId!,
          conversationId: conversationId,
          peerUserId: peerUserId,
          myUserId: myId,
          video: true,
          iceServers: ice,
          preferSpeakerOutput: true,
          sendSignal: sendSignal,
        );
        _bindPeerConnectionState(_rtc!);
        _remoteStreamSub = _rtc!.onRemoteStream.listen((s) {
          debugPrint('[VideoCall] remote stream received: ${s.id} tracks=${s.getTracks().length}');
          remoteRenderer.srcObject = s;
          _remoteVideoStreamKey = '${s.id}-${DateTime.now().millisecondsSinceEpoch}';
          
          if (!_connected) {
            debugPrint(
              '[VideoCall] remote media received before connection event sid=$_activeCallSessionId outgoing=$isOutgoing',
            );
            _markConnected();
          }
          _notifySafe();
          
          // Also listen for track changes on this stream
          s.onAddTrack = (_) {
            debugPrint('[VideoCall] remote track added to stream ${s.id}');
            _remoteVideoStreamKey = '${s.id}-${DateTime.now().millisecondsSinceEpoch}';
            _notifySafe();
          };
          s.onRemoveTrack = (_) {
            debugPrint('[VideoCall] remote track removed from stream ${s.id}');
            _remoteVideoStreamKey = '${s.id}-${DateTime.now().millisecondsSinceEpoch}';
            _notifySafe();
          };
        });

        await _rtc!.startAsCaller();
        _bindLocalPreview();
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
            isVideo: true,
            avatarUrl: avatarUrl,
          ),
          viewModel: this,
        );

        _rtc = WebRtcCallSession(
          callSessionId: sid,
          conversationId: conversationId,
          peerUserId: peerUserId,
          myUserId: myId,
          video: true,
          iceServers: ice,
          preferSpeakerOutput: true,
          sendSignal: sendSignal,
        );

        _signalSub = _realtime.onCallSignal.listen(_onSignal);
        _callStateSub = _realtime.onCallState.listen(_onCallState);
        _bindPeerConnectionState(_rtc!);
        _remoteStreamSub = _rtc!.onRemoteStream.listen((s) {
          debugPrint('[VideoCall] remote stream received: ${s.id} tracks=${s.getTracks().length}');
          remoteRenderer.srcObject = s;
          _remoteVideoStreamKey = '${s.id}-${DateTime.now().millisecondsSinceEpoch}';
          
          if (!_connected) {
            debugPrint(
              '[VideoCall] remote media received before connection event sid=$_activeCallSessionId outgoing=$isOutgoing',
            );
            _markConnected();
          }
          _notifySafe();
          
          // Also listen for track changes on this stream
          s.onAddTrack = (_) {
            debugPrint('[VideoCall] remote track added to stream ${s.id}');
            _remoteVideoStreamKey = '${s.id}-${DateTime.now().millisecondsSinceEpoch}';
            _notifySafe();
          };
          s.onRemoveTrack = (_) {
            debugPrint('[VideoCall] remote track removed from stream ${s.id}');
            _remoteVideoStreamKey = '${s.id}-${DateTime.now().millisecondsSinceEpoch}';
            _notifySafe();
          };
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
            '[VideoCall] incoming join sid=$sid waiting for realtime before transport bootstrap',
          );
          realtimeReady = await _realtime.waitUntilConnected(
            token: token,
            timeout: const Duration(seconds: 8),
          );
          debugPrint(
            '[VideoCall] incoming join sid=$sid realtimeReady=$realtimeReady',
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
            '[VideoCall] incoming join sid=$sid using queued offer captured before transport was ready',
          );
        }

        if (initialOffer != null && initialOffer.isNotEmpty) {
          if (!realtimeReady) {
            debugPrint(
              '[VideoCall] incoming join sid=$sid proceeding with bootstrap offer after realtime wait timeout',
            );
          }
          debugPrint(
            '[VideoCall] incoming join sid=$sid startAsCallee with push/bootstrap offer preIce=${_preBufferedIce.length}',
          );
          _calleeBootstrapStarted = true;
          await _rtc!.startAsCallee(initialOffer);
          await _replayPreBufferedIce();
          _bindLocalPreview();
        } else {
          debugPrint(
            '[VideoCall] incoming join sid=$sid waiting for remote offer over realtime',
          );
          _waitingRemoteOffer = true;
          _startOfferRecovery();
        }
      }

      unawaited(_ensureSpeakerphoneForVideo());
    } catch (e, st) {
      unawaited(_ringback.stop());
      debugPrint('[VideoCall] $e\n$st');
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
      if (_renderersReady) {
        try {
          await localRenderer.dispose();
          await remoteRenderer.dispose();
        } catch (_) {}
        _renderersReady = false;
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
        debugPrint('[VideoCall] replay ICE: $e\n$st');
      }
    }
  }

  void _bindLocalPreview() {
    final s = _rtc?.localStream;
    if (s != null) {
      localRenderer.srcObject = s;
      _notifySafe();
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
    final sid = _activeCallSessionId;
    if (sid != null && sid.isNotEmpty) {
      unawaited(
        startBackgroundCall(
          BackgroundCallInfo(
            callSessionId: sid,
            callerName: contactName,
            handle: contactId,
            isVideo: true,
            isOutgoing: isOutgoing,
          ),
        ),
      );
    }
    _cancelOfferRecovery();
    _cancelOutgoingOfferReplay();
    unawaited(_ringback.stop());
    _connected = true;
    _connecting = false;
    _startTimer();
    final ls = _rtc?.localStream;
    if (ls != null) {
      localRenderer.srcObject = ls;
    }
    
    unawaited(_ensureSpeakerphoneForVideo());
    _notifySafe();
  }

  /// Video calls use the loudspeaker by default (and we keep it on after connect).
  Future<void> _ensureSpeakerphoneForVideo() async {
    if (kIsWeb) return;
    try {
      await Helper.setSpeakerphoneOn(true);
      if (WebRTC.platformIsIOS) {
        await Helper.setAppleAudioIOMode(
          AppleAudioIOMode.localAndRemote,
          preferSpeakerOutput: true,
        );
        await Helper.ensureAudioSession();
      }
    } catch (e, st) {
      debugPrint('[VideoCall] speaker: $e\n$st');
    }
  }

  void _onCallState(Map<String, dynamic> p) {
    final sid = p['callSessionId']?.toString() ?? '';
    if (sid.isEmpty || sid != _activeCallSessionId) return;
    final type = p['type']?.toString().trim();
    if (type == 'ended') {
      final reason = p['reason']?.toString();
      unawaited(_hangupLocal(fromRemote: true, remoteEndReason: reason));
      return;
    }
    if (type == 'participant_left') {
      final myId = _session.user?.id;
      final leftUser = p['userId']?.toString();
      if (leftUser == null || leftUser.isEmpty) return;
      // Outgoing + still ringing: any other member leaving means decline / missed (do not require peerUserId match).
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
      '[VideoCall] signal sid=$_activeCallSessionId type=$signalType waitingRemoteOffer=$_waitingRemoteOffer',
    );
    if (payload is! Map) return;
    unawaited(_handleSignal(signalType, Map<String, dynamic>.from(payload)));
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
      '[VideoCall] replay outgoing offer sid=$_activeCallSessionId attempt=$_outgoingOfferReplayAttempts',
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
      '[VideoCall] request offer replay sid=$sid attempt=$_offerRecoveryAttempts',
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
              '[VideoCall] incoming offer queued until transport is ready sid=$_activeCallSessionId',
            );
            break;
          }
          if (!isOutgoing && !_calleeBootstrapStarted) {
            _cancelOfferRecovery();
            _waitingRemoteOffer = false;
            _calleeBootstrapStarted = true;
            await rtc.startAsCallee(map);
            await _replayPreBufferedIce();
            _bindLocalPreview();
            unawaited(_ensureSpeakerphoneForVideo());
            _notifySafe();
          } else if (!isOutgoing) {
            debugPrint(
              '[VideoCall] duplicate incoming offer ignored sid=$_activeCallSessionId',
            );
          }
          break;
        case 'offer-request':
          if (isOutgoing && !_connected) {
            debugPrint(
              '[VideoCall] outgoing sid=$_activeCallSessionId resend cached offer on request',
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
      debugPrint('[VideoCall] signal $signalType: $e\n$st');
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _durationSeconds++;
      if (_durationSeconds % 1 == 0) {
        unawaited(CallForegroundService.updateTimer(durationFormatted));
      }
      _notifySafe();
    });
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _rtc?.setMuted(_isMuted);
    _notifySafe();
  }

  Future<void> toggleVideo() async {
    _isVideoOn = !_isVideoOn;
    await _rtc?.setVideoEnabled(_isVideoOn);
    _notifySafe();
  }

  Future<void> switchCamera() async {
    await _rtc?.switchCamera();
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

    if (_renderersReady) {
      try {
        localRenderer.srcObject = null;
        remoteRenderer.srcObject = null;
        await localRenderer.dispose();
        await remoteRenderer.dispose();
      } catch (_) {}
      _renderersReady = false;
    } else {
      try {
        await localRenderer.dispose();
        await remoteRenderer.dispose();
      } catch (_) {}
    }

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
      _signalSub?.cancel();
      _callStateSub?.cancel();
      _remoteStreamSub?.cancel();
      _connectionEstablishedSub?.cancel();
      _connectionFailedSub?.cancel();
      return;
    }
    _actuallyDisposed = true;
    unawaited(_hangupLocal(fromRemote: false, remoteEndReason: null));
    super.dispose();
  }
}
