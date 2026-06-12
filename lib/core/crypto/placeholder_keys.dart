import 'dart:convert';
import 'dart:math';

/// Temporary random base64 keys so `/auth/register` accepts the payload.
/// Replace with real Signal / X3DH material when integrating end-to-end crypto.
class PlaceholderKeys {
  static String _randomB64(int byteLength) {
    final bytes = List<int>.generate(byteLength, (_) => Random.secure().nextInt(256));
    return base64Encode(bytes);
  }

  static String get identityPublicKey => _randomB64(32);
  static String get signedPreKey => _randomB64(32);
  static String get signedPreKeySignature => _randomB64(64);
  static String get deviceIdentityPublicKey => _randomB64(32);
  static String get deviceSignedPreKey => _randomB64(32);
  static String get deviceSignedPreKeySig => _randomB64(64);

  static List<Map<String, dynamic>> oneTimePreKeys({int count = 2}) {
    return List.generate(
      count,
      (i) => {
        'keyId': i + 1,
        'publicKey': _randomB64(32),
      },
    );
  }
}
