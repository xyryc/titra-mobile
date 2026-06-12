import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:titra/core/constants/storage_keys.dart';
import 'package:titra/features/auth/data/models/user_summary.dart';
import 'package:uuid/uuid.dart';

enum AuthPage { create, login }

/// Global session: token, cached user, onboarding / profile / auth UI flags.
class SessionController extends ChangeNotifier {
  SessionController({
    required SharedPreferences prefs,
    FlutterSecureStorage? secureStorage,
  })  : _prefs = prefs,
        _secure = secureStorage ?? const FlutterSecureStorage();

  final SharedPreferences _prefs;
  final FlutterSecureStorage _secure;

  bool _hydrated = false;
  bool get hydrated => _hydrated;

  String? _sessionToken;
  String? get sessionToken => _sessionToken;

  UserSummary? _user;
  UserSummary? get user => _user;

  bool _needsProfileSetup = false;
  bool get needsProfileSetup => _needsProfileSetup;

  bool _onboardingCompleted = false;
  bool get onboardingCompleted => _onboardingCompleted;

  AuthPage _authPage = AuthPage.create;
  AuthPage get authPage => _authPage;

  String? _deviceId;

  /// Stable logical device id (matches server `Device.deviceId`). Never generates a new UUID on each read.
  String get deviceId {
    _deviceId ??= const Uuid().v4();
    return _deviceId!;
  }

  Future<void> hydrate() async {
    _sessionToken = await _secure.read(key: StorageKeys.sessionToken);
    final userJson = _prefs.getString(StorageKeys.userSummaryJson);
    if (userJson != null) {
      try {
        _user = UserSummary.fromJson(jsonDecode(userJson) as Map<String, dynamic>);
      } catch (_) {
        _user = null;
      }
    }
    _needsProfileSetup = _prefs.getBool(StorageKeys.needsProfileSetup) ?? false;
    _onboardingCompleted = _prefs.getBool(StorageKeys.onboardingCompleted) ?? false;
    final fromPrefs = _prefs.getString(StorageKeys.deviceId);
    if (fromPrefs != null && fromPrefs.isNotEmpty) {
      _deviceId = fromPrefs;
    } else {
      _deviceId ??= const Uuid().v4();
      await _prefs.setString(StorageKeys.deviceId, _deviceId!);
    }
    _hydrated = true;
    notifyListeners();
  }

  Future<void> persistAuthenticated({
    required String token,
    required UserSummary user,
    required bool needsProfileSetup,
  }) async {
    _sessionToken = token;
    _user = user;
    _needsProfileSetup = needsProfileSetup;
    await _secure.write(key: StorageKeys.sessionToken, value: token);
    await _prefs.setString(StorageKeys.userSummaryJson, jsonEncode(user.toJson()));
    await _prefs.setBool(StorageKeys.needsProfileSetup, needsProfileSetup);
    
    // Save token to plain SharedPreferences for native access (e.g. background decline)
    await _prefs.setString('native_session_token', token);
    
    notifyListeners();
  }

  Future<void> completeProfileSetup() async {
    _needsProfileSetup = false;
    await _prefs.setBool(StorageKeys.needsProfileSetup, false);
    notifyListeners();
  }

  /// Updates cached user (e.g. after profile photo upload or GET /auth/me) without changing the session token.
  Future<void> updateCachedUser(UserSummary user) async {
    _user = user;
    await _prefs.setString(StorageKeys.userSummaryJson, jsonEncode(user.toJson()));
    notifyListeners();
  }

  Future<void> completeOnboarding() async {
    _onboardingCompleted = true;
    _authPage = AuthPage.create;
    notifyListeners();
    await _prefs.setBool(StorageKeys.onboardingCompleted, true);
  }

  void showLogin() {
    _authPage = AuthPage.login;
    notifyListeners();
  }

  void showCreateIdentity() {
    _authPage = AuthPage.create;
    notifyListeners();
  }

  Future<void> clearSession() async {
    _sessionToken = null;
    _user = null;
    _needsProfileSetup = false;
    _authPage = AuthPage.login;
    await _secure.delete(key: StorageKeys.sessionToken);
    await _prefs.remove(StorageKeys.userSummaryJson);
    await _prefs.setBool(StorageKeys.needsProfileSetup, false);
    await _prefs.remove('native_session_token');
    notifyListeners();
  }

  Future<void> applyUnauthorized() async {
    await clearSession();
  }
}
