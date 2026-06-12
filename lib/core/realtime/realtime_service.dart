import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as socket_io;
import 'package:titra/core/realtime/realtime_origin.dart';

/// Server event names (must match [titra-backend/src/common/constants/security.constants.ts]).
abstract final class RealtimeEvents {
  static const messageCreated = 'message.created';
  static const messageRead = 'message.read';
  static const messageDelivered = 'message.delivered';
  static const presenceUpdated = 'presence.updated';
  static const typingUpdated = 'typing.updated';
  static const callState = 'call.state';
  static const callSignal = 'call.signal';
  static const callPeerJoined = 'call.peer_joined';
}

/// Socket.IO client for namespace `/realtime`. Connects when a session token exists.
class RealtimeService extends ChangeNotifier {
  socket_io.Socket? _socket;
  String? _connectedToken;

  final _messageCreated = StreamController<Map<String, dynamic>>.broadcast();
  final _messageRead = StreamController<Map<String, dynamic>>.broadcast();
  final _messageDelivered = StreamController<Map<String, dynamic>>.broadcast();
  final _typingUpdated = StreamController<Map<String, dynamic>>.broadcast();
  final _presenceUpdated = StreamController<Map<String, dynamic>>.broadcast();
  final _callState = StreamController<Map<String, dynamic>>.broadcast();
  final _callSignal = StreamController<Map<String, dynamic>>.broadcast();
  final _callPeerJoined = StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessageCreated => _messageCreated.stream;

  Stream<Map<String, dynamic>> get onMessageRead => _messageRead.stream;

  Stream<Map<String, dynamic>> get onMessageDelivered =>
      _messageDelivered.stream;

  Stream<Map<String, dynamic>> get onTypingUpdated => _typingUpdated.stream;

  Stream<Map<String, dynamic>> get onPresenceUpdated => _presenceUpdated.stream;

  Stream<Map<String, dynamic>> get onCallState => _callState.stream;

  Stream<Map<String, dynamic>> get onCallSignal => _callSignal.stream;

  Stream<Map<String, dynamic>> get onCallPeerJoined => _callPeerJoined.stream;

  bool get isConnected => _socket?.connected ?? false;

  Future<bool> waitUntilConnected({
    Duration timeout = const Duration(seconds: 6),
    String? token,
  }) async {
    if (isConnected) return true;
    if (token != null && token.isNotEmpty) {
      reconnectIfNeeded(token);
    }

    final completer = Completer<bool>();
    Timer? timer;

    void finish(bool value) {
      if (completer.isCompleted) return;
      completer.complete(value);
    }

    void listener() {
      if (isConnected) {
        finish(true);
      }
    }

    addListener(listener);
    timer = Timer(timeout, () => finish(isConnected));
    listener();

    try {
      return await completer.future;
    } finally {
      timer.cancel();
      removeListener(listener);
    }
  }

  /// Call when [SessionController] token or hydration changes.
  void syncSessionToken(String? token, bool hydrated) {
    if (!hydrated) return;
    if (token == null || token.isEmpty) {
      disconnect();
      return;
    }
    if (token == _connectedToken && _socket != null) {
      if (!isConnected) {
        debugPrint('RealtimeService: socket exists but not connected, calling connect()');
        _socket!.connect();
      }
      return;
    }
    disconnect();
    _connect(token);
  }

  void _connect(String token) {
    _connectedToken = token;
    final url = realtimeSocketUrl();
    try {
      _socket = socket_io.io(
        url,
        socket_io.OptionBuilder()
            .setTransports(['websocket'])
            .setPath('/socket.io/')
            .setAuth({'token': token})
            .enableForceNew()
            .build(),
      );

      _socket!.on(RealtimeEvents.messageCreated, (data) {
        final map = _asJsonMap(data);
        if (map != null) {
          _messageCreated.add(map);
        }
      });

      _socket!.on(RealtimeEvents.typingUpdated, (data) {
        final map = _asJsonMap(data);
        if (map != null) {
          _typingUpdated.add(map);
        }
      });

      _socket!.on(RealtimeEvents.messageRead, (data) {
        final map = _asJsonMap(data);
        if (map != null) {
          _messageRead.add(map);
        }
      });

      _socket!.on(RealtimeEvents.messageDelivered, (data) {
        final map = _asJsonMap(data);
        if (map != null) {
          _messageDelivered.add(map);
        }
      });

      _socket!.on(RealtimeEvents.presenceUpdated, (data) {
        final map = _asJsonMap(data);
        if (map != null) {
          _presenceUpdated.add(map);
        }
      });

      _socket!.on(RealtimeEvents.callState, (data) {
        final map = _asJsonMap(data);
        if (map != null) {
          _callState.add(map);
        }
      });

      _socket!.on(RealtimeEvents.callSignal, (data) {
        final map = _asJsonMap(data);
        if (map != null) {
          _callSignal.add(map);
        }
      });

      _socket!.on(RealtimeEvents.callPeerJoined, (data) {
        final map = _asJsonMap(data);
        if (map != null) {
          _callPeerJoined.add(map);
        }
      });

      _socket!.onConnect((_) {
        debugPrint('RealtimeService connected');
        notifyListeners();
        _flushPendingCallSignals();

        final convId = _currentConversationId;
        if (convId != null && convId.isNotEmpty) {
          debugPrint('RealtimeService re-joining conversation after reconnection: $convId');
          _socket?.emit('conversation.join', {'conversationId': convId});
        }
      });

      _socket!.onDisconnect((_) {
        debugPrint('RealtimeService disconnected');
        notifyListeners();
      });

      _socket!.connect();
    } catch (e, st) {
      debugPrint('RealtimeService connect failed: $e\n$st');
      _socket?.dispose();
      _socket = null;
      _connectedToken = null;
    }
  }

  Map<String, dynamic>? _asJsonMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  void emitTypingUpdate({
    required String conversationId,
    required bool isTyping,
  }) {
    if (!isConnected) return;
    _socket?.emit('typing.update', {
      'conversationId': conversationId,
      'isTyping': isTyping,
    });
  }

  String? _currentConversationId;

  /// Join the Socket.IO room for [conversationId]. Required for `typing.updated`
  /// and for conversation-scoped events. `message.created` is also delivered on
  /// your personal `user:{id}` room so the home chat list can refresh without joining.
  void joinConversation(String conversationId) {
    _currentConversationId = conversationId;
    if (!isConnected) return;
    _socket?.emit('conversation.join', {'conversationId': conversationId});
  }

  void leaveConversation(String conversationId) {
    if (_currentConversationId == conversationId) {
      _currentConversationId = null;
    }
    if (!isConnected) return;
    _socket?.emit('conversation.leave', {'conversationId': conversationId});
  }

  /// WebRTC signaling relay. For 1:1, always set [toUserId] to the remote peer.
  void emitCallSignal({
    required String conversationId,
    required String callSessionId,
    required String signalType,
    required String toUserId,
    required Object payload,
  }) {
    final event = <String, dynamic>{
      'conversationId': conversationId,
      'callSessionId': callSessionId,
      'signalType': signalType,
      'toUserId': toUserId,
      'payload': payload,
    };
    if (!isConnected) {
      debugPrint(
        'RealtimeService.emitCallSignal queued ($signalType): socket not connected',
      );
      _pendingCallSignals.add(event);
      return;
    }
    _socket?.emit('call.signal', event);
  }

  final List<Map<String, dynamic>> _pendingCallSignals = [];

  void _flushPendingCallSignals() {
    if (_pendingCallSignals.isEmpty) return;
    final batch = List<Map<String, dynamic>>.from(_pendingCallSignals);
    _pendingCallSignals.clear();
    for (final event in batch) {
      debugPrint(
        'RealtimeService.emitCallSignal flushed ${event['signalType']}',
      );
      _socket?.emit('call.signal', event);
    }
  }

  void disconnect() {
    _currentConversationId = null;
    _pendingCallSignals.clear();
    _socket?.dispose();
    _socket = null;
    _connectedToken = null;
    notifyListeners();
  }

  /// After app resume, reconnect if the socket dropped while still logged in.
  void reconnectIfNeeded(String? token) {
    if (token == null || token.isEmpty) return;
    if (_connectedToken == token && (_socket?.connected ?? false)) return;
    syncSessionToken(token, true);
  }

  @override
  void dispose() {
    disconnect();
    _messageCreated.close();
    _messageRead.close();
    _messageDelivered.close();
    _typingUpdated.close();
    _presenceUpdated.close();
    _callState.close();
    _callSignal.close();
    _callPeerJoined.close();
    super.dispose();
  }
}
