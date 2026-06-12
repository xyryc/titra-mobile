/// One row from `GET calls/history` for the Calls tab.
class CallHistoryEntry {
  CallHistoryEntry({
    required this.callSessionId,
    required this.conversationId,
    required this.callType,
    required this.conversationType,
    required this.direction,
    required this.outcome,
    required this.displayTitle,
    this.durationSec,
    required this.createdAt,
    this.peerAvatarUrl,
    this.peerUserId,
  });

  final String callSessionId;
  final String conversationId;
  final String callType;
  final String conversationType;
  final String direction;
  final String outcome;
  final String displayTitle;
  final int? durationSec;
  final DateTime createdAt;
  final String? peerAvatarUrl;
  final String? peerUserId;

  bool get isGroup => conversationType.toUpperCase() == 'GROUP';
  bool get isVideo => callType.toUpperCase() == 'VIDEO';

  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) {
    final peer = json['peer'];
    String? avatar;
    String? peerId;
    if (peer is Map) {
      final m = Map<String, dynamic>.from(peer);
      final u = m['profileImageUrl'];
      avatar = u is String && u.isNotEmpty ? u : null;
      final id = m['id'];
      peerId = id is String ? id : null;
    }
    final createdRaw = json['createdAt'];
    final DateTime created = _parseHistoryInstant(createdRaw);

    return CallHistoryEntry(
      callSessionId: json['callSessionId'] as String? ?? '',
      conversationId: json['conversationId'] as String? ?? '',
      callType: json['callType'] as String? ?? 'AUDIO',
      conversationType: json['conversationType'] as String? ?? 'DIRECT',
      direction: json['direction'] as String? ?? 'incoming',
      outcome: json['outcome'] as String? ?? 'missed',
      displayTitle: json['displayTitle'] as String? ?? 'Call',
      durationSec: _parseInt(json['durationSec']),
      createdAt: created,
      peerAvatarUrl: avatar,
      peerUserId: peerId,
    );
  }

  /// API sends ISO-8601 (e.g. from Prisma `toISOString()`). Normalise to UTC for storage.
  static DateTime _parseHistoryInstant(Object? raw) {
    if (raw is! String || raw.isEmpty) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) {
      return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
    }
    if (parsed.isUtc) return parsed;
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    );
  }

  static int? _parseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }
}
