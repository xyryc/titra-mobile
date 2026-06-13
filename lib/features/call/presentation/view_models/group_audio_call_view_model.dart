import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:titra/core/api/api_client.dart';
import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/features/call/data/active_call_guard.dart';
import 'package:titra/features/call/data/call_participant.dart';
import 'package:titra/features/call/data/calls_repository.dart';
import 'package:titra/features/call/data/call_foreground_service.dart';
import 'package:titra/features/call/data/group_mesh_call_coordinator.dart';
import 'package:titra/features/call/data/incoming_call_coordinator.dart';
import 'package:titra/features/call/data/outgoing_ringback.dart';

/// Group audio call (mesh). Hidden [RTCVideoRenderer]s play remote audio.
class GroupAudioCallViewModel extends ChangeNotifier {
  GroupAudioCallViewModel({
    required CallsRepository callsRepository,
    required RealtimeService realtimeService,
    required SessionController sessionController,
    required this.groupName,
    required this.conversationId,
    required this.remotePeerUserIds,
    required Map<String, String> peerNamesById,
    required this.isOutgoing,
    this.callSessionId,
    this.incomingCallCoordinator,
  }) : _calls = callsRepository,
       _realtime = realtimeService,
       _session = sessionController,
       _peerNamesById = Map<String, String>.from(peerNamesById) {
    participants = <CallParticipant>[];
    unawaited(_bootstrap());
  }

  final CallsRepository _calls;
  final RealtimeService _realtime;
  final SessionController _session;
  final IncomingCallCoordinator? incomingCallCoordinator;

  final String groupName;
  final String conversationId;
  final List<String> remotePeerUserIds;
  final Map<String, String> _peerNamesById;
  final bool isOutgoing;
  final String? callSessionId;

  late List<CallParticipant> participants;

  /// Hidden renderers so remote audio plays (pair with tiny [RTCVideoView] in UI).
  final Map<String, RTCVideoRenderer> remoteAudioRenderers = {};

  final OutgoingRingback _ringback = OutgoingRingback();

  GroupMeshCallCoordinator? _mesh;
  String? _activeCallSessionId;
  String? get activeCallSessionId => _activeCallSessionId;
  StreamSubscription<Map<String, dynamic>>? _signalSub;
  StreamSubscription<Map<String, dynamic>>? _callStateSub;
  StreamSubscription<Map<String, dynamic>>? _callPeerJoinedSub;
  final List<StreamSubscription<MediaStream>> _remoteSubs = [];
  final Set<String> _subscribedRemote = {};
  final Map<String, Timer> _offerReplayTimers = {};
  final Map<String, int> _offerReplayAttempts = {};

  Timer? _timer;
  int _durationSeconds = 0;
  int get durationSeconds => _durationSeconds;

  String get durationFormatted {
    final m = _durationSeconds ~/ 60;
    final s = _durationSeconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  void _notifySafe() {
    if (!_actuallyDisposed) notifyListeners();
  }

  bool _isMuted = false;
  bool get isMuted => _isMuted;

  bool _isSpeakerOn = true;
  bool get isSpeakerOn => _isSpeakerOn;

  String? _error;
  String? get error => _error;

  bool _connecting = true;
  bool get connecting => _connecting;

  bool _connected = false;
  bool get connected => _connected;

  bool _ended = false;
  bool get ended => _ended;

  bool _shutdownStarted = false;
  bool _actuallyDisposed = false;
  bool _uiDetached = false;
  bool _joinedExistingActiveCall = false;
  String? _initiatorUserId;
  String? _activeSpeakerUserId;

  bool get canEndForEveryone {
    final myId = _session.user?.id;
    return myId != null &&
        myId.isNotEmpty &&
        _initiatorUserId != null &&
        _initiatorUserId == myId;
  }

  String? get activeSpeakerUserId => _activeSpeakerUserId;

  int get participantCount => participants.length + 1;

  List<CallParticipant> get orderedParticipants {
    final ordered = List<CallParticipant>.from(participants);
    ordered.sort((a, b) {
      final aRank = _participantRank(a);
      final bRank = _participantRank(b);
      if (aRank != bRank) return aRank.compareTo(bRank);
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return ordered;
  }

  int _participantRank(CallParticipant participant) {
    if (participant.id == _activeSpeakerUserId) return 0;
    if (participant.isSpeaking) return 1;
    if (!participant.isMuted) return 2;
    return 3;
  }

  void updateParticipantState(
    String userId, {
    bool? isMuted,
    bool? isSpeaking,
  }) {
    if (userId.isEmpty) return;
    final index = participants.indexWhere((p) => p.id == userId);
    if (index < 0) return;
    final current = participants[index];
    final next = current.copyWith(isMuted: isMuted, isSpeaking: isSpeaking);
    if (next.isMuted == current.isMuted &&
        next.isSpeaking == current.isSpeaking &&
        next.name == current.name &&
        next.avatarUrl == current.avatarUrl) {
      return;
    }
    participants[index] = next;
    if (isSpeaking != null) {
      if (isSpeaking) {
        _activeSpeakerUserId = userId;
      } else if (_activeSpeakerUserId == userId) {
        String? fallback;
        for (final participant in participants) {
          if (participant.id != userId && participant.isSpeaking) {
            fallback = participant.id;
            break;
          }
        }
        _activeSpeakerUserId = fallback;
      }
    }
    _notifySafe();
  }

  void _attachStreamsForNewSessions() {
    final mesh = _mesh;
    if (mesh == null) return;
    for (final entry in mesh.sessionsByPeer.entries) {
      final id = entry.key;
      if (_subscribedRemote.contains(id)) continue;
      final rtc = entry.value;
      final renderer = remoteAudioRenderers[id];
      if (renderer == null) continue;
      _subscribedRemote.add(id);
      _remoteSubs.add(
        rtc.onRemoteStream.listen((stream) {
          _cancelOfferReplayForPeer(id);
          renderer.srcObject = stream;
          _markConnected();
          _notifySafe();
        }),
      );
    }
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
      _error = 'Microphone is required';
      _connecting = false;
      _notifySafe();
      return;
    }

    var stage = 'fetch_ice_servers';
    var callSessionCreated = false;
    try {
      final ice = await _calls.fetchIceServers();
      if (isOutgoing) {
        stage = 'load_active_calls';
        final activeCalls = await _calls.fetchActiveCalls(conversationId);
        final existing = activeCalls.cast<Map<String, dynamic>?>().firstWhere(
          (call) =>
              call != null && call['type']?.toString().toUpperCase() == 'AUDIO',
          orElse: () => null,
        );
        if (existing != null) {
          _activeCallSessionId = existing['id']?.toString();
          _joinedExistingActiveCall = true;
          _initiatorUserId = existing['initiatorId']?.toString();
          stage = 'join_existing_call';
          callSessionCreated = true;
        } else {
          stage = 'start_new_call';
          final created = await _calls.startCall(
            conversationId: conversationId,
            type: 'AUDIO',
          );
          _activeCallSessionId = created['id']?.toString();
          _initiatorUserId =
              created['initiatorId']?.toString() ?? _session.user?.id;
          callSessionCreated = true;
        }
        if (_activeCallSessionId == null || _activeCallSessionId!.isEmpty) {
          throw StateError('No call id');
        }
        ActiveCallGuard.enter(_activeCallSessionId!);

        incomingCallCoordinator?.setActiveCall(
          ActiveCallInfo(
            callSessionId: _activeCallSessionId!,
            conversationId: conversationId,
            contactId: conversationId,
            peerUserId: '',
            contactName: groupName,
            isVideo: false,
            isGroup: true,
            remotePeerUserIds: remotePeerUserIds,
            peerNamesById: _peerNamesById,
          ),
          viewModel: this,
        );

        if (_joinedExistingActiveCall) {
          await _calls.joinCallWithRetry(
            _activeCallSessionId!,
            conversationId: conversationId,
          );
        }
      } else {
        final sid = callSessionId;
        if (sid == null || sid.isEmpty) {
          throw StateError('Missing call session');
        }
        _activeCallSessionId = sid;
        ActiveCallGuard.enter(sid);
        stage = 'join_incoming_call';

        incomingCallCoordinator?.setActiveCall(
          ActiveCallInfo(
            callSessionId: sid,
            conversationId: conversationId,
            contactId: conversationId,
            peerUserId: '',
            contactName: groupName,
            isVideo: false,
            isGroup: true,
            remotePeerUserIds: remotePeerUserIds,
            peerNamesById: _peerNamesById,
          ),
          viewModel: this,
        );

        await _calls.joinCallWithRetry(sid, conversationId: conversationId);
        callSessionCreated = true;
        stage = 'load_call_metadata';
        await _loadCurrentCallMetadata();
      }

      stage = 'create_mesh';
      _mesh = GroupMeshCallCoordinator(
        callSessionId: _activeCallSessionId!,
        conversationId: conversationId,
        myUserId: myId,
        video: false,
        iceServers: ice,
        realtime: _realtime,
        preferSpeakerOutput: _isSpeakerOn,
      );

      _signalSub = _realtime.onCallSignal.listen((map) async {
        _handleOfferReplaySignal(map);
        await _mesh?.handleSignal(map);
        _attachStreamsForNewSessions();
      });
      _callStateSub = _realtime.onCallState.listen(_onCallState);
      _callPeerJoinedSub = _realtime.onCallPeerJoined.listen((map) async {
        await _onCallPeerJoined(map);
      });

      _realtime.joinConversation(conversationId);

      if (incomingCallCoordinator != null && _activeCallSessionId != null) {
        final bootstrap = incomingCallCoordinator!.consumeAcceptedJoinBootstrap(
          _activeCallSessionId!,
        );
        if (bootstrap.offer != null && bootstrap.callerUserId != null) {
          debugPrint(
            '[GroupAudioCall] consuming bootstrap offer from ${bootstrap.callerUserId}',
          );
          await _mesh?.handleSignal({
            'callSessionId': _activeCallSessionId,
            'fromUserId': bootstrap.callerUserId,
            'signalType': 'offer',
            'payload': bootstrap.offer,
          });
          for (final ice in bootstrap.preIce) {
            await _mesh?.handleSignal({
              'callSessionId': _activeCallSessionId,
              'fromUserId': bootstrap.callerUserId,
              'signalType': 'ice-candidate',
              'payload': ice,
            });
          }
        }
      }

      if (isOutgoing && !_joinedExistingActiveCall) {
        _attachStreamsForNewSessions();
      } else {
        stage = 'bootstrap_join_offer';
        await _startJoinBootstrapOffer();
      }

      unawaited(_ensureSpeaker());
      _connecting = false;
      _notifySafe();
    } catch (e, st) {
      debugPrint('[GroupAudioCall] bootstrap failed at $stage: $e\n$st');
      if (e is DioException) {
        _error = ApiClient.parseErrorMessage(e);
      } else {
        _error = callSessionCreated
            ? 'Call started, but audio setup failed'
            : 'Could not start group call';
      }
      _connecting = false;
      if (_activeCallSessionId != null) {
        ActiveCallGuard.clearIfMatches(_activeCallSessionId!);
      }
      _notifySafe();
    }
  }

  Future<void> _ensureSpeaker() async {
    if (kIsWeb) return;
    try {
      await Helper.setSpeakerphoneOn(_isSpeakerOn);
      if (WebRTC.platformIsIOS) {
        await Helper.setAppleAudioIOMode(
          AppleAudioIOMode.localAndRemote,
          preferSpeakerOutput: _isSpeakerOn,
        );
        await Helper.ensureAudioSession();
      }
    } catch (e, st) {
      debugPrint('[GroupAudioCall] audio route: $e\n$st');
    }
  }

  void _onCallState(Map<String, dynamic> p) {
    final sid = p['callSessionId']?.toString() ?? '';
    if (sid.isEmpty || sid != _activeCallSessionId) return;
    final type = p['type']?.toString();
    if (type == 'ended') {
      unawaited(_hangupLocal(fromRemote: true));
    } else if (type == 'participant_joined') {
      final joinedId = p['userId']?.toString() ?? '';
      final myId = _session.user?.id ?? '';
      if (joinedId.isNotEmpty && joinedId != myId) {
        _markConnected();
        unawaited(_ensureParticipantVisible(joinedId));
      }
    } else if (type == 'participant_left') {
      final leftId = p['userId']?.toString() ?? '';
      if (leftId.isNotEmpty) {
        unawaited(_removeParticipant(leftId));
      }
    }
  }

  Future<void> _removeParticipant(String userId) async {
    _cancelOfferReplayForPeer(userId);
    participants.removeWhere((p) => p.id == userId);
    _subscribedRemote.remove(userId);
    if (_activeSpeakerUserId == userId) {
      _activeSpeakerUserId = null;
    }

    await _mesh?.closePeerSession(userId);

    final renderer = remoteAudioRenderers.remove(userId);
    if (renderer != null) {
      try {
        renderer.srcObject = null;
        await renderer.dispose();
      } catch (_) {}
    }
    _notifySafe();
  }

  Future<void> _onCallPeerJoined(Map<String, dynamic> p) async {
    final sid = p['callSessionId']?.toString() ?? '';
    if (sid.isEmpty || sid != _activeCallSessionId) return;
    final joinedUserId = p['userId']?.toString() ?? '';
    final myId = _session.user?.id ?? '';
    if (joinedUserId.isEmpty || joinedUserId == myId) return;

    await _ensureParticipantVisible(joinedUserId);

    final mesh = _mesh;
    if (mesh == null || mesh.hasSessionForPeer(joinedUserId)) return;
    await mesh.startOfferToPeer(joinedUserId);
    _startOfferReplayForPeer(joinedUserId, sendImmediately: false);
    _attachStreamsForNewSessions();
  }

  Future<void> _startJoinBootstrapOffer() async {
    final sid = _activeCallSessionId;
    final myId = _session.user?.id;
    final mesh = _mesh;
    if (sid == null ||
        sid.isEmpty ||
        myId == null ||
        myId.isEmpty ||
        mesh == null) {
      return;
    }
    final activeCalls = await _calls.fetchActiveCalls(conversationId);
    final current = activeCalls.cast<Map<String, dynamic>?>().firstWhere(
      (call) => call != null && call['id']?.toString() == sid,
      orElse: () => null,
    );
    if (current == null) return;
    _initiatorUserId = current['initiatorId']?.toString();
    await _syncJoinedParticipantsFromCall(current);
    final participants = current['participants'];
    if (participants is! List) return;

    String? anchorUserId;
    final initiatorId = current['initiatorId']?.toString();
    final initiatorParticipant = participants
        .whereType<Map>()
        .cast<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .firstWhere(
          (p) =>
              p['userId']?.toString() == initiatorId &&
              p['status']?.toString().toUpperCase() == 'JOINED',
          orElse: () => const <String, dynamic>{},
        );
    if (initiatorId != null &&
        initiatorId.isNotEmpty &&
        initiatorId != myId &&
        initiatorParticipant.isNotEmpty) {
      anchorUserId = initiatorId;
    } else {
      for (final raw in participants.whereType<Map>()) {
        final p = Map<String, dynamic>.from(raw);
        final userId = p['userId']?.toString();
        final status = p['status']?.toString().toUpperCase();
        if (userId == null || userId.isEmpty || userId == myId) continue;
        if (status == 'JOINED') {
          anchorUserId = userId;
          break;
        }
      }
    }
    if (anchorUserId == null || anchorUserId.isEmpty) return;
    await mesh.startOfferToPeer(anchorUserId);
    _startOfferReplayForPeer(anchorUserId, sendImmediately: false);
    _attachStreamsForNewSessions();
  }

  void _handleOfferReplaySignal(Map<String, dynamic> map) {
    final sid = map['callSessionId']?.toString() ?? '';
    if (sid.isEmpty || sid != _activeCallSessionId) return;
    final fromUserId = map['fromUserId']?.toString() ?? '';
    if (fromUserId.isEmpty) return;
    final signalType = map['signalType']?.toString();
    if (signalType == 'answer' || signalType == 'offer') {
      _cancelOfferReplayForPeer(fromUserId);
    }
  }

  Future<void> _replayOfferToPeer(String peerUserId) async {
    if (_shutdownStarted) return;
    final mesh = _mesh;
    if (mesh == null) return;
    _offerReplayAttempts[peerUserId] =
        (_offerReplayAttempts[peerUserId] ?? 0) + 1;
    debugPrint(
      '[GroupAudioCall] replay outgoing offer sid=$_activeCallSessionId '
      'peer=$peerUserId attempt=${_offerReplayAttempts[peerUserId]}',
    );
    await mesh.resendOfferToPeer(peerUserId);
  }

  void _startOfferReplayForPeer(
    String peerUserId, {
    bool sendImmediately = true,
  }) {
    if (peerUserId.isEmpty) return;
    _cancelOfferReplayForPeer(peerUserId);
    if (sendImmediately) {
      unawaited(_replayOfferToPeer(peerUserId));
    }
    _offerReplayTimers[peerUserId] = Timer.periodic(
      const Duration(seconds: 2),
      (timer) {
        if (_shutdownStarted) {
          _cancelOfferReplayForPeer(peerUserId);
          return;
        }
        final attempts = _offerReplayAttempts[peerUserId] ?? 0;
        if (attempts >= 6) {
          _cancelOfferReplayForPeer(peerUserId);
          return;
        }
        unawaited(_replayOfferToPeer(peerUserId));
      },
    );
  }

  void _cancelOfferReplayForPeer(String peerUserId) {
    _offerReplayTimers.remove(peerUserId)?.cancel();
    _offerReplayAttempts.remove(peerUserId);
  }

  void _cancelAllOfferReplay() {
    for (final timer in _offerReplayTimers.values) {
      timer.cancel();
    }
    _offerReplayTimers.clear();
    _offerReplayAttempts.clear();
  }

  Future<void> _loadCurrentCallMetadata() async {
    final sid = _activeCallSessionId;
    if (sid == null || sid.isEmpty) return;
    final activeCalls = await _calls.fetchActiveCalls(conversationId);
    final current = activeCalls.cast<Map<String, dynamic>?>().firstWhere(
      (call) => call != null && call['id']?.toString() == sid,
      orElse: () => null,
    );
    if (current == null) return;
    _initiatorUserId = current['initiatorId']?.toString();
    await _syncJoinedParticipantsFromCall(current);
  }

  Future<void> _ensureParticipantVisible(String userId) async {
    if (userId.isEmpty) return;
    if (!remoteAudioRenderers.containsKey(userId)) {
      final renderer = RTCVideoRenderer();
      await renderer.initialize();
      remoteAudioRenderers[userId] = renderer;
    }
    if (!participants.any((p) => p.id == userId)) {
      participants.add(
        CallParticipant(
          id: userId,
          name: _peerNamesById[userId] ?? 'User',
          avatarUrl: null,
        ),
      );
      _notifySafe();
    }
  }

  Future<void> _syncJoinedParticipantsFromCall(
    Map<String, dynamic> current,
  ) async {
    final myId = _session.user?.id ?? '';
    final rawParticipants = current['participants'];
    if (rawParticipants is! List) return;

    final joinedIds = <String>{
      for (final raw in rawParticipants.whereType<Map>())
        if ((raw['status']?.toString().toUpperCase() == 'JOINED'))
          (raw['userId']?.toString() ?? ''),
    }..removeWhere((id) => id.isEmpty || id == myId);

    participants.removeWhere((p) => !joinedIds.contains(p.id));

    final staleRendererIds = remoteAudioRenderers.keys
        .where((id) => !joinedIds.contains(id))
        .toList();
    for (final id in staleRendererIds) {
      _cancelOfferReplayForPeer(id);
      _subscribedRemote.remove(id);
      await _mesh?.closePeerSession(id);
      final renderer = remoteAudioRenderers.remove(id);
      if (renderer != null) {
        try {
          renderer.srcObject = null;
          await renderer.dispose();
        } catch (_) {}
      }
    }
    for (final joinedId in joinedIds) {
      await _ensureParticipantVisible(joinedId);
    }
    if (joinedIds.isNotEmpty) {
      _markConnected();
    }
    _notifySafe();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _durationSeconds++;
      _notifySafe();
    });
  }

  void _markConnected() {
    if (_connected) return;
    final sid = _activeCallSessionId;
    if (sid != null && sid.isNotEmpty) {
      startBackgroundCall(BackgroundCallInfo(
        callSessionId: sid,
        callerName: groupName,
        handle: groupName,
        isVideo: false,
      ));
    }
    _connected = true;
    _startTimer();
    _notifySafe();
  }

  Future<void> toggleMute() async {
    _isMuted = !_isMuted;
    await _mesh?.setMutedAll(_isMuted);
    _notifySafe();
  }

  Future<void> toggleSpeaker() async {
    _isSpeakerOn = !_isSpeakerOn;
    await _ensureSpeaker();
    _notifySafe();
  }

  Future<void> endCall() async {
    await _hangupLocal(fromRemote: false);
  }

  Future<void> _hangupLocal({required bool fromRemote}) async {
    if (_shutdownStarted) return;
    _shutdownStarted = true;
    unawaited(_ringback.stop());
    _cancelAllOfferReplay();
    _timer?.cancel();
    _timer = null;
    await _signalSub?.cancel();
    await _callStateSub?.cancel();
    await _callPeerJoinedSub?.cancel();
    for (final s in _remoteSubs) {
      await s.cancel();
    }
    _remoteSubs.clear();
    _subscribedRemote.clear();
    await _mesh?.dispose();
    _mesh = null;

    for (final r in remoteAudioRenderers.values) {
      try {
        r.srcObject = null;
        await r.dispose();
      } catch (_) {}
    }
    remoteAudioRenderers.clear();

    _realtime.leaveConversation(conversationId);

    final sid = _activeCallSessionId;
    if (sid != null) {
      incomingCallCoordinator?.clearActiveCall(sid);
      await stopBackgroundCall(callSessionId: sid);
      if (!fromRemote) {
        try {
          if (canEndForEveryone) {
            await _calls.endCall(sid, reason: 'completed');
          } else {
            await _calls.leaveCall(sid);
          }
        } catch (_) {}
      }
      ActiveCallGuard.clearIfMatches(sid);
      _activeCallSessionId = null;
    }
    _ended = true;
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
      // timer cancel করব না যাতে background এ সময় ঠিক থাকে
      _signalSub?.cancel();
      _callStateSub?.cancel();
      _callPeerJoinedSub?.cancel();
      for (final s in _remoteSubs) {
        s.cancel();
      }
      _remoteSubs.clear();
      return;
    }
    _actuallyDisposed = true;
    unawaited(_hangupLocal(fromRemote: true));
    super.dispose();
  }
}
