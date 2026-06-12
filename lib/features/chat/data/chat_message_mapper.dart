import 'dart:convert';

import 'package:titra/core/local_db/daos/messages_dao.dart';
import 'package:titra/core/constants/api_constants.dart';
import 'package:titra/features/chat/data/message_model.dart';
import 'package:titra/features/chat/data/message_plain_codec.dart';

/// Maps REST / Socket.IO message JSON to [MessageModel].
class ChatMessageMapper {
  ChatMessageMapper._();

  static MessageModel fromServerJson(
    Map<String, dynamic> m,
    String myUserId, {
    required bool isGroup,
  }) {
    final senderId = m['senderId']?.toString() ?? '';
    final kind = m['kind']?.toString() ?? 'TEXT';
    final ciphertext = m['ciphertext']?.toString() ?? '';
    final id = m['id']?.toString() ?? '';
    final createdAt = m['createdAt']?.toString();
    final t = createdAt != null
        ? DateTime.tryParse(createdAt)?.toLocal()
        : null;

    Map<String, dynamic>? sender;
    final s = m['sender'];
    if (s is Map) {
      sender = Map<String, dynamic>.from(s);
    }

    final k = kind.toUpperCase();
    var text = MessagePlainCodec.displayText(
      kind: kind,
      ciphertext: ciphertext,
    );
    final isFromMe = senderId == myUserId;

    final status = isFromMe
        ? _outgoingReceiptStatus(m, myUserId)
        : MessageStatus.sent;

    MessageContentKind contentKind = MessageContentKind.text;
    String? voiceUrl;
    int? voiceDurationMs;
    String? imageUrl;
    CallLogPayload? callLog;
    if (k == 'VOICE') {
      contentKind = MessageContentKind.voice;
      voiceDurationMs = MessagePlainCodec.decodeVoiceDurationMs(ciphertext);
      voiceUrl = _firstAudioPublicUrl(m);
    } else if (k == 'FILE') {
      imageUrl = _firstImagePublicUrl(m);
      if (imageUrl != null && imageUrl.isNotEmpty) {
        contentKind = MessageContentKind.image;
        text = 'Photo';
      }
    } else if (k == 'CALL_LOG') {
      final parsed = MessagePlainCodec.decodeCallLogPayload(ciphertext);
      if (parsed != null) {
        contentKind = MessageContentKind.callLog;
        callLog = parsed;
        text = 'Call';
      }
    }

    return MessageModel(
      id: id,
      text: text,
      imageUrl: imageUrl,
      isFromMe: isFromMe,
      timestamp: formatTime(t ?? DateTime.now()),
      status: status,
      senderName: (!isFromMe && isGroup)
          ? (sender?['profileName'] as String?)
          : null,
      // Per-message avatar for anyone who isn’t me (direct + group). ChatScreen uses
      // senderAvatarUrl ?? vm.avatarUrl so 1:1 still has a fallback when the API omits it.
      senderAvatarUrl: !isFromMe
          ? _nonEmptyString(sender?['profileImageUrl'])
          : null,
      clientMessageId: m['clientMessageId']?.toString(),
      contentKind: contentKind,
      voiceAudioUrl: voiceUrl,
      voiceDurationMs: voiceDurationMs,
      callLog: callLog,
    );
  }

  static MessageModel fromLocalRecord(
    MessageWithSenderRow row,
    String myUserId, {
    required bool isGroup,
  }) {
    final message = row.message;
    final sender = row.sender;
    final raw = _decodeRawJson(message.rawJson);
    final isFromMe = message.senderId == myUserId;
    final type = message.type.toUpperCase();
    final timestamp = DateTime.fromMillisecondsSinceEpoch(
      message.sentAt ?? message.createdAtLocal,
    );

    var text = (message.messageText ?? '').trim();
    MessageContentKind contentKind = MessageContentKind.text;
    String? imageUrl;
    String? voiceUrl;
    int? voiceDurationMs;
    CallLogPayload? callLog;

    if (type == 'VOICE') {
      contentKind = MessageContentKind.voice;
      text = text.isNotEmpty ? text : 'Voice message';
      voiceDurationMs =
          _asInt(raw['durationMs']) ??
          MessagePlainCodec.decodeVoiceDurationMs(
            raw['ciphertext']?.toString() ?? '',
          );
      voiceUrl = _attachmentUrl(raw, expectedType: 'AUDIO');
    } else if (type == 'FILE') {
      imageUrl = _attachmentUrl(raw, expectedType: 'IMAGE');
      if (imageUrl != null) {
        contentKind = MessageContentKind.image;
        text = text.isNotEmpty ? text : 'Photo';
      }
    } else if (type == 'CALL_LOG') {
      callLog = MessagePlainCodec.decodeCallLogPayload(
        raw['ciphertext']?.toString() ?? '',
      );
      if (callLog != null) {
        contentKind = MessageContentKind.callLog;
        text = 'Call';
      }
    }

    if (text.isEmpty) {
      text = _fallbackTextForType(type);
    }

    return MessageModel(
      id: message.serverId ?? message.localId,
      text: text,
      imageUrl: imageUrl,
      isFromMe: isFromMe,
      timestamp: formatTime(timestamp),
      status: _statusFromLocal(message.status),
      senderName: (!isFromMe && isGroup)
          ? _nonEmptyString(sender?.displayName)
          : null,
      senderAvatarUrl: !isFromMe ? _nonEmptyString(sender?.photoUrl) : null,
      clientMessageId: message.clientMessageId,
      contentKind: contentKind,
      voiceAudioUrl: voiceUrl,
      voiceDurationMs: voiceDurationMs,
      callLog: callLog,
    );
  }

  static String? _nonEmptyString(Object? v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
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

  static int? _asInt(Object? value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static String _fallbackTextForType(String type) {
    switch (type) {
      case 'VOICE':
        return 'Voice message';
      case 'FILE':
        return 'Photo';
      case 'CALL_LOG':
        return 'Call';
      default:
        return 'Encrypted message';
    }
  }

  static String? _attachmentUrl(
    Map<String, dynamic> raw, {
    required String expectedType,
  }) {
    final attachments = raw['attachments'];
    if (attachments is! List) return null;
    for (final item in attachments) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final type = map['type']?.toString().toUpperCase() ?? '';
      if (type != expectedType) continue;
      final localPath = _nonEmptyString(map['localPath']);
      if (localPath != null) return localPath;
      final publicUrl = _nonEmptyString(map['publicUrl']);
      if (publicUrl != null) return publicUrl;
      final remoteUrl = _nonEmptyString(map['remoteUrl']);
      if (remoteUrl != null) return remoteUrl;
      final storageKey = _nonEmptyString(map['storageKey']);
      final base = ApiConstants.storagePublicBaseUrl.replaceAll(
        RegExp(r'/$'),
        '',
      );
      if (storageKey != null && base.isNotEmpty) {
        return '$base/uploads/$storageKey';
      }
    }
    return null;
  }

  static MessageStatus _statusFromLocal(String rawStatus) {
    switch (rawStatus.toLowerCase()) {
      case 'pending':
      case 'sending':
        return MessageStatus.pending;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      case 'failed':
        return MessageStatus.failed;
      case 'sent':
      default:
        return MessageStatus.sent;
    }
  }

  static String? _firstAudioPublicUrl(Map<String, dynamic> m) {
    final raw = m['attachments'];
    if (raw is! List) return null;
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final type = map['type']?.toString().toUpperCase() ?? '';
      if (type != 'AUDIO') continue;
      final direct = map['publicUrl']?.toString();
      if (direct != null && direct.isNotEmpty) return direct;
      final key = map['storageKey']?.toString();
      final base = ApiConstants.storagePublicBaseUrl.replaceAll(
        RegExp(r'/$'),
        '',
      );
      if (key != null && key.isNotEmpty && base.isNotEmpty) {
        return '$base/uploads/$key';
      }
    }
    return null;
  }

  static String? _firstImagePublicUrl(Map<String, dynamic> m) {
    final raw = m['attachments'];
    if (raw is! List) return null;
    for (final item in raw) {
      if (item is! Map) continue;
      final map = Map<String, dynamic>.from(item);
      final type = map['type']?.toString().toUpperCase() ?? '';
      if (type != 'IMAGE') continue;
      final direct = map['publicUrl']?.toString();
      if (direct != null && direct.isNotEmpty) return direct;
      final key = map['storageKey']?.toString();
      final base = ApiConstants.storagePublicBaseUrl.replaceAll(
        RegExp(r'/$'),
        '',
      );
      if (key != null && key.isNotEmpty && base.isNotEmpty) {
        return '$base/uploads/$key';
      }
    }
    return null;
  }

  static MessageStatus _outgoingReceiptStatus(
    Map<String, dynamic> m,
    String myUserId,
  ) {
    final reads = m['reads'];
    if (reads is List) {
      for (final r in reads) {
        if (r is Map && (r['userId']?.toString() ?? '') != myUserId) {
          return MessageStatus.read;
        }
      }
    }
    final deliveries = m['deliveries'];
    if (deliveries is List) {
      for (final d in deliveries) {
        if (d is Map && (d['userId']?.toString() ?? '') != myUserId) {
          return MessageStatus.delivered;
        }
      }
    }
    return MessageStatus.sent;
  }

  static String formatTime(DateTime t) {
    final h = t.hour > 12 ? t.hour - 12 : (t.hour == 0 ? 12 : t.hour);
    final m = t.minute.toString().padLeft(2, '0');
    final am = t.hour < 12 ? 'AM' : 'PM';
    return '$h:$m $am';
  }
}
