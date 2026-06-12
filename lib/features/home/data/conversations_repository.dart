import 'dart:async';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:titra/core/api/api_client.dart';
import 'package:titra/core/local_db/app_database.dart';
import 'package:titra/features/home/data/chat_model.dart';

import '../../../core/local_db/daos/conversations_dao.dart';

/// Remote conversation API plus local-first chat list caching.
class ConversationsRepository {
  ConversationsRepository(this._api, this._db);

  final ApiClient _api;
  final AppDatabase _db;
  final Map<String, Future<void>> _refreshDetailInFlight =
      <String, Future<void>>{};
  final Map<String, DateTime> _refreshDetailCooldownUntil =
      <String, DateTime>{};

  Stream<List<ChatModel>> watchChatsForUser(String currentUserId) {
    return _db.conversationsDao.watchConversationsWithMembers().map((items) {
      return items
          .map((item) => _toChatModel(item, currentUserId))
          .whereType<ChatModel>()
          .toList();
    });
  }

  Future<List<ChatModel>> listChatsForUser(String currentUserId) async {
    await refreshConversations(currentUserId);
    return watchChatsForUser(currentUserId).first;
  }

  Future<void> refreshConversations(String currentUserId) async {
    final response = await _api.get<dynamic>('conversations');
    final body = response.data;
    if (body is! Map<String, dynamic>) return;
    final raw = body['data'];
    if (raw is! List) return;
    for (final item in raw.whereType<Map>()) {
      await _syncConversationEnvelope(
        Map<String, dynamic>.from(item),
        currentUserId: currentUserId,
      );
    }
  }

  /// Creates or returns existing direct conversation; [peerAccountIdTenDigits] must be 10 digits.
  Future<String> createDirectConversation(
    String peerAccountIdTenDigits, {
    String? currentUserId,
  }) async {
    final response = await _api.post<dynamic>(
      'conversations/direct',
      data: {'peerAccountId': peerAccountIdTenDigits},
    );
    final raw = response.data;
    Map<String, dynamic> conv;
    if (raw is Map<String, dynamic>) {
      if (raw['data'] is Map) {
        conv = Map<String, dynamic>.from(raw['data'] as Map);
      } else {
        conv = Map<String, dynamic>.from(raw);
      }
    } else {
      throw StateError('Invalid conversation response');
    }
    final id = conv['id']?.toString();
    if (id == null || id.isEmpty) {
      throw StateError('Missing conversation id');
    }
    return id;
  }

  /// Creates a group chat. [memberAccountIdsTenDigits] must list at least one other member (10-digit IDs).
  /// Returns conversation id, title, member display names, and member user UUIDs for calls.
  Future<CreatedGroupConversation> createGroupConversation({
    required String title,
    required List<String> memberAccountIdsTenDigits,
  }) async {
    final trimmed = title.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Group title is required');
    }
    if (memberAccountIdsTenDigits.isEmpty) {
      throw ArgumentError('Add at least one member');
    }
    final response = await _api.post<dynamic>(
      'conversations/group',
      data: {
        'title': trimmed,
        'members': memberAccountIdsTenDigits
            .map((id) => {'accountId': id})
            .toList(),
      },
    );
    final raw = response.data;
    Map<String, dynamic> conv;
    if (raw is Map<String, dynamic>) {
      if (raw['data'] is Map) {
        conv = Map<String, dynamic>.from(raw['data'] as Map);
      } else {
        conv = Map<String, dynamic>.from(raw);
      }
    } else {
      throw StateError('Invalid group conversation response');
    }
    final id = conv['id']?.toString();
    if (id == null || id.isEmpty) {
      throw StateError('Missing conversation id');
    }
    final resolvedTitle = conv['title']?.toString().trim();
    final membersRaw = conv['members'];
    final names = <String>[];
    final userIds = <String>[];
    if (membersRaw is List) {
      for (final m in membersRaw) {
        if (m is! Map) continue;
        final map = Map<String, dynamic>.from(m);
        final u = map['user'];
        if (u is Map) {
          final um = Map<String, dynamic>.from(u);
          final pn = um['profileName']?.toString();
          if (pn != null && pn.isNotEmpty) names.add(pn);
          final uid = um['id']?.toString();
          if (uid != null && uid.isNotEmpty) userIds.add(uid);
        } else {
          final uid = map['userId']?.toString();
          if (uid != null && uid.isNotEmpty) userIds.add(uid);
        }
      }
    }
    await _syncConversationEnvelope(conv);
    return CreatedGroupConversation(
      conversationId: id,
      title: (resolvedTitle != null && resolvedTitle.isNotEmpty)
          ? resolvedTitle
          : trimmed,
      memberNames: names,
      memberUserIds: userIds,
    );
  }

  /// Loads full conversation (members with user ids) for group call setup.
  Future<CreatedGroupConversation> fetchGroupConversationDetail(
    String conversationId,
  ) async {
    final envelope = await _fetchConversationEnvelope(conversationId);
    if (envelope == null) {
      throw StateError('Invalid conversation response');
    }
    await _syncConversationEnvelope(envelope);
    final tid = envelope['id']?.toString() ?? conversationId;
    final t = envelope['title']?.toString().trim() ?? 'Group';
    final membersRaw = envelope['members'];
    final names = <String>[];
    final userIds = <String>[];
    if (membersRaw is List) {
      for (final m in membersRaw) {
        if (m is! Map) continue;
        final map = Map<String, dynamic>.from(m);
        final u = map['user'];
        if (u is Map) {
          final um = Map<String, dynamic>.from(u);
          final pn = um['profileName']?.toString();
          if (pn != null && pn.isNotEmpty) names.add(pn);
          final uid = um['id']?.toString();
          if (uid != null && uid.isNotEmpty) userIds.add(uid);
        }
      }
    }
    return CreatedGroupConversation(
      conversationId: tid,
      title: t,
      memberNames: names,
      memberUserIds: userIds,
    );
  }

  Future<void> refreshConversationDetail(
    String conversationId, {
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final cooldownUntil = _refreshDetailCooldownUntil[conversationId];
    if (cooldownUntil != null && now.isBefore(cooldownUntil)) {
      return;
    }

    final existing = _refreshDetailInFlight[conversationId];
    if (existing != null) {
      await existing;
      return;
    }

    final future = _refreshConversationDetailInternal(
      conversationId,
      currentUserId: currentUserId,
    );
    _refreshDetailInFlight[conversationId] = future;
    try {
      await future;
    } finally {
      if (identical(_refreshDetailInFlight[conversationId], future)) {
        _refreshDetailInFlight.remove(conversationId);
      }
    }
  }

  Future<void> _refreshConversationDetailInternal(
    String conversationId, {
    String? currentUserId,
  }) async {
    try {
      final envelope = await _fetchConversationEnvelope(conversationId);
      if (envelope == null) return;
      await _syncConversationEnvelope(envelope, currentUserId: currentUserId);
      _refreshDetailCooldownUntil.remove(conversationId);
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        _refreshDetailCooldownUntil[conversationId] = DateTime.now().add(
          _retryDelayFrom429(e),
        );
        return;
      }
      rethrow;
    }
  }

  Duration _retryDelayFrom429(DioException error) {
    final headerValue = error.response?.headers.value('retry-after');
    final seconds = int.tryParse(headerValue ?? '');
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds);
    }
    return const Duration(seconds: 15);
  }

  /// Direct peer UUID (not you) for presence APIs.
  Future<String?> fetchDirectPeerUserId(
    String conversationId,
    String myUserId,
  ) async {
    final envelope = await _fetchConversationEnvelope(conversationId);
    if (envelope == null) return null;
    await _syncConversationEnvelope(envelope, currentUserId: myUserId);
    final membersRaw = envelope['members'];
    if (membersRaw is! List) return null;
    for (final m in membersRaw) {
      if (m is! Map) continue;
      final map = Map<String, dynamic>.from(m);
      final uid = map['userId']?.toString();
      if (uid != null && uid.isNotEmpty && uid != myUserId) {
        return uid;
      }
      final u = map['user'];
      if (u is Map && u['id'] != null) {
        final id = u['id'].toString();
        if (id.isNotEmpty && id != myUserId) return id;
      }
    }
    return null;
  }

  /// True if [userId] has at least one connected realtime socket (shared convo required server-side).
  Future<bool> fetchUserOnline(String userId) async {
    final response = await _api.get<dynamic>(
      'presence/$userId/online',
      showFeedback: false,
    );
    final raw = response.data;
    if (raw is! Map) return false;
    final data = raw['data'];
    if (data is Map && data['online'] != null) {
      final v = data['online'];
      return v == true || v == 1;
    }
    if (raw['online'] != null) {
      final v = raw['online'];
      return v == true || v == 1;
    }
    return false;
  }

  ChatModel? _toChatModel(ConversationWithMembers item, String currentUserId) {
    final conversation = item.conversation;
    final isGroup = conversation.type.toUpperCase() == 'GROUP';
    final lastMessage = conversation.lastMessagePreview ?? 'No messages yet';
    final timestamp = _formatListTimestampFromMillis(
      conversation.lastMessageAt,
    );
    final status = conversation.unreadCount > 0
        ? ChatMessageStatus.received
        : (conversation.lastMessageSenderId == currentUserId &&
                  conversation.lastMessageAt != null
              ? ChatMessageStatus.sent
              : ChatMessageStatus.read);

    if (isGroup) {
      final memberNames = item.members
          .map((m) => (m.displayName ?? '').trim())
          .where((name) => name.isNotEmpty)
          .toList();
      final memberUserIds = item.members.map((m) => m.id).toList();
      return ChatModel(
        id: conversation.id,
        name: (conversation.title ?? '').trim().isNotEmpty
            ? conversation.title!.trim()
            : 'Group',
        avatarUrl: conversation.avatarUrl,
        contactDisplayId: null,
        lastMessage: lastMessage,
        timestamp: timestamp,
        unreadCount: conversation.unreadCount,
        status: status,
        isNumericId: false,
        isGroup: true,
        memberNames: memberNames.isEmpty ? null : memberNames,
        memberUserIds: memberUserIds.isEmpty ? null : memberUserIds,
      );
    }

    final peer = item.members.firstWhere(
      (m) => m.id != currentUserId,
      orElse: () => item.members.isNotEmpty
          ? item.members.first
          : User(
              id: '',
              username: null,
              displayName: 'User',
              photoUrl: null,
              phone: null,
              updatedAt: 0,
            ),
    );
    if (peer.id.isEmpty && item.members.isEmpty) {
      return null;
    }
    final accountId = peer.phone ?? '';
    final digits = accountId.replaceAll(RegExp(r'[^0-9]'), '');
    return ChatModel(
      id: conversation.id,
      name: (peer.displayName ?? '').trim().isNotEmpty
          ? peer.displayName!.trim()
          : ((conversation.title ?? '').trim().isNotEmpty
                ? conversation.title!.trim()
                : 'User'),
      avatarUrl: peer.photoUrl ?? conversation.avatarUrl,
      contactDisplayId: accountId.isNotEmpty ? accountId : null,
      lastMessage: lastMessage,
      timestamp: timestamp,
      unreadCount: conversation.unreadCount,
      status: status,
      isNumericId: digits.length == 10,
      isGroup: false,
      peerUserId: peer.id,
    );
  }

  Future<Map<String, dynamic>?> _fetchConversationEnvelope(
    String conversationId,
  ) async {
    final response = await _api.get<dynamic>(
      'conversations/$conversationId',
      showFeedback: false,
    );
    final raw = response.data;
    if (raw is! Map<String, dynamic>) return null;
    final data = raw['data'];
    if (data is Map<String, dynamic>) return data;
    return raw;
  }

  Future<void> _syncConversationEnvelope(
    Map<String, dynamic> json, {
    String? currentUserId,
  }) async {
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) return;

    final type = json['type']?.toString().toUpperCase() ?? 'DIRECT';
    final title = json['title']?.toString().trim();
    final avatarUrl = _nonEmptyString(json['avatarUrl']);
    final lastMessage = json['lastMessage'] is Map
        ? Map<String, dynamic>.from(json['lastMessage'] as Map)
        : null;
    final lastMessageAt = _parseTimestampMs(
      json['lastMessageAt'] ?? lastMessage?['createdAt'],
    );
    final lastMessageId = _nonEmptyString(lastMessage?['id']);
    final lastMessageSenderId = _nonEmptyString(lastMessage?['senderId']);
    final unreadCount = _asInt(json['unreadCount']) ?? 0;

    final members = _extractConversationMembers(json['members']);
    if (members.isNotEmpty) {
      await _db.usersDao.upsertUsers(
        members.map(
          (member) => UsersCompanion.insert(
            id: member.userId,
            username: Value(member.accountId),
            displayName: Value(member.displayName),
            photoUrl: Value(member.photoUrl),
            phone: Value(member.accountId),
            updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
          ),
        ),
      );
      await _db.conversationsDao.replaceMembers(
        id,
        members.map(
          (member) => ConversationMembersCompanion.insert(
            conversationId: id,
            userId: member.userId,
            role: Value(member.role),
            joinedAt: Value(member.joinedAt),
          ),
        ),
      );
    }

    await _db.conversationsDao.upsertConversation(
      ConversationsCompanion.insert(
        id: id,
        type: type,
        title: Value(_resolvedLocalTitle(type, title, members, currentUserId)),
        avatarUrl: Value(avatarUrl),
        lastMessageId: Value(lastMessageId),
        lastMessagePreview: Value(_previewFromLastMessage(lastMessage)),
        lastMessageAt: Value(lastMessageAt),
        lastMessageSenderId: Value(lastMessageSenderId),
        unreadCount: Value(unreadCount),
        updatedAt: Value(
          lastMessageAt ?? DateTime.now().millisecondsSinceEpoch,
        ),
      ),
    );
  }

  String? _resolvedLocalTitle(
    String type,
    String? serverTitle,
    List<_ConversationMemberPayload> members,
    String? currentUserId,
  ) {
    if (type == 'GROUP') {
      if (serverTitle != null && serverTitle.isNotEmpty) return serverTitle;
      return 'Group';
    }
    if (serverTitle != null && serverTitle.isNotEmpty) return serverTitle;
    for (final member in members) {
      if (member.userId != currentUserId && member.displayName.isNotEmpty) {
        return member.displayName;
      }
    }
    return null;
  }

  List<_ConversationMemberPayload> _extractConversationMembers(dynamic raw) {
    if (raw is! List) return const [];
    final members = <_ConversationMemberPayload>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final nested = map['user'];
      final user = nested is Map ? Map<String, dynamic>.from(nested) : map;
      final userId =
          _nonEmptyString(user['id']) ?? _nonEmptyString(map['userId']);
      if (userId == null) continue;
      members.add(
        _ConversationMemberPayload(
          userId: userId,
          accountId:
              _nonEmptyString(user['accountId']) ??
              _nonEmptyString(map['accountId']),
          displayName:
              _nonEmptyString(user['profileName']) ??
              _nonEmptyString(user['displayName']) ??
              'User',
          photoUrl:
              _nonEmptyString(user['profileImageUrl']) ??
              _nonEmptyString(user['photoUrl']),
          role: _nonEmptyString(map['role']),
          joinedAt: _parseTimestampMs(map['joinedAt']),
        ),
      );
    }
    return members;
  }

  static String? _nonEmptyString(Object? value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
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
    final intValue = int.tryParse(text);
    if (intValue != null) return intValue;
    final dt = DateTime.tryParse(text);
    return dt?.millisecondsSinceEpoch;
  }
}

String _previewFromLastMessage(Map<String, dynamic>? lastMsg) {
  if (lastMsg == null) return 'No messages yet';
  final kind = lastMsg['kind']?.toString() ?? 'TEXT';
  switch (kind) {
    case 'FILE':
      return 'Encrypted file';
    case 'VOICE':
      return 'Voice message';
    case 'SYSTEM':
      return 'System message';
    case 'TEXT':
    default:
      return 'Encrypted message';
  }
}

String _formatListTimestampFromMillis(int? millis) {
  if (millis == null) return '';
  final local = DateTime.fromMillisecondsSinceEpoch(millis).toLocal();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final msgDay = DateTime(local.year, local.month, local.day);
  if (msgDay == today) {
    final hour24 = local.hour;
    final h = hour24 % 12 == 0 ? 12 : hour24 % 12;
    final ampm = hour24 >= 12 ? 'PM' : 'AM';
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m $ampm';
  }
  if (msgDay == today.subtract(const Duration(days: 1))) {
    return 'Yesterday';
  }
  const months = <String>[
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${months[local.month - 1]} ${local.day}';
}

class _ConversationMemberPayload {
  const _ConversationMemberPayload({
    required this.userId,
    required this.accountId,
    required this.displayName,
    required this.photoUrl,
    required this.role,
    required this.joinedAt,
  });

  final String userId;
  final String? accountId;
  final String displayName;
  final String? photoUrl;
  final String? role;
  final int? joinedAt;
}

/// Result of creating or loading a group conversation (for navigation and calls).
class CreatedGroupConversation {
  const CreatedGroupConversation({
    required this.conversationId,
    required this.title,
    required this.memberNames,
    required this.memberUserIds,
  });

  final String conversationId;
  final String title;
  final List<String> memberNames;
  final List<String> memberUserIds;
}
