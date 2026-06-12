/// Type of call for the call log.
enum CallLogType {
  sent,
  received,
  missed,
}

/// Single call log entry for the Calls tab.
class CallLogEntry {
  const CallLogEntry({
    required this.id,
    required this.contactId,
    required this.contactName,
    required this.type,
    required this.timestamp,
    this.durationSeconds,
    this.avatarUrl,
    this.isNumericId = false,
    this.isGroup = false,
    this.participantNames,
    this.isVideo = false,
  });

  final String id;
  final String contactId;
  final String contactName;
  final CallLogType type;
  final String timestamp;
  /// Duration in seconds for completed calls; null for missed.
  final int? durationSeconds;
  final String? avatarUrl;
  final bool isNumericId;
  /// True when this was a group call.
  final bool isGroup;
  /// Display names of participants (for group calls).
  final List<String>? participantNames;
  /// True when this was a video call (vs audio).
  final bool isVideo;

  factory CallLogEntry.fromJson(Map<String, dynamic> json) {
    final participantNamesRaw = json['participantNames'];
    List<String>? participantNames;
    if (participantNamesRaw is List) {
      participantNames = participantNamesRaw.map((e) => e.toString()).toList();
    }
    return CallLogEntry(
      id: json['id'] as String,
      contactId: json['contactId'] as String,
      contactName: json['contactName'] as String,
      type: _typeFromJson(json['type']),
      timestamp: json['timestamp'] as String,
      durationSeconds: (json['durationSeconds'] as num?)?.toInt(),
      avatarUrl: json['avatarUrl'] as String?,
      isNumericId: json['isNumericId'] as bool? ?? false,
      isGroup: json['isGroup'] as bool? ?? false,
      participantNames: participantNames,
      isVideo: json['isVideo'] as bool? ?? false,
    );
  }

  static CallLogType _typeFromJson(dynamic value) {
    if (value == null) return CallLogType.missed;
    switch (value.toString()) {
      case 'sent':
        return CallLogType.sent;
      case 'received':
        return CallLogType.received;
      case 'missed':
      default:
        return CallLogType.missed;
    }
  }
}
