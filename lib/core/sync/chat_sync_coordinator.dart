import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:titra/core/local_db/app_database.dart';
import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/features/chat/data/messaging_repository.dart';

class ChatSyncCoordinator {
  ChatSyncCoordinator({
    required AppDatabase db,
    required RealtimeService realtime,
    required MessagingRepository messagingRepository,
    required SessionController sessionController,
  }) : _db = db,
       _realtime = realtime,
       _messaging = messagingRepository,
       _session = sessionController {
    _attach();
  }

  final AppDatabase _db;
  final RealtimeService _realtime;
  final MessagingRepository _messaging;
  final SessionController _session;

  StreamSubscription<Map<String, dynamic>>? _messageCreatedSub;
  StreamSubscription<Map<String, dynamic>>? _messageDeliveredSub;
  StreamSubscription<Map<String, dynamic>>? _messageReadSub;
  VoidCallback? _realtimeListener;

  void _attach() {
    _messageCreatedSub = _realtime.onMessageCreated.listen(
      _handleMessageCreated,
    );
    _messageDeliveredSub = _realtime.onMessageDelivered.listen(
      _handleMessageDelivered,
    );
    _messageReadSub = _realtime.onMessageRead.listen(_handleMessageRead);
    _realtimeListener = () {
      if (_realtime.isConnected && _session.user?.id != null) {
        unawaited(_messaging.retryPendingMessages());
      }
    };
    _realtime.addListener(_realtimeListener!);
  }

  String? get _currentUserId => _session.user?.id;

  Future<void> _handleMessageCreated(Map<String, dynamic> payload) async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;
    await _messaging.applyRealtimeMessageCreated(
      payload,
      currentUserId: userId,
    );
  }

  Future<void> _handleMessageDelivered(Map<String, dynamic> payload) {
    return _messaging.applyRealtimeDeliveryReceipt(payload);
  }

  Future<void> _handleMessageRead(Map<String, dynamic> payload) {
    return _messaging.applyRealtimeReadReceipt(payload);
  }

  Future<void> hydrateConversation(String conversationId) async {
    final userId = _currentUserId;
    if (userId == null || userId.isEmpty) return;
    final conversation = await _db.conversationsDao.getConversation(
      conversationId,
    );
    await _messaging.hydrateConversation(
      conversationId,
      currentUserId: userId,
      isGroup: conversation?.type.toUpperCase() == 'GROUP',
    );
  }

  void dispose() {
    if (_realtimeListener != null) {
      _realtime.removeListener(_realtimeListener!);
      _realtimeListener = null;
    }
    unawaited(_messageCreatedSub?.cancel());
    unawaited(_messageDeliveredSub?.cancel());
    unawaited(_messageReadSub?.cancel());
    _messageCreatedSub = null;
    _messageDeliveredSub = null;
    _messageReadSub = null;
  }
}
