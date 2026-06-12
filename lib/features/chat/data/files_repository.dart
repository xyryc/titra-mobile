import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:titra/core/api/api_client.dart';
import 'package:titra/core/constants/api_constants.dart';

/// Upload-intent flow for binary blobs (e.g. voice). Storage PUT uses a bare [Dio] instance
/// so the session token is not sent to the object-storage host.
class FilesRepository {
  FilesRepository(this._api) {
    _putDio = Dio(
      BaseOptions(
        connectTimeout: ApiConstants.connectTimeout,
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: ApiConstants.receiveTimeout,
      ),
    );
  }

  final ApiClient _api;
  late final Dio _putDio;

  static String sha256HexOfBytes(Uint8List bytes) {
    return sha256.convert(bytes).toString();
  }

  static String guessImageMimeFromPath(String path) {
    final lower = path.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
    return 'image/jpeg';
  }

  static String guessImageFileNameFromPath(String path) {
    final normalized = path.replaceAll('\\', '/');
    final name = normalized.split('/').last;
    return name.isEmpty ? 'photo.jpg' : name;
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

  /// Returns intent fields plus [sha256Hex] used for the upload.
  /// When [sessionUpload] is true, send bytes with [putIntentBinary] (uses session cookie), not [_putDio].
  Future<
      ({
        String intentId,
        String uploadUrl,
        String storageKey,
        String sha256Hex,
        bool sessionUpload,
      })> _createBinaryUploadIntent({
    required String conversationId,
    required Uint8List fileBytes,
    required String apiAttachmentType,
    required String encryptedMimeType,
    required String encryptedName,
  }) async {
    final sha256Hex = sha256HexOfBytes(fileBytes);
    final response = await _api.post<dynamic>(
      'files/upload-intents',
      data: {
        'conversationId': conversationId,
        'type': apiAttachmentType,
        'ciphertextSha256': sha256Hex,
        'encryptedMimeType': encryptedMimeType,
        'encryptedSizeBytes': fileBytes.length,
        'encryptedName': encryptedName,
      },
      showFeedback: false,
    );
    final map = _unwrapData(response);
    final intentId = map['intentId']?.toString() ?? '';
    final uploadUrl = map['uploadUrl']?.toString() ?? '';
    final storageKey = map['storageKey']?.toString() ?? '';
    final sessionUpload = map['uploadAuth']?.toString().toLowerCase() == 'session';
    if (intentId.isEmpty || storageKey.isEmpty) {
      throw StateError('Invalid upload-intent response');
    }
    if (!sessionUpload && uploadUrl.isEmpty) {
      throw StateError('Invalid upload-intent response');
    }
    return (
      intentId: intentId,
      uploadUrl: uploadUrl,
      storageKey: storageKey,
      sha256Hex: sha256Hex,
      sessionUpload: sessionUpload,
    );
  }

  Future<
      ({
        String intentId,
        String uploadUrl,
        String storageKey,
        String sha256Hex,
        bool sessionUpload,
      })> createAudioUploadIntent({
    required String conversationId,
    required Uint8List fileBytes,
    String encryptedMimeType = 'audio/mp4',
  }) {
    return _createBinaryUploadIntent(
      conversationId: conversationId,
      fileBytes: fileBytes,
      apiAttachmentType: 'AUDIO',
      encryptedMimeType: encryptedMimeType,
      encryptedName: 'voice.m4a',
    );
  }

  Future<
      ({
        String intentId,
        String uploadUrl,
        String storageKey,
        String sha256Hex,
        bool sessionUpload,
      })> createImageUploadIntent({
    required String conversationId,
    required Uint8List fileBytes,
    required String encryptedMimeType,
    required String encryptedName,
  }) {
    return _createBinaryUploadIntent(
      conversationId: conversationId,
      fileBytes: fileBytes,
      apiAttachmentType: 'IMAGE',
      encryptedMimeType: encryptedMimeType,
      encryptedName: encryptedName,
    );
  }

  /// Cloudinary path: multipart POST (same stack as profile photo). Raw PUT + Nest
  /// `rawBody` does not reliably expose binary bodies, which caused HTTP 400.
  Future<void> postIntentContentMultipart({
    required String intentId,
    required Uint8List bytes,
    required String sha256Hex,
    required String filename,
  }) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: filename),
    });
    await _api.postMultipart<dynamic>(
      'files/upload-intents/$intentId/content',
      data: form,
      headers: {'x-content-sha256': sha256Hex},
      showFeedback: false,
    );
  }

  Future<void> putBytesToUploadUrl({
    required String uploadUrl,
    required Uint8List bytes,
    required String sha256Hex,
    String contentType = 'application/octet-stream',
  }) async {
    await _putDio.put<List<int>>(
      uploadUrl,
      data: bytes,
      options: Options(
        headers: {
          'Content-Type': contentType,
          'x-content-sha256': sha256Hex,
        },
        responseType: ResponseType.bytes,
        followRedirects: true,
        validateStatus: (s) => s != null && s >= 200 && s < 300,
      ),
    );
  }

  Future<Map<String, dynamic>> completeUpload(String intentId) async {
    final response = await _api.post<dynamic>(
      'files/upload-intents/complete',
      data: {'intentId': intentId},
      showFeedback: false,
    );
    final map = _unwrapData(response);
    final att = map['attachment'];
    if (att is! Map) {
      throw StateError('Invalid complete-upload response');
    }
    return Map<String, dynamic>.from(att);
  }

  /// Shapes attachment JSON for `POST /messages` so Nest [ValidationPipe] (whitelist / enums / @IsInt) accepts it.
  static Map<String, dynamic> attachmentForMessageSend(Map<String, dynamic> fromComplete) {
    int? asInt(dynamic v) {
      if (v == null) return null;
      if (v is int) return v;
      if (v is num) return v.round();
      return int.tryParse(v.toString());
    }

    final storageKey = fromComplete['storageKey']?.toString() ?? '';
    if (storageKey.isEmpty) {
      throw StateError('Attachment missing storageKey');
    }

    final attType = fromComplete['type']?.toString().toUpperCase() ?? 'AUDIO';
    final encName = fromComplete['encryptedName']?.toString();
    final encMime = fromComplete['encryptedMimeType']?.toString();
    final defaultName = attType == 'IMAGE' ? 'photo.jpg' : 'voice.m4a';
    final defaultMime = attType == 'IMAGE' ? 'image/jpeg' : 'audio/mp4';
    final out = <String, dynamic>{
      'type': attType,
      'storageKey': storageKey,
      'encryptedName': (encName != null && encName.isNotEmpty) ? encName : defaultName,
      'encryptedMimeType': (encMime != null && encMime.isNotEmpty) ? encMime : defaultMime,
    };

    final sz = asInt(fromComplete['encryptedSizeBytes']);
    if (sz != null) {
      out['encryptedSizeBytes'] = sz;
    }

    final hash = fromComplete['ciphertextSha256']?.toString();
    if (hash != null && hash.isNotEmpty) {
      out['ciphertextSha256'] = hash;
    }

    final nonce = fromComplete['nonce']?.toString();
    if (nonce != null && nonce.isNotEmpty) {
      out['nonce'] = nonce;
    }

    final env = fromComplete['encryptionKeyEnvelope']?.toString();
    if (env != null && env.isNotEmpty) {
      out['encryptionKeyEnvelope'] = env;
    }

    return out;
  }

  /// Create intent, PUT bytes, complete; returns attachment map for [MessagingRepository.sendVoiceMessage].
  Future<Map<String, dynamic>> uploadAudioBytes({
    required String conversationId,
    required Uint8List fileBytes,
    String encryptedMimeType = 'audio/mp4',
  }) async {
    final intent = await createAudioUploadIntent(
      conversationId: conversationId,
      fileBytes: fileBytes,
      encryptedMimeType: encryptedMimeType,
    );
    try {
      if (intent.sessionUpload) {
        await postIntentContentMultipart(
          intentId: intent.intentId,
          bytes: fileBytes,
          sha256Hex: intent.sha256Hex,
          filename: 'voice.m4a',
        );
      } else {
        await putBytesToUploadUrl(
          uploadUrl: intent.uploadUrl,
          bytes: fileBytes,
          sha256Hex: intent.sha256Hex,
          contentType: 'audio/mp4',
        );
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final hint = code != null ? ' (HTTP $code)' : '';
      throw StateError('Could not upload audio to storage$hint. ${e.message ?? ''}'.trim());
    }
    final raw = await completeUpload(intent.intentId);
    return attachmentForMessageSend(raw);
  }

  /// Create intent, upload bytes, complete; returns attachment map for [MessagingRepository.sendFileMessage].
  Future<Map<String, dynamic>> uploadImageBytes({
    required String conversationId,
    required Uint8List fileBytes,
    required String encryptedMimeType,
    required String encryptedName,
  }) async {
    final intent = await createImageUploadIntent(
      conversationId: conversationId,
      fileBytes: fileBytes,
      encryptedMimeType: encryptedMimeType,
      encryptedName: encryptedName,
    );
    try {
      if (intent.sessionUpload) {
        await postIntentContentMultipart(
          intentId: intent.intentId,
          bytes: fileBytes,
          sha256Hex: intent.sha256Hex,
          filename: encryptedName,
        );
      } else {
        await putBytesToUploadUrl(
          uploadUrl: intent.uploadUrl,
          bytes: fileBytes,
          sha256Hex: intent.sha256Hex,
          contentType: encryptedMimeType,
        );
      }
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      final hint = code != null ? ' (HTTP $code)' : '';
      throw StateError('Could not upload image to storage$hint. ${e.message ?? ''}'.trim());
    }
    final raw = await completeUpload(intent.intentId);
    return attachmentForMessageSend(raw);
  }
}
