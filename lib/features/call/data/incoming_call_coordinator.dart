import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/core/services/native_call_overlay_manager.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/features/call/data/active_call_guard.dart';
import 'package:titra/features/call/data/call_end_tone.dart';
import 'package:titra/features/call/data/incoming_call_ringtone.dart';
import 'package:titra/features/call/data/calls_repository.dart';
import 'package:titra/features/call/presentation/view/audio_call_screen.dart';
import 'package:titra/features/call/presentation/view/group_audio_call_screen.dart';
import 'package:titra/features/call/presentation/view/group_video_call_screen.dart';
import 'package:titra/features/call/presentation/view/video_call_screen.dart';
import 'package:titra/features/home/data/conversations_repository.dart';

import '../presentation/view_models/audio_call_view_model.dart';
import '../presentation/view_models/group_audio_call_view_model.dart';
import '../presentation/view_models/group_video_call_view_model.dart';
import '../presentation/view_models/video_call_view_model.dart';

/// Ringing 1:1 direct call (offer may arrive on [onCallSignal] before accept).
class IncomingRingingCall {
  IncomingRingingCall({
    required this.callSessionId,
    required this.conversationId,
    required this.callerUserId,
    required this.isVideo,
    this.callerName,
    this.callerAvatarUrl,
    this.callerAccountId,
    this.isGroup = false,
  });

  final String callSessionId;
  final String conversationId;
  final String callerUserId;
  final bool isVideo;
  final String? callerName;
  final String? callerAvatarUrl;
  final String? callerAccountId;

  final bool isGroup;

  /// SDP offer from peer (buffered when signal arrives before UI).
  Map<String, dynamic>? bufferedOffer;

  /// ICE candidates from peer while ringing (coordinator used to drop these; without them the call never connects).
  final List<Map<String, dynamic>> bufferedIceCandidates = [];
}

/// Signals that arrived before [call.state] `started` (Socket order can drop them otherwise).
class _EarlyCallSignals {
  String? callerUserId;
  Map<String, dynamic>? offer;
  final List<Map<String, dynamic>> ice = [];
}

class IncomingJoinBootstrap {
  IncomingJoinBootstrap({this.callerUserId, this.offer, List<Map<String, dynamic>>? preIce})
    : preIce = preIce ?? <Map<String, dynamic>>[];

  final String? callerUserId;
  final Map<String, dynamic>? offer;
  final List<Map<String, dynamic>> preIce;
}

/// Information about an ongoing (active) call for floating UI.
class ActiveCallInfo {
  ActiveCallInfo({
    required this.callSessionId,
    required this.conversationId,
    required this.contactId,
    required this.peerUserId,
    required this.contactName,
    required this.isVideo,
    this.avatarUrl,
    this.isGroup = false,
    this.remotePeerUserIds,
    this.peerNamesById,
  });

  final String callSessionId;
  final String conversationId;
  final String contactId;
  final String peerUserId;
  final String contactName;
  final bool isVideo;
  final String? avatarUrl;
  final bool isGroup;
  final List<String>? remotePeerUserIds;
  final Map<String, String>? peerNamesById;
}

/// Listens globally for [call.state] / [call.signal] and exposes [ringing] for UI.
class IncomingCallCoordinator extends ChangeNotifier {
  IncomingCallCoordinator({
    required GlobalKey<NavigatorState> navigatorKey,
    required CallsRepository callsRepository,
    required ConversationsRepository conversationsRepository,
  }) : _navigatorKey = navigatorKey,
       _calls = callsRepository,
       _conversations = conversationsRepository;

  final GlobalKey<NavigatorState> _navigatorKey;
  GlobalKey<NavigatorState> get navigatorKey => _navigatorKey;
  final CallsRepository _calls;
  final ConversationsRepository _conversations;
  Map<String, dynamic>? _bufferedOffer;
  final List<Map<String, dynamic>> _bufferedIceCandidates = [];
  StreamSubscription<Map<String, dynamic>>? _preScreenCallStateSub;
  StreamSubscription<Map<String, dynamic>>? _preScreenCallSignalSub;
  StreamSubscription<dynamic>? _overlaySub;

  final IncomingCallAssetRingtone _incomingRingtone = IncomingCallAssetRingtone();

  final Map<String, _EarlyCallSignals> _earlyByCallSessionId = {};
  final Map<String, IncomingJoinBootstrap> _acceptedByCallSessionId = {};
  final Set<String> _endedCallSessionIds = {};

  StreamSubscription<Map<String, dynamic>>? _stateSub;
  StreamSubscription<Map<String, dynamic>>? _signalSub;
  RealtimeService? _attachedRealtime;
  SessionController? _session;

  IncomingRingingCall? _ringing;
  IncomingRingingCall? get ringing => _ringing;

  ActiveCallInfo? _activeCall;
  ActiveCallInfo? get activeCall => _activeCall;

  ChangeNotifier? _activeViewModel;
  ChangeNotifier? get activeViewModel => _activeViewModel;

  bool _isCallScreenVisible = false;
  bool get isCallScreenVisible => _isCallScreenVisible;

  void setCallScreenVisible(bool visible) {
    if (_isCallScreenVisible != visible) {
      _isCallScreenVisible = visible;
      notifyListeners();
    }
  }

  Timer? _overlayUpdateTimer;

  void _stopOverlayUpdateTimer() {
    _overlayUpdateTimer?.cancel();
    _overlayUpdateTimer = null;
  }

  void setActiveCall(ActiveCallInfo? info, {ChangeNotifier? viewModel}) {
    _activeCall = info;
    if (viewModel != null) {
      _activeViewModel = viewModel;
    }
    // Logic for system overlay is handled in _AppCoordinator based on lifecycle
    notifyListeners();
  }

  void clearActiveCall(String callSessionId) {
    if (_activeCall?.callSessionId == callSessionId) {
      _stopOverlayUpdateTimer();
      _activeCall = null;
      _activeViewModel = null;
      if (Platform.isAndroid) {
        NativeCallOverlayManager.instance.dismiss();
      }
      notifyListeners();
    }
  }

  Future<void> showActiveCallOverlay() async {
    if (!Platform.isAndroid) return;
    final active = _activeCall;
    if (active == null) return;

    _stopOverlayUpdateTimer();
    await _performOverlayUpdate(active);

    // Start timer to update duration in the bubble while in background
    _overlayUpdateTimer =
        Timer.periodic(const Duration(seconds: 1), (timer) async {
      final currentActive = _activeCall;
      if (currentActive == null) {
        _stopOverlayUpdateTimer();
        return;
      }
      await _performOverlayUpdate(currentActive);
    });
  }

  Future<void> _performOverlayUpdate(ActiveCallInfo active) async {
    final vm = _activeViewModel;
    final duration = switch (vm) {
      AudioCallViewModel v => v.durationFormatted,
      VideoCallViewModel v => v.durationFormatted,
      GroupAudioCallViewModel v => v.durationFormatted,
      GroupVideoCallViewModel v => v.durationFormatted,
      _ => '00:00',
    };

    bool isMuted = false;
    if (vm is AudioCallViewModel) {
      isMuted = vm.isMuted;
    } else if (vm is VideoCallViewModel) {
      isMuted = vm.isMuted;
    } else if (vm is GroupAudioCallViewModel) {
      isMuted = vm.isMuted;
    } else if (vm is GroupVideoCallViewModel) {
      isMuted = vm.isMuted;
    }

    await NativeCallOverlayManager.instance.show(
      callSessionId: active.callSessionId,
      callerName: active.contactName,
      duration: duration,
      isVideo: active.isVideo,
      avatarUrl: active.avatarUrl,
      isMuted: isMuted,
    );
  }

  void onAppResumed() {
    _stopOverlayUpdateTimer();
  }

  Future<void> restoreActiveCallFromOverlay({String? callSessionId}) async {
    debugPrint('[IncomingCallCoordinator] restoreActiveCallFromOverlay sessionId=$callSessionId');
    // Guard: if call screen is already visible, don't push another route
    if (_isCallScreenVisible) {
      debugPrint('[IncomingCallCoordinator] Call screen already visible, skipping duplicate push');
      return;
    }
    _stopOverlayUpdateTimer();
    final active = _activeCall;
    if (active == null) {
      debugPrint('[IncomingCallCoordinator] No active call to restore');
      return;
    }
    if (callSessionId != null &&
        callSessionId.isNotEmpty &&
        active.callSessionId != callSessionId) {
      debugPrint('[IncomingCallCoordinator] SessionId mismatch: $callSessionId != ${active.callSessionId}');
      return;
    }

    // Hide overlay immediately before pushing call screen
    _isCallScreenVisible = true;
    notifyListeners();

    final nav = _navigatorKey.currentState;
    if (nav == null) {
      debugPrint('[IncomingCallCoordinator] Navigator state is NULL');
      return;
    }

    final vm = _activeViewModel;
    debugPrint('[IncomingCallCoordinator] Navigating for vm type: ${vm?.runtimeType}');

    if (vm is AudioCallViewModel) {
      unawaited(nav.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/audio-call'),
          builder: (_) => AudioCallScreen(
            contactName: active.contactName,
            contactId: active.contactId,
            conversationId: active.conversationId,
            peerUserId: active.peerUserId,
            isOutgoing: vm.isOutgoing,
            avatarUrl: active.avatarUrl,
            showTitraId: true,
            callSessionId: active.callSessionId,
            incomingCallCoordinator: this,
          ),
        ),
      ));
      return;
    }

    if (vm is VideoCallViewModel) {
      unawaited(nav.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/video-call'),
          builder: (_) => VideoCallScreen(
            contactName: active.contactName,
            contactId: active.contactId,
            conversationId: active.conversationId,
            peerUserId: active.peerUserId,
            isOutgoing: vm.isOutgoing,
            avatarUrl: active.avatarUrl,
            callSessionId: active.callSessionId,
            incomingCallCoordinator: this,
          ),
        ),
      ));
      return;
    }

    if (vm is GroupAudioCallViewModel) {
      unawaited(nav.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/group-audio-call'),
          builder: (_) => GroupAudioCallScreen(
            groupName: active.contactName,
            conversationId: active.conversationId,
            remotePeerUserIds: active.remotePeerUserIds ?? const <String>[],
            peerNamesById: active.peerNamesById ?? const <String, String>{},
            isOutgoing: vm.isOutgoing,
            callSessionId: active.callSessionId,
            incomingCallCoordinator: this,
          ),
        ),
      ));
      return;
    }

    if (vm is GroupVideoCallViewModel) {
      unawaited(nav.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/group-video-call'),
          builder: (_) => GroupVideoCallScreen(
            groupName: active.contactName,
            conversationId: active.conversationId,
            remotePeerUserIds: active.remotePeerUserIds ?? const <String>[],
            peerNamesById: active.peerNamesById ?? const <String, String>{},
            isOutgoing: vm.isOutgoing,
            callSessionId: active.callSessionId,
            incomingCallCoordinator: this,
          ),
        ),
      ));
    }
  }

  void  startPreScreenBuffering(String callSessionId, RealtimeService realtime) {
    _stopPreScreenBuffering();
    _bufferedOffer = null;
    _bufferedIceCandidates.clear();

    _preScreenCallStateSub = realtime.onCallState.listen((data) {
      if (data['callSessionId'] != callSessionId) return;
      debugPrint('[IncomingCallCoordinator] pre-screen call.state: ${data['state']}');
    });

    _preScreenCallSignalSub = realtime.onCallSignal.listen((data) {
      if (data['callSessionId'] != callSessionId) return;
      final signalType = data['signalType'] as String?;
      debugPrint('[IncomingCallCoordinator] pre-screen buffering signal: $signalType');
      if (signalType == 'offer' || signalType == 'answer') {
        _bufferedOffer = data['payload'] as Map<String, dynamic>?;
      } else if (signalType == 'ice-candidate') {
        final payload = data['payload'];
        if (payload is Map<String, dynamic>) {
          _bufferedIceCandidates.add(payload);
        }
      }
    });
  }
  void _stopPreScreenBuffering() {
    _preScreenCallStateSub?.cancel();
    _preScreenCallStateSub = null;
    _preScreenCallSignalSub?.cancel();
    _preScreenCallSignalSub = null;
  }

  /// Returns buffered offer+ICE and clears buffers (to hand off to ViewModel).
  ({Map<String, dynamic>? offer, List<Map<String, dynamic>> iceCandidates})
  consumeBufferedSignals() {
    final offer = _bufferedOffer;
    final ice = List<Map<String, dynamic>>.from(_bufferedIceCandidates);
    _bufferedOffer = null;
    _bufferedIceCandidates.clear();
    _stopPreScreenBuffering();
    return (offer: offer, iceCandidates: ice);
  }


  void attach(RealtimeService realtime, SessionController session) {
    if (_attachedRealtime == realtime && _stateSub != null) return;
    // App fresh start — ensure no stale overlay from previous session
    if (Platform.isAndroid) NativeCallOverlayManager.instance.dismiss();
    _detachSubsOnly();
    _attachedRealtime = realtime;
    _session = session;
    _stateSub = realtime.onCallState.listen((p) => _onCallState(p, session));
    _signalSub = realtime.onCallSignal.listen((p) => _onCallSignal(p, session));

    // Listen for messages from system overlay bubble
    if (Platform.isAndroid) {
      _overlaySub?.cancel();
      _overlaySub = FlutterOverlayWindow.overlayListener.listen((data) {
        debugPrint('[IncomingCallCoordinator] Received overlay data: $data');
        // String payloads are the only reliable format between isolates
        if (data is! String) return;
        if (data == 'LAUNCH_APP' || data == 'launch_app' || data == 'return_to_call') {
          unawaited(restoreActiveCallFromOverlay());
        } else if (data == 'end_call') {
          unawaited(endActiveCall());
        } else if (data == 'toggle_mute') {
          unawaited(toggleMute());
        }
      });
    }
  }

  /// Ends the currently active call (invoked from UI or system overlay).
  Future<void> endActiveCall() async {
    final vm = _activeViewModel;
    debugPrint('[IncomingCallCoordinator] endActiveCall for vm: ${vm?.runtimeType}');
    if (vm is AudioCallViewModel) {
      await vm.endCall();
    } else if (vm is VideoCallViewModel) {
      await vm.endCall();
    } else if (vm is GroupAudioCallViewModel) {
      await vm.endCall();
    } else if (vm is GroupVideoCallViewModel) {
      await vm.endCall();
    }
  }

  /// Toggles mute state (invoked from system overlay).
  Future<void> toggleMute() async {
    final vm = _activeViewModel;
    debugPrint('[IncomingCallCoordinator] toggleMute for vm: ${vm?.runtimeType}');
    if (vm is AudioCallViewModel) {
      await vm.toggleMute();
    } else if (vm is VideoCallViewModel) {
      await vm.toggleMute();
    } else if (vm is GroupAudioCallViewModel) {
      await vm.toggleMute();
    } else if (vm is GroupVideoCallViewModel) {
      await vm.toggleMute();
    }
  }



  /// When the user opens the app from an FCM/local notification before socket replay.
  void presentFromPushData(Map<String, String> data) {
    if (ActiveCallGuard.hasActiveCall) return;
    final sid = data['callSessionId'] ?? '';
    final convId = data['conversationId'] ?? '';
    final caller = data['initiatorUserId'] ?? '';
    if (sid.isEmpty || convId.isEmpty || caller.isEmpty) return;

    if (_endedCallSessionIds.contains(sid)) {
      debugPrint('[IncomingCall] presentFromPushData blocked — session $sid already ended');
      return;
    }

    final existing = _ringing;
    if (existing != null && existing.callSessionId == sid) {
      notifyListeners();
      unawaited(_syncIncomingRingtone(true));
      return;
    }

    final ct = (data['callType'] ?? '').toUpperCase();
    final isVideo = ct == 'VIDEO';
    final isGroup = data['isGroup'] == '1';

    final ring = IncomingRingingCall(
      callSessionId: sid,
      conversationId: convId,
      callerUserId: caller,
      isVideo: isVideo,
      callerName: data['initiatorName'],
      callerAccountId: data['initiatorAccountId'],
      isGroup: isGroup,
    );
    final bootstrap = _collectJoinBootstrap(sid);
    ring.bufferedOffer = bootstrap.offer;
    ring.bufferedIceCandidates.addAll(bootstrap.preIce);
    _ringing = ring;
    notifyListeners();
    unawaited(_syncIncomingRingtone(true));
  }

  /// Decline action from push when the in-app overlay may never have appeared.
  Future<void> declineIncomingFromNotification(Map<String, String> data) async {
    final sid = data['callSessionId'] ?? '';
    if (sid.isEmpty) return;
    if (_ringing?.callSessionId == sid) {
      await decline();
      return;
    }
    await _syncIncomingRingtone(false);
    await playCallEndedTone();
    _earlyByCallSessionId.remove(sid);
    _acceptedByCallSessionId.remove(sid);
    try {
      await _calls.endCall(sid, reason: 'declined');
    } catch (_) {}
  }

  void _detachSubsOnly() {
    _stateSub?.cancel();
    _signalSub?.cancel();
    _overlaySub?.cancel();
    _stateSub = null;
    _signalSub = null;
    _overlaySub = null;
  }

  @override
  void dispose() {
    unawaited(_syncIncomingRingtone(false));
    _detachSubsOnly();
    _attachedRealtime = null;
    _session = null;
    super.dispose();
  }

  Future<void> _syncIncomingRingtone(bool play) async {
    if (kIsWeb) return;
    try {
      if (play) {
        await _incomingRingtone.start();
      } else {
        await _incomingRingtone.stop();
      }
    } catch (e, st) {
      debugPrint('[IncomingCall] ringtone: $e\n$st');
    }
  }

  void _onCallState(Map<String, dynamic> p, SessionController session) {
    final myId = session.user?.id;
    if (myId == null || myId.isEmpty) return;

    final type = p['type']?.toString();
    if (type == 'started') {
      if (ActiveCallGuard.hasActiveCall) return;
      final call = p['call'];
      if (call is! Map) return;
      final callMap = Map<String, dynamic>.from(call);
      final initiatorId = callMap['initiatorId']?.toString() ?? '';
      if (initiatorId == myId) return;

      bool isGroup = false;
      final conv = callMap['conversation'];
      if (conv is Map) {
        final convType = conv['type']?.toString().toUpperCase();
        isGroup = convType == 'GROUP';
      }

      final id = callMap['id']?.toString() ?? '';
      final convId = callMap['conversationId']?.toString() ?? '';
      if (id.isEmpty || convId.isEmpty) return;

      final callType = callMap['type']?.toString().toUpperCase() ?? 'AUDIO';
      final isVideo = callType == 'VIDEO';

      String? name;
      String? avatarUrl;
      String? accountId;
      final init = callMap['initiator'];
      if (init is Map) {
        final im = Map<String, dynamic>.from(init);
        name = im['profileName']?.toString().trim();
        if (name != null && name.isEmpty) name = null;
        final img = im['profileImageUrl']?.toString().trim();
        avatarUrl = (img != null && img.isNotEmpty) ? img : null;
        final aid = im['accountId']?.toString().trim();
        accountId = (aid != null && aid.isNotEmpty) ? aid : null;
      }

      final early = _earlyByCallSessionId.remove(id);
      final ring = IncomingRingingCall(
        callSessionId: id,
        conversationId: convId,
        callerUserId: initiatorId,
        isVideo: isVideo,
        callerName: name,
        callerAvatarUrl: avatarUrl,
        callerAccountId: accountId,
        isGroup: isGroup,
      );
      if (early != null &&
          early.callerUserId != null &&
          early.callerUserId == initiatorId) {
        if (early.offer != null) {
          ring.bufferedOffer = early.offer;
        }
        ring.bufferedIceCandidates.addAll(early.ice);
      }
      _ringing = ring;
      notifyListeners();
      unawaited(_syncIncomingRingtone(true));
      return;
    }

    if (type == 'ended' || type == 'participant_left') {
      final sid = p['callSessionId']?.toString();
      if (sid != null && sid.isNotEmpty) {
        if (type == 'ended') {
          _endedCallSessionIds.add(sid);
          _earlyByCallSessionId.remove(sid);
          _acceptedByCallSessionId.remove(sid);

          clearActiveCall(sid);
        } else {
          // participant_left: only clear if it's a 1:1 call and the other person left,
          // or if we somehow know we should leave.
          // For now, let the ViewModel handle its own lifecycle and call clearActiveCall.
        }
      }
      if (sid != null &&
          sid.isNotEmpty &&
          _ringing != null &&
          _ringing!.callSessionId == sid) {
        unawaited(_syncIncomingRingtone(false));
        _ringing = null;
        notifyListeners();
      }
    }
  }

  void _onCallSignal(Map<String, dynamic> p, SessionController session) {
    final myId = session.user?.id;
    if (myId == null || myId.isEmpty) return;

    final sid = p['callSessionId']?.toString();
    if (sid == null || sid.isEmpty) return;

    final from = p['fromUserId']?.toString();
    if (from == null || from.isEmpty || from == myId) return;

    final signalType = p['signalType']?.toString();
    final payload = p['payload'];

    final r = _ringing;
    if (r != null && sid == r.callSessionId && from == r.callerUserId) {
      if (signalType == 'offer' && payload is Map) {
        r.bufferedOffer = Map<String, dynamic>.from(payload);
        notifyListeners();
        return;
      }
      if (signalType == 'ice-candidate' && payload is Map) {
        r.bufferedIceCandidates.add(Map<String, dynamic>.from(payload));
        return;
      }
      return;
    }

    if (r == null) {
      if (signalType == 'offer' && payload is Map) {
        final e = _earlyByCallSessionId.putIfAbsent(
          sid,
          () => _EarlyCallSignals(),
        );
        e.callerUserId = from;
        e.offer = Map<String, dynamic>.from(payload);
        return;
      }
      if (signalType == 'ice-candidate' && payload is Map) {
        final e = _earlyByCallSessionId.putIfAbsent(
          sid,
          () => _EarlyCallSignals(),
        );
        e.callerUserId ??= from;
        e.ice.add(Map<String, dynamic>.from(payload));
        return;
      }
    }
  }

  Future<void> decline() async {
    final r = _ringing;
    if (r == null) return;
    await _syncIncomingRingtone(false);
    await playCallEndedTone();
    _earlyByCallSessionId.remove(r.callSessionId);
    _acceptedByCallSessionId.remove(r.callSessionId);
    _ringing = null;
    notifyListeners();
    try {
      await _calls.endCall(r.callSessionId, reason: 'declined');
    } catch (_) {}
  }

  IncomingJoinBootstrap _collectJoinBootstrap(
      String callSessionId, {
        bool includeRinging = true,
      }) {
    Map<String, dynamic>? offer;
    final preIce = <Map<String, dynamic>>[];
    String? callerUserId;

    // Also drain pre-screen buffer
    if (_bufferedOffer != null) {
      offer = Map<String, dynamic>.from(_bufferedOffer!);
      _bufferedOffer = null;
    }
    preIce.addAll(List<Map<String, dynamic>>.from(_bufferedIceCandidates));
    _bufferedIceCandidates.clear();

    final ringing = _ringing;
    if (includeRinging &&
        ringing != null &&
        ringing.callSessionId == callSessionId) {
      callerUserId = ringing.callerUserId;
      if (offer == null && ringing.bufferedOffer != null) {
        offer = Map<String, dynamic>.from(ringing.bufferedOffer!);
      }
      preIce.addAll(
        ringing.bufferedIceCandidates.map(Map<String, dynamic>.from),
      );
    }

    final early = _earlyByCallSessionId.remove(callSessionId);
    callerUserId ??= early?.callerUserId;
    if (offer == null && early?.offer != null) {
      offer = Map<String, dynamic>.from(early!.offer!);
    }
    if (early != null) {
      preIce.addAll(early.ice.map(Map<String, dynamic>.from));
    }

    return IncomingJoinBootstrap(
      callerUserId: callerUserId,
      offer: offer,
      preIce: preIce,
    );
  }


  IncomingJoinBootstrap _mergeJoinBootstrap(
    IncomingJoinBootstrap? primary,
    IncomingJoinBootstrap? secondary,
  ) {
    String? callerUserId = primary?.callerUserId ?? secondary?.callerUserId;
    Map<String, dynamic>? offer;
    if (primary?.offer != null) {
      offer = Map<String, dynamic>.from(primary!.offer!);
    } else if (secondary?.offer != null) {
      offer = Map<String, dynamic>.from(secondary!.offer!);
    }

    final preIce = <Map<String, dynamic>>[];
    if (primary != null) {
      preIce.addAll(primary.preIce.map(Map<String, dynamic>.from));
    }
    if (secondary != null) {
      preIce.addAll(secondary.preIce.map(Map<String, dynamic>.from));
    }

    return IncomingJoinBootstrap(
      callerUserId: callerUserId,
      offer: offer,
      preIce: preIce,
    );
  }

  void _stashAcceptedJoinBootstrap(String callSessionId) {
    final existing = _acceptedByCallSessionId.remove(callSessionId);
    final current = _collectJoinBootstrap(callSessionId);
    _acceptedByCallSessionId[callSessionId] = _mergeJoinBootstrap(
      existing,
      current,
    );
  }

  IncomingJoinBootstrap consumeAcceptedJoinBootstrap(String callSessionId) {
    final accepted = _acceptedByCallSessionId.remove(callSessionId);
    final late = _collectJoinBootstrap(callSessionId, includeRinging: false);
    return _mergeJoinBootstrap(accepted, late);
  }

  /// Accept directly from push notification data — does NOT require [_ringing]
  /// to be set by a socket event (which may not have arrived yet on cold start).
  Future<void> acceptFromPushData(Map<String, String> data) async {
    final nav = _navigatorKey.currentState;
    if (nav == null) return;

    final sid = data['callSessionId'] ?? '';
    final convId = data['conversationId'] ?? '';
    final caller = data['initiatorUserId'] ?? '';
    if (sid.isEmpty || convId.isEmpty || caller.isEmpty) return;

    final ct = (data['callType'] ?? '').toUpperCase();
    final isVideo = ct == 'VIDEO';
    final isGroup = data['isGroup'] == '1';
    final ringing = _ringing?.callSessionId == sid ? _ringing : null;
    final name =
        ringing?.callerName ?? data['initiatorName'] ?? 'Incoming call';
    final accountId =
        ringing?.callerAccountId ?? data['initiatorAccountId'] ?? caller;
    final avatarUrl = ringing?.callerAvatarUrl;

    // Stop ringing and clear state — we're accepting now.
    await _syncIncomingRingtone(false);
    _stashAcceptedJoinBootstrap(sid);

    final bootstrap = _acceptedByCallSessionId[sid];
    debugPrint(
      '[IncomingCall] acceptFromPushData sid=$sid '
      'hasOffer=${bootstrap?.offer != null} preIce=${bootstrap?.preIce.length ?? 0}',
    );
    _ringing = null;
    notifyListeners();

    if (isGroup) {
      try {
        final detail = await _conversations.fetchGroupConversationDetail(
          convId,
        );
        final myId = _session?.user?.id ?? '';
        final remoteIds = detail.memberUserIds
            .where((id) => id != myId)
            .toList();
        if (remoteIds.isEmpty) return;
        final peerNames = <String, String>{};
        for (final uid in remoteIds) {
          final idx = detail.memberUserIds.indexOf(uid);
          peerNames[uid] = idx >= 0 && idx < detail.memberNames.length
              ? detail.memberNames[idx]
              : 'User';
        }
        final title = detail.title.isNotEmpty ? detail.title : 'Group call';
        if (isVideo) {
          await nav.push<void>(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/video_call'),
              builder: (_) => GroupVideoCallScreen(
                groupName: title,
                conversationId: convId,
                remotePeerUserIds: remoteIds,
                peerNamesById: peerNames,
                isOutgoing: false,
                callSessionId: sid,
                incomingCallCoordinator: this,
              ),
            ),
          );
        } else {
          await nav.push<void>(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/audio_call'),
              builder: (_) => GroupAudioCallScreen(
                groupName: title,
                conversationId: convId,
                remotePeerUserIds: remoteIds,
                peerNamesById: peerNames,
                isOutgoing: false,
                callSessionId: sid,
                incomingCallCoordinator: this,
              ),
            ),
          );
        }
      } catch (e, st) {
        debugPrint('[IncomingCall] group acceptFromPushData: $e\n$st');
      }
      return;
    }

    if (isVideo) {
      await nav.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/video_call'),
          builder: (_) => VideoCallScreen(
            contactName: name,
            contactId: accountId,
            conversationId: convId,
            peerUserId: caller,
            isOutgoing: false,
            showTitraId: false,
            avatarUrl: avatarUrl,
            callSessionId: sid,
            remoteOffer: bootstrap?.offer,
            preBufferedIceCandidates: bootstrap?.preIce,
            incomingCallCoordinator: this,
          )
        )
      );
    } else {
      await nav.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/audio_call'),
          builder: (_) => AudioCallScreen(
            contactName: name,
            contactId: accountId,
            conversationId: convId,
            peerUserId: caller,
            isOutgoing: false,
            showTitraId: false,
            avatarUrl: avatarUrl,
            callSessionId: sid,
            remoteOffer: bootstrap?.offer,
            preBufferedIceCandidates: bootstrap?.preIce,
            incomingCallCoordinator: this,
          ),
        ),
      );
    }
  }

  Future<void> accept() async {
    final r = _ringing;
    if (r == null) return;
    final nav = _navigatorKey.currentState;
    if (nav == null) return;

    await _syncIncomingRingtone(false);
    _stashAcceptedJoinBootstrap(r.callSessionId);
    final bootstrap = _acceptedByCallSessionId[r.callSessionId];
    _ringing = null;
    notifyListeners();

    final name = r.callerName ?? 'Incoming call';
    final displayId = r.callerAccountId ?? r.callerUserId;

    if (r.isGroup) {
      try {
        final detail = await _conversations.fetchGroupConversationDetail(
          r.conversationId,
        );
        final myId = _session?.user?.id ?? '';
        final remoteIds = detail.memberUserIds
            .where((id) => id != myId)
            .toList();
        if (remoteIds.isEmpty) {
          return;
        }
        final peerNames = <String, String>{};
        for (final uid in remoteIds) {
          final idx = detail.memberUserIds.indexOf(uid);
          final peerName = idx >= 0 && idx < detail.memberNames.length
              ? detail.memberNames[idx]
              : 'User';
          peerNames[uid] = peerName;
        }
        final title = detail.title.isNotEmpty ? detail.title : 'Group call';
        if (r.isVideo) {
          await nav.push<void>(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/video_call'),
              builder: (_) => GroupVideoCallScreen(
                groupName: title,
                conversationId: r.conversationId,
                remotePeerUserIds: remoteIds,
                peerNamesById: peerNames,
                isOutgoing: false,
                callSessionId: r.callSessionId,
                incomingCallCoordinator: this,
              ),
            ),
          );
        } else {
          await nav.push<void>(
            MaterialPageRoute<void>(
              settings: const RouteSettings(name: '/audio_call'),
              builder: (_) => GroupAudioCallScreen(
                groupName: title,
                conversationId: r.conversationId,
                remotePeerUserIds: remoteIds,
                peerNamesById: peerNames,
                isOutgoing: false,
                callSessionId: r.callSessionId,
                incomingCallCoordinator: this,
              ),
            ),
          );
        }
      } catch (e, st) {
        debugPrint('[IncomingCall] group accept: $e\n$st');
      }
      return;
    }

    if (r.isVideo) {
      await nav.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/video_call'),
          builder: (_) => VideoCallScreen(
            contactName: name,
            contactId: displayId,
            conversationId: r.conversationId,
            peerUserId: r.callerUserId,
            isOutgoing: false,
            showTitraId: false,
            avatarUrl: r.callerAvatarUrl,
            callSessionId: r.callSessionId,
            remoteOffer: bootstrap?.offer,
            preBufferedIceCandidates: bootstrap?.preIce,
            incomingCallCoordinator: this,
          ),
        ),
      );
    } else {
      await nav.push<void>(
        MaterialPageRoute<void>(
          settings: const RouteSettings(name: '/audio_call'),
          builder: (_) => AudioCallScreen(
            contactName: name,
            contactId: displayId,
            conversationId: r.conversationId,
            peerUserId: r.callerUserId,
            isOutgoing: false,
            showTitraId: false,
            avatarUrl: r.callerAvatarUrl,
            callSessionId: r.callSessionId,
            remoteOffer: bootstrap?.offer,
            preBufferedIceCandidates: bootstrap?.preIce,
            incomingCallCoordinator: this,
          ),
        ),
      );
    }
  }
}
