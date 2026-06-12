/// Status of the last message for UI (read receipts, etc.).
enum ChatMessageStatus {
  sent,
  received,
  read,
}

/// Single chat / contact for the home list.
class ChatModel {
  const ChatModel({
    required this.id,
    required this.name,
    this.avatarUrl,
    this.contactDisplayId,
    required this.lastMessage,
    required this.timestamp,
    this.unreadCount = 0,
    this.status = ChatMessageStatus.read,
    this.isNumericId = false,
    this.isGroup = false,
    this.memberNames,
    this.memberUserIds,
    this.peerUserId,
  });

  final String id;
  final String name;
  final String? avatarUrl;
  /// 10-digit ID for header (e.g. 849-392-1029). If null, use name when isNumericId.
  final String? contactDisplayId;
  final String lastMessage;
  final String timestamp;
  final int unreadCount;
  final ChatMessageStatus status;
  /// True when name is a 10-digit ID (e.g. 884-902-1102).
  final bool isNumericId;
  /// True when this chat is a group (multiple participants).
  final bool isGroup;
  /// Display names of group members (for group chats).
  final List<String>? memberNames;

  /// Member user UUIDs (for group calls / mesh). May exclude or include self depending on API.
  final List<String>? memberUserIds;

  /// Other user’s UUID in a direct chat (for presence); null for groups / unknown.
  final String? peerUserId;

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    final memberNamesRaw = json['memberNames'];
    List<String>? memberNames;
    if (memberNamesRaw is List) {
      memberNames = memberNamesRaw.map((e) => e.toString()).toList();
    }
    final memberUserIdsRaw = json['memberUserIds'];
    List<String>? memberUserIds;
    if (memberUserIdsRaw is List) {
      memberUserIds = memberUserIdsRaw.map((e) => e.toString()).toList();
    }
    return ChatModel(
      id: json['id'] as String,
      name: json['name'] as String,
      avatarUrl: json['avatarUrl'] as String?,
      contactDisplayId: json['contactDisplayId'] as String?,
      lastMessage: json['lastMessage'] as String,
      timestamp: json['timestamp'] as String,
      unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
      status: _statusFromJson(json['status']),
      isNumericId: json['isNumericId'] as bool? ?? false,
      isGroup: json['isGroup'] as bool? ?? false,
      memberNames: memberNames,
      memberUserIds: memberUserIds,
      peerUserId: json['peerUserId'] as String?,
    );
  }

  static ChatMessageStatus _statusFromJson(dynamic value) {
    if (value == null) return ChatMessageStatus.read;
    switch (value.toString()) {
      case 'sent':
        return ChatMessageStatus.sent;
      case 'received':
        return ChatMessageStatus.received;
      case 'read':
      default:
        return ChatMessageStatus.read;
    }
  }
}
