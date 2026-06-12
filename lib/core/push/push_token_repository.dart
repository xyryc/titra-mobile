import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:titra/core/api/api_client.dart';

class PushTokenRepository {
  PushTokenRepository(this._api);

  final ApiClient _api;

  // push_token_repository.dart
  Future<void> registerFcmToken({
    required String fcmToken,
    required String clientDeviceId,
  }) async {
    int attempts = 0;
    const maxAttempts = 3;

    while (attempts < maxAttempts) {
      try {
        await _api.put<void>(
          '/users/me/push-token',
          data: {'fcmToken': fcmToken, 'clientDeviceId': clientDeviceId},
        );
        return; // Success
      } on DioException catch (e) {
        if (e.response?.statusCode == 429) {
          attempts++;
          if (attempts >= maxAttempts) {
            debugPrint('[PushTokenRepo] Rate limit exceeded after $attempts attempts');
            return; // Don't throw - fail silently for non-critical operation
          }
          //  Exponential backoff: 2s, 4s, 8s
          await Future.delayed(Duration(seconds: 2 * attempts));
          continue;
        }
        rethrow; // Other errors should propagate
      }
    }
  }
}
