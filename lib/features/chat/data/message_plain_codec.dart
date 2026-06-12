import 'dart:convert';
import 'dart:math';

import 'package:titra/features/chat/data/message_model.dart';

/// Placeholder "encryption" for development: stores UTF-8 text as base64 in
/// [ciphertext]. Real E2E should replace this with libsodium / Signal-style crypto.
///
/// Recipients using the same codec see readable text; others see [fallbackLabel].
class MessagePlainCodec {
  MessagePlainCodec._();

  static const String _fallbackLabel = 'Encrypted message';

  /// Opaque payload for POST /messages (server stores as-is).
  static String encodePlaintext(String plaintext) {
    return base64Encode(utf8.encode(plaintext));
  }

  /// Base64 JSON metadata for `kind: VOICE` (duration for UI).
  static String encodeVoiceMetadata(int durationMs) {
    final json = jsonEncode({'durationMs': durationMs});
    return base64Encode(utf8.encode(json));
  }

  /// Parses [encodeVoiceMetadata] output; returns null if missing or invalid.
  static int? decodeVoiceDurationMs(String ciphertext) {
    try {
      final bytes = base64Decode(ciphertext);
      final obj = jsonDecode(utf8.decode(bytes));
      if (obj is! Map) return null;
      final raw = obj['durationMs'];
      if (raw is int) return raw;
      if (raw is num) return raw.round();
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Parses server `CALL_LOG` ciphertext (base64 JSON).
  static CallLogPayload? decodeCallLogPayload(String ciphertext) {
    try {
      final bytes = base64Decode(ciphertext);
      final obj = jsonDecode(utf8.decode(bytes));
      if (obj is! Map) return null;
      if (obj['v'] != 1) return null;
      final callType = obj['callType']?.toString().toUpperCase() ?? 'AUDIO';
      final rawOutcome = obj['outcome']?.toString().toLowerCase() ?? '';
      CallLogOutcome outcome;
      switch (rawOutcome) {
        case 'completed':
          outcome = CallLogOutcome.completed;
          break;
        case 'missed':
          outcome = CallLogOutcome.missed;
          break;
        case 'cancelled':
          outcome = CallLogOutcome.cancelled;
          break;
        default:
          return null;
      }
      final ds = obj['durationSec'];
      int? durationSec;
      if (ds is int) {
        durationSec = ds;
      } else if (ds is num) {
        durationSec = ds.round();
      }
      return CallLogPayload(
        isVideo: callType == 'VIDEO',
        outcome: outcome,
        durationSec: durationSec,
      );
    } catch (_) {
      return null;
    }
  }

  /// 12-byte nonce as base64 (required by API; not used for real crypto here).
  static String randomNonceBase64() {
    final bytes = List<int>.generate(12, (_) => Random.secure().nextInt(256));
    return base64Encode(bytes);
  }

  /// Human-readable line in the bubble for [kind] + [ciphertext].
  static String displayText({
    required String kind,
    required String ciphertext,
  }) {
    final k = kind.toUpperCase();
    if (k != 'TEXT') {
      switch (k) {
        case 'FILE':
          return 'Encrypted file';
        case 'VOICE':
          return 'Voice message';
        case 'SYSTEM':
          return 'System message';
        case 'CALL_LOG':
          return 'Call';
        default:
          return _fallbackLabel;
      }
    }
    try {
      final bytes = base64Decode(ciphertext);
      final s = utf8.decode(bytes);
      if (s.isEmpty) return _fallbackLabel;
      return s;
    } catch (_) {
      return _fallbackLabel;
    }
  }
}
