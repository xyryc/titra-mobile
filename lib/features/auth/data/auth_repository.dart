import 'package:dio/dio.dart';
import 'package:titra/core/api/api_client.dart';
import 'package:titra/core/crypto/placeholder_keys.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/features/auth/data/models/user_summary.dart';

class AuthRepository {
  AuthRepository(this._api, this._session);

  final ApiClient _api;
  final SessionController _session;

  Map<String, dynamic> _unwrap(Response<dynamic> response) {
    final data = response.data;
    if (data is Map && data['data'] != null) {
      return Map<String, dynamic>.from(data['data'] as Map);
    }
    if (data is Map) {
      return Map<String, dynamic>.from(data);
    }
    return {};
  }

  Future<void> register({
    required String accountId,
    required String profileName,
    required String password,
  }) async {
    final pk = PlaceholderKeys.identityPublicKey;
    final body = {
      'accountId': accountId,
      'profileName': profileName,
      'password': password,
      'identityPublicKey': pk,
      'signedPreKey': PlaceholderKeys.signedPreKey,
      'signedPreKeySignature': PlaceholderKeys.signedPreKeySignature,
      'deviceId': _session.deviceId,
      'deviceLabel': 'Titra Mobile',
      'deviceIdentityPublicKey': PlaceholderKeys.deviceIdentityPublicKey,
      'deviceSignedPreKey': PlaceholderKeys.deviceSignedPreKey,
      'deviceSignedPreKeySig': PlaceholderKeys.deviceSignedPreKeySig,
      'oneTimePreKeys': PlaceholderKeys.oneTimePreKeys(),
    };

    final response = await _api.post<dynamic>('/auth/register', data: body);
    final data = _unwrap(response);
    final userMap = data['user'] as Map<String, dynamic>?;
    final sessionMap = data['session'] as Map<String, dynamic>?;
    if (userMap == null || sessionMap == null) {
      throw StateError('Invalid register response');
    }
    final token = sessionMap['sessionToken'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Missing session token');
    }
    final user = UserSummary.fromJson(userMap);
    await _session.persistAuthenticated(
      token: token,
      user: user,
      needsProfileSetup: true,
    );
    _api.showSuccessMessage('Welcome to Titra');
  }

  Future<void> login({
    required String accountId,
    required String password,
  }) async {
    final body = {
      'accountId': accountId,
      'password': password,
      'deviceId': _session.deviceId,
    };
    final response = await _api.post<dynamic>('/auth/login', data: body);
    final data = _unwrap(response);
    final userMap = data['user'] as Map<String, dynamic>?;
    final sessionMap = data['session'] as Map<String, dynamic>?;
    if (userMap == null || sessionMap == null) {
      throw StateError('Invalid login response');
    }
    final token = sessionMap['sessionToken'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Missing session token');
    }
    final user = UserSummary.fromJson(userMap);
    await _session.persistAuthenticated(
      token: token,
      user: user,
      needsProfileSetup: false,
    );
    _api.showFloatingSuccessMessage('Welcome back');
  }

  Future<void> logout() async {
    try {
      await _api.post<dynamic>('/auth/logout', showFeedback: false);
    } catch (_) {
      // Still clear local session if network fails
    }
    await _session.clearSession();
  }

  Future<UserSummary> refreshMe() async {
    final response = await _api.get<dynamic>('auth/me', showFeedback: false);
    final data = _unwrap(response);
    final user = UserSummary.fromJson(data);
    await _session.updateCachedUser(user);
    return user;
  }

  Future<UserSummary> uploadProfilePhotoFromPath(String filePath) async {
    final segments = filePath.split(RegExp(r'[\\/]'));
    final fileName = segments.isNotEmpty ? segments.last : 'photo.jpg';
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: fileName),
    });
    final response = await _api.postMultipart<dynamic>(
      'users/me/profile-photo',
      data: formData,
      showFeedback: false,
    );
    final data = _unwrap(response);
    final user = UserSummary.fromJson(data);
    await _session.updateCachedUser(user);
    return user;
  }
}
