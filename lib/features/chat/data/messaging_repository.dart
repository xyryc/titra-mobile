import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:titra/core/api/api_client.dart';
import 'package:titra/core/local_db/app_database.dart';
import 'package:titra/features/chat/data/chat_message_mapper.dart';
import 'package:titra/features/chat/data/files_repository.dart';
import 'package:titra/features/chat/data/message_model.dart';
import 'package:titra/features/chat/data/message_plain_codec.dart';
import 'package:uuid/uuid.dart';

/// Local-first messaging repository backed by SQLite with remote sync.
class MessagingRepository {
  MessagingRepository(this._api, this._db, this._files);

  final ApiClient _api;
  final AppDatabase _db;
  final FilesRepository _files;
  final Uuid _uuid = const Uuid();

  Stream<List<MessageModel>> watchMessages(
    String conversationId, {
    required String currentUserId,
    required bool isGroup,
  }) {
    return _db.messagesDao.watchMessages(conversationId).map((rows) {
      return rows
          .map(
            (row) => ChatMessageMapper.fromLocalRecord(
              row,
              currentUserId,
              isGroup: isGroup,
            ),
          )
          .toList();
    });
  }

  Map<String, dynamic> _unwrapData(Response<dynamic> response) {
    final data = response.data;
    if (data is Map && data['data'] != null && data['data'] is Map) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  /// Newest-first from API; caller may reverse for chat order.
  Future<List<Map<String, dynamic>>> fetchMessages(
    String conversationId, {
    int limit = 100,
  }) async {
    final response = await _api.get<dynamic>(
      'messages',
      queryParameters: {
        'conversationId': conversationId,
        'limit': limit.toString(),
      },
    );
    final data = _unwrapData(response);
    final raw = data['items'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  Future<void> hydrateConversation(
    String conversationId, {
    required String currentUserId,
    required bool isGroup,
    int limit = 100,
  }) async {
    final raw = await fetchMessages(conversationId, limit: limit);
    await _upsertServerMessages(
      raw.reversed.toList(),
      currentUserId: currentUserId,
      incrementUnreadForIncoming: false,
      fallbackConversationId: conversationId,
      fallbackConversationType: isGroup ? 'GROUP' : 'DIRECT',
    );
    if (raw.isNotEmpty) {
      final lastCreatedAt = _parseTimestampMs(raw.first['createdAt']);
      if (lastCreatedAt != null) {
        await _db.syncDao.setSyncCursor(
          'messages:$conversationId',
          lastCreatedAt.toString(),
        );
      }
    }
  }

  Future<void> sendTextMessageLocal({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String? senderAvatarUrl,
    required String? senderAccountId,
    required bool isGroup,
    required String plaintext,
    String? conversationTitle,
    String? conversationAvatarUrl,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final localId = 'local_${_uuid.v4()}';
    final clientMessageId = _uuid.v4();
    final rawPayload = <String, dynamic>{
      'kind': 'TEXT',
      'plaintext': plaintext,
      'sender': _localSenderPayload(
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
      ),
      'clientMessageId': clientMessageId,
    };

    final operationId = await _enqueueLocalMessage(
      localId: localId,
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      senderAccountId: senderAccountId,
      isGroup: isGroup,
      type: 'TEXT',
      text: plaintext,
      rawPayload: rawPayload,
      createdAt: now,
      conversationTitle: conversationTitle,
      conversationAvatarUrl: conversationAvatarUrl,
    );

    unawaited(_syncQueuedMessage(localId, operationId: operationId));
  }

  Future<void> sendVoiceMessageLocal({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String? senderAvatarUrl,
    required String? senderAccountId,
    required bool isGroup,
    required String filePath,
    required int durationMs,
    String? conversationTitle,
    String? conversationAvatarUrl,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final localId = 'local_${_uuid.v4()}';
    final clientMessageId = _uuid.v4();
    final rawPayload = <String, dynamic>{
      'kind': 'VOICE',
      'durationMs': durationMs,
      'localAttachmentPath': filePath,
      'attachments': [
        {'type': 'AUDIO', 'localPath': filePath},
      ],
      'sender': _localSenderPayload(
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
      ),
      'clientMessageId': clientMessageId,
    };

    final operationId = await _enqueueLocalMessage(
      localId: localId,
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      senderAccountId: senderAccountId,
      isGroup: isGroup,
      type: 'VOICE',
      text: 'Voice message',
      attachmentCount: 1,
      rawPayload: rawPayload,
      createdAt: now,
      conversationTitle: conversationTitle,
      conversationAvatarUrl: conversationAvatarUrl,
    );

    unawaited(_syncQueuedMessage(localId, operationId: operationId));
  }

  Future<void> sendImageMessageLocal({
    required String conversationId,
    required String senderId,
    required String senderName,
    required String? senderAvatarUrl,
    required String? senderAccountId,
    required bool isGroup,
    required String filePath,
    String? conversationTitle,
    String? conversationAvatarUrl,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final localId = 'local_${_uuid.v4()}';
    final clientMessageId = _uuid.v4();
    final rawPayload = <String, dynamic>{
      'kind': 'FILE',
      'localAttachmentPath': filePath,
      'attachments': [
        {'type': 'IMAGE', 'localPath': filePath},
      ],
      'sender': _localSenderPayload(
        senderId: senderId,
        senderName: senderName,
        senderAvatarUrl: senderAvatarUrl,
      ),
      'clientMessageId': clientMessageId,
    };

    final operationId = await _enqueueLocalMessage(
      localId: localId,
      clientMessageId: clientMessageId,
      conversationId: conversationId,
      senderId: senderId,
      senderName: senderName,
      senderAvatarUrl: senderAvatarUrl,
      senderAccountId: senderAccountId,
      isGroup: isGroup,
      type: 'FILE',
      text: 'Photo',
      attachmentCount: 1,
      rawPayload: rawPayload,
      createdAt: now,
      conversationTitle: conversationTitle,
      conversationAvatarUrl: conversationAvatarUrl,
    );

    unawaited(_syncQueuedMessage(localId, operationId: operationId));
  }

  Future<void> retryPendingMessages() async {
    final operations = await _db.syncDao.getPendingOperations(limit: 200);
    for (final operation in operations) {
      if (operation.entityType != 'message') continue;
      await _syncQueuedMessage(operation.entityId, operationId: operation.id);
    }
  }

  Future<void> applyRealtimeMessageCreated(
    Map<String, dynamic> payload, {
    required String currentUserId,
  }) {
    return _upsertServerMessages(
      [payload],
      currentUserId: currentUserId,
      incrementUnreadForIncoming: true,
      fallbackConversationId: payload['conversationId']?.toString(),
    );
  }

  Future<void> applyRealtimeDeliveryReceipt(
    Map<String, dynamic> payload,
  ) async {
    final ids = _extractReceiptMessageIds(payload);
    if (ids.isEmpty) return;
    await _db.messagesDao.markStatusesByServerIds(
      serverIds: ids,
      status: 'delivered',
      deliveredAt: DateTime.now().millisecondsSinceEpoch,
    );
  }

  Future<void> applyRealtimeReadReceipt(Map<String, dynamic> payload) async {
    final ids = _extractReceiptMessageIds(payload);
    if (ids.isEmpty) return;
    await _db.messagesDao.markStatusesByServerIds(
      serverIds: ids,
      status: 'read',
      readAt: DateTime.now().millisecondsSinceEpoch,
    );
    final conversationId = payload['conversationId']?.toString();
    if (conversationId != null && conversationId.isNotEmpty) {
      await _db.conversationsDao.clearUnreadCount(conversationId);
    }
  }

  Future<Map<String, dynamic>> sendTextMessage({
    required String conversationId,
    required String plaintext,
    required String clientMessageId,
  }) async {
    final response = await _api.post<dynamic>(
      'messages',
      data: {
        'conversationId': conversationId,
        'kind': 'TEXT',
        'ciphertext': MessagePlainCodec.encodePlaintext(plaintext),
        'nonce': MessagePlainCodec.randomNonceBase64(),
        'clientMessageId': clientMessageId,
        'expirationPolicy': 'NONE',
      },
    );
    final map = _unwrapData(response);
    if (map.isEmpty) {
      throw StateError('Empty message response');
    }
    return map;
  }

  Future<Map<String, dynamic>> sendVoiceMessage({
    required String conversationId,
    required int durationMs,
    required Map<String, dynamic> attachment,
    required String clientMessageId,
  }) async {
    final response = await _api.post<dynamic>(
      'messages',
      data: {
        'conversationId': conversationId,
        'kind': 'VOICE',
        'ciphertext': MessagePlainCodec.encodeVoiceMetadata(durationMs),
        'nonce': MessagePlainCodec.randomNonceBase64(),
        'clientMessageId': clientMessageId,
        'expirationPolicy': 'NONE',
        'attachments': [attachment],
      },
      showFeedback: false,
    );
    final map = _unwrapData(response);
    if (map.isEmpty) {
      throw StateError('Empty message response');
    }
    return map;
  }

  Future<Map<String, dynamic>> sendFileMessage({
    required String conversationId,
    required Map<String, dynamic> attachment,
    required String clientMessageId,
  }) async {
    final response = await _api.post<dynamic>(
      'messages',
      data: {
        'conversationId': conversationId,
        'kind': 'FILE',
        'ciphertext': MessagePlainCodec.encodePlaintext(''),
        'nonce': MessagePlainCodec.randomNonceBase64(),
        'clientMessageId': clientMessageId,
        'expirationPolicy': 'NONE',
        'attachments': [attachment],
      },
      showFeedback: false,
    );
    final map = _unwrapData(response);
    if (map.isEmpty) {
      throw StateError('Empty message response');
    }
    return map;
  }

  Future<void> markMessagesRead({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;
    await _db.conversationsDao.clearUnreadCount(conversationId);
    await _api.post<dynamic>(
      'messages/read',
      data: {'conversationId': conversationId, 'messageIds': messageIds},
      showFeedback: false,
    );
  }

  Future<void> markMessagesDelivered({
    required String conversationId,
    required List<String> messageIds,
  }) async {
    if (messageIds.isEmpty) return;
    await _api.post<dynamic>(
      'messages/delivered',
      data: {'conversationId': conversationId, 'messageIds': messageIds},
      showFeedback: false,
    );
  }

  Future<String> _enqueueLocalMessage({
    required String localId,
    required String clientMessageId,
    required String conversationId,
    required String senderId,
    required String senderName,
    required String? senderAvatarUrl,
    required String? senderAccountId,
    required bool isGroup,
    required String type,
    required String text,
    required Map<String, dynamic> rawPayload,
    required int createdAt,
    int attachmentCount = 0,
    String? conversationTitle,
    String? conversationAvatarUrl,
  }) async {
    await _db.usersDao.upsertUser(
      UsersCompanion.insert(
        id: senderId,
        username: Value(senderAccountId),
        displayName: Value(senderName),
        photoUrl: Value(senderAvatarUrl),
        phone: Value(senderAccountId),
        updatedAt: Value(createdAt),
      ),
    );

    await _db.messagesDao.upsertMessage(
      MessagesCompanion.insert(
        localId: localId,
        clientMessageId: Value(clientMessageId),
        conversationId: conversationId,
        senderId: senderId,
        type: type,
        messageText: Value(text),
        attachmentCount: Value(attachmentCount),
        createdAtLocal: createdAt,
        updatedAt: Value(createdAt),
        status: const Value('pending'),
        syncState: const Value('queued'),
        rawJson: Value(jsonEncode(rawPayload)),
      ),
    );

    await _upsertOrUpdateConversationPreview(
      conversationId: conversationId,
      localMessageId: localId,
      senderId: senderId,
      preview: text,
      timestamp: createdAt,
      isGroup: isGroup,
      conversationTitle: conversationTitle,
      conversationAvatarUrl: conversationAvatarUrl,
      unreadCount: 0,
    );

    return _db.syncDao.queueOperation(
      entityType: 'message',
      entityId: localId,
      operation: 'create',
      payload: {
        'localId': localId,
        'clientMessageId': clientMessageId,
        'conversationId': conversationId,
        'type': type,
      },
    );
  }

  Future<void> _syncQueuedMessage(String localId, {String? operationId}) async {
    final message = await _db.messagesDao.getMessageByLocalId(localId);
    if (message == null) {
      if (operationId != null) {
        await _db.syncDao.markOperationSynced(operationId);
      }
      return;
    }
    if (message.serverId != null && message.serverId!.isNotEmpty) {
      if (operationId != null) {
        await _db.syncDao.markOperationSynced(operationId);
      }
      return;
    }

    await _db.messagesDao.updateMessageStatus(
      localId: localId,
      status: 'pending',
      syncState: 'syncing',
    );

    try {
      final raw = _decodeRawJson(message.rawJson);
      final clientMessageId =
          message.clientMessageId ?? raw['clientMessageId']?.toString() ?? '';
      late final Map<String, dynamic> created;

      switch (message.type.toUpperCase()) {
        case 'TEXT':
          created = await sendTextMessage(
            conversationId: message.conversationId,
            plaintext:
                raw['plaintext']?.toString() ?? message.messageText ?? '',
            clientMessageId: clientMessageId,
          );
          break;
        case 'VOICE':
          final path = raw['localAttachmentPath']?.toString() ?? '';
          final durationMs = _asInt(raw['durationMs']) ?? 0;
          final bytes = await File(path).readAsBytes();
          final attachment = await _files.uploadAudioBytes(
            conversationId: message.conversationId,
            fileBytes: bytes,
          );
          created = await sendVoiceMessage(
            conversationId: message.conversationId,
            durationMs: durationMs,
            attachment: attachment,
            clientMessageId: clientMessageId,
          );
          break;
        case 'FILE':
          final path = raw['localAttachmentPath']?.toString() ?? '';
          final bytes = await File(path).readAsBytes();
          final mime = FilesRepository.guessImageMimeFromPath(path);
          final name = FilesRepository.guessImageFileNameFromPath(path);
          final attachment = await _files.uploadImageBytes(
            conversationId: message.conversationId,
            fileBytes: bytes,
            encryptedMimeType: mime,
            encryptedName: name,
          );
          created = await sendFileMessage(
            conversationId: message.conversationId,
            attachment: attachment,
            clientMessageId: clientMessageId,
          );
          break;
        default:
          throw StateError('Unsupported queued message type: ${message.type}');
      }

      await _upsertServerMessages(
        [created],
        currentUserId: message.senderId,
        incrementUnreadForIncoming: false,
        preferredLocalId: localId,
        fallbackConversationId: message.conversationId,
      );
      if (operationId != null) {
        await _db.syncDao.markOperationSynced(operationId);
      }
    } catch (error) {
      final messageText = error is DioException
          ? ApiClient.parseErrorMessage(error)
          : error.toString();
      await _db.messagesDao.markMessageFailed(
        localId: localId,
        error: messageText,
      );
      if (operationId != null) {
        await _db.syncDao.scheduleRetry(
          operationId,
          delaySeconds: 30,
          lastError: messageText,
        );
      }
    }
  }

  Future<void> _upsertServerMessages(
    List<Map<String, dynamic>> items, {
    required String currentUserId,
    required bool incrementUnreadForIncoming,
    String? preferredLocalId,
    String? fallbackConversationId,
    String? fallbackConversationType,
  }) async {
    for (final item in items) {
      final conversationId =
          item['conversationId']?.toString() ?? fallbackConversationId;
      if (conversationId == null || conversationId.isEmpty) continue;

      await _upsertSender(item['sender']);

      final serverId = item['id']?.toString();
      final clientMessageId = item['clientMessageId']?.toString();
      final senderId = item['senderId']?.toString() ?? '';
      final existing = await _db.messagesDao.findMessage(
        localId: preferredLocalId,
        serverId: serverId,
        clientMessageId: clientMessageId,
      );
      final localId =
          existing?.localId ??
          preferredLocalId ??
          (serverId != null && serverId.isNotEmpty
              ? 'remote_$serverId'
              : 'remote_${_uuid.v4()}');

      final kind = item['kind']?.toString().toUpperCase() ?? 'TEXT';
      final ciphertext = item['ciphertext']?.toString() ?? '';
      final text = _previewTextForRemote(kind, ciphertext);
      final sentAt =
          _parseTimestampMs(item['createdAt']) ??
          _parseTimestampMs(item['sentAt']) ??
          DateTime.now().millisecondsSinceEpoch;
      final createdAtLocal = existing?.createdAtLocal ?? sentAt;
      final status = senderId == currentUserId
          ? _remoteStatusForOutgoing(item, currentUserId)
          : 'sent';

      await _db.messagesDao.upsertMessage(
        MessagesCompanion.insert(
          localId: localId,
          clientMessageId: Value(clientMessageId),
          serverId: Value(serverId),
          conversationId: conversationId,
          senderId: senderId,
          type: kind,
          messageText: Value(text),
          attachmentCount: Value(_attachmentCount(item['attachments'])),
          sentAt: Value(sentAt),
          createdAtLocal: createdAtLocal,
          updatedAt: Value(sentAt),
          deliveredAt: Value(_parseTimestampMs(item['deliveredAt'])),
          readAt: Value(_parseTimestampMs(item['readAt'])),
          status: Value(status),
          syncState: const Value('synced'),
          errorMessage: const Value(null),
          rawJson: Value(jsonEncode(item)),
        ),
      );

      final isIncoming = senderId.isNotEmpty && senderId != currentUserId;
      final conversation = await _db.conversationsDao.getConversation(
        conversationId,
      );
      final nextUnreadCount =
          incrementUnreadForIncoming && isIncoming && existing == null
          ? (conversation?.unreadCount ?? 0) + 1
          : conversation?.unreadCount ?? 0;

      await _upsertOrUpdateConversationPreview(
        conversationId: conversationId,
        localMessageId: localId,
        senderId: senderId,
        preview: text,
        timestamp: sentAt,
        isGroup:
            (conversation?.type ?? fallbackConversationType ?? 'DIRECT')
                .toUpperCase() ==
            'GROUP',
        conversationTitle: conversation?.title,
        conversationAvatarUrl: conversation?.avatarUrl,
        unreadCount: nextUnreadCount,
      );
    }
  }

  Future<void> _upsertOrUpdateConversationPreview({
    required String conversationId,
    required String localMessageId,
    required String senderId,
    required String preview,
    required int timestamp,
    required bool isGroup,
    required int unreadCount,
    String? conversationTitle,
    String? conversationAvatarUrl,
  }) async {
    final existing = await _db.conversationsDao.getConversation(conversationId);
    if (existing == null) {
      await _db.conversationsDao.upsertConversation(
        ConversationsCompanion.insert(
          id: conversationId,
          type: isGroup ? 'GROUP' : 'DIRECT',
          title: Value(conversationTitle),
          avatarUrl: Value(conversationAvatarUrl),
          lastMessageId: Value(localMessageId),
          lastMessagePreview: Value(preview),
          lastMessageAt: Value(timestamp),
          lastMessageSenderId: Value(senderId),
          unreadCount: Value(unreadCount),
          updatedAt: Value(timestamp),
        ),
      );
      return;
    }
    if (existing.lastMessageAt != null && existing.lastMessageAt! > timestamp) {
      if (existing.unreadCount != unreadCount) {
        await _db.conversationsDao.setUnreadCount(conversationId, unreadCount);
      }
      return;
    }
    await _db.conversationsDao.upsertConversation(
      ConversationsCompanion(
        id: Value(conversationId),
        type: Value(existing.type),
        title: Value(conversationTitle ?? existing.title),
        avatarUrl: Value(conversationAvatarUrl ?? existing.avatarUrl),
        lastMessageId: Value(localMessageId),
        lastMessagePreview: Value(preview),
        lastMessageAt: Value(timestamp),
        lastMessageSenderId: Value(senderId),
        unreadCount: Value(unreadCount),
        isArchived: Value(existing.isArchived),
        isMuted: Value(existing.isMuted),
        serverVersion: Value(existing.serverVersion),
        updatedAt: Value(timestamp),
      ),
    );
  }

  Future<void> _upsertSender(dynamic rawSender) async {
    if (rawSender is! Map) return;
    final sender = Map<String, dynamic>.from(rawSender);
    final id = sender['id']?.toString();
    if (id == null || id.isEmpty) return;
    await _db.usersDao.upsertUser(
      UsersCompanion.insert(
        id: id,
        username: Value(_nonEmptyString(sender['accountId'])),
        displayName: Value(
          _nonEmptyString(sender['profileName']) ??
              _nonEmptyString(sender['displayName']),
        ),
        photoUrl: Value(
          _nonEmptyString(sender['profileImageUrl']) ??
              _nonEmptyString(sender['photoUrl']),
        ),
        phone: Value(_nonEmptyString(sender['accountId'])),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Map<String, dynamic> _localSenderPayload({
    required String senderId,
    required String senderName,
    required String? senderAvatarUrl,
  }) {
    return {
      'id': senderId,
      'profileName': senderName,
      'profileImageUrl': senderAvatarUrl,
    };
  }

  static Map<String, dynamic> _decodeRawJson(String? rawJson) {
    if (rawJson == null || rawJson.isEmpty) return const {};
    try {
      final decoded = jsonDecode(rawJson);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const {};
  }

  static List<String> _extractReceiptMessageIds(Map<String, dynamic> payload) {
    final rawList = payload['messageIds'];
    if (rawList is List) {
      return rawList
          .map((e) => e.toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    final single = payload['messageId']?.toString();
    if (single != null && single.isNotEmpty) {
      return [single];
    }
    return const [];
  }

  static String _previewTextForRemote(String kind, String ciphertext) {
    switch (kind) {
      case 'VOICE':
        return 'Voice message';
      case 'FILE':
        return 'Photo';
      case 'CALL_LOG':
        return 'Call';
      case 'TEXT':
      default:
        return MessagePlainCodec.displayText(
          kind: kind,
          ciphertext: ciphertext,
        );
    }
  }

  static String _remoteStatusForOutgoing(
    Map<String, dynamic> item,
    String myUserId,
  ) {
    final reads = item['reads'];
    if (reads is List) {
      for (final entry in reads.whereType<Map>()) {
        if (entry['userId']?.toString() != myUserId) {
          return 'read';
        }
      }
    }
    final deliveries = item['deliveries'];
    if (deliveries is List) {
      for (final entry in deliveries.whereType<Map>()) {
        if (entry['userId']?.toString() != myUserId) {
          return 'delivered';
        }
      }
    }
    return 'sent';
  }

  static int _attachmentCount(dynamic attachments) {
    if (attachments is List) return attachments.length;
    return 0;
  }

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static int? _parseTimestampMs(Object? raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    final text = raw.toString();
    final asInt = int.tryParse(text);
    if (asInt != null) return asInt;
    return DateTime.tryParse(text)?.millisecondsSinceEpoch;
  }

  static String? _nonEmptyString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}
