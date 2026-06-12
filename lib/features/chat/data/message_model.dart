/// How the bubble should render message body (beyond status / sender meta).
enum MessageContentKind { text, voice, image, callLog }

/// Server-written call history row (`kind: CALL_LOG`).
enum CallLogOutcome { completed, missed, cancelled }

class CallLogPayload {
  const CallLogPayload({
    required this.isVideo,
    required this.outcome,
    this.durationSec,
  });

  final bool isVideo;
  final CallLogOutcome outcome;
  final int? durationSec;
}

/// Single message in a conversation.
class MessageModel {
  const MessageModel({
    required this.id,
    required this.text,
    this.imageUrl,
    required this.isFromMe,
    required this.timestamp,
    this.status = MessageStatus.sent,
    this.senderName,
    this.senderAvatarUrl,
    this.clientMessageId,
    this.contentKind = MessageContentKind.text,
    this.voiceAudioUrl,
    this.voiceDurationMs,
    this.callLog,
  });

  final String id;
  final String text;
  final String? imageUrl;
  final bool isFromMe;
  final String timestamp;
  final MessageStatus status;

  /// Display name of sender (for group chats).
  final String? senderName;

  /// Avatar URL of sender (for group chats).
  final String? senderAvatarUrl;

  /// Correlates optimistic UI with `message.created` / REST before server `id` is known.
  final String? clientMessageId;

  final MessageContentKind contentKind;
  final String? voiceAudioUrl;
  final int? voiceDurationMs;

  /// Set when [contentKind] is [MessageContentKind.callLog].
  final CallLogPayload? callLog;

  MessageModel copyWith({
    String? id,
    String? text,
    String? imageUrl,
    bool? isFromMe,
    String? timestamp,
    MessageStatus? status,
    String? senderName,
    String? senderAvatarUrl,
    String? clientMessageId,
    MessageContentKind? contentKind,
    String? voiceAudioUrl,
    int? voiceDurationMs,
    CallLogPayload? callLog,
  }) {
    return MessageModel(
      id: id ?? this.id,
      text: text ?? this.text,
      imageUrl: imageUrl ?? this.imageUrl,
      isFromMe: isFromMe ?? this.isFromMe,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      senderName: senderName ?? this.senderName,
      senderAvatarUrl: senderAvatarUrl ?? this.senderAvatarUrl,
      clientMessageId: clientMessageId ?? this.clientMessageId,
      contentKind: contentKind ?? this.contentKind,
      voiceAudioUrl: voiceAudioUrl ?? this.voiceAudioUrl,
      voiceDurationMs: voiceDurationMs ?? this.voiceDurationMs,
      callLog: callLog ?? this.callLog,
    );
  }
}

enum MessageStatus {
  /// Local-only optimistic row or actively syncing.
  pending,

  /// Single tick: accepted by server / leaving device.
  sent,

  /// Double tick (grey): at least one other member received it.
  delivered,

  /// Double tick (accent): at least one other member read it.
  read,

  /// Failed to sync to the backend.
  failed,
}
