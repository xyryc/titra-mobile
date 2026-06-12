import 'package:flutter/foundation.dart';

import '../../data/signup_repository.dart';

class CreateIdentityViewModel extends ChangeNotifier {
  CreateIdentityViewModel() {
    _uniqueId = generateUniqueId();
  }

  String _uniqueId = '';
  String get uniqueId => _uniqueId;

  String _displayName = '';
  String get displayName => _displayName;
  set displayName(String v) {
    _displayName = v;
    notifyListeners();
  }

  String _password = '';
  String get password => _password;

  String _confirmPassword = '';
  String get confirmPassword => _confirmPassword;

  bool _passwordVisible = false;
  bool get passwordVisible => _passwordVisible;

  bool _confirmPasswordVisible = false;
  bool get confirmPasswordVisible => _confirmPasswordVisible;

  (int level, String label) get passwordStrength => getPasswordStrength(_password);

  String? _passwordError;
  String? get passwordError => _passwordError;

  /// Live mismatch message when confirm is non-empty and different from password.
  String? get confirmError {
    if (_confirmPassword.isEmpty) return null;
    if (_password != _confirmPassword) return 'Passwords do not match';
    return null;
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Display / register name (min 2 chars on server; shorter values become [Titra User] at register).
  String get profileNameForRegister {
    final t = _displayName.trim();
    if (t.length >= 2) return t;
    return 'Titra User';
  }

  /// Button enabled only when password and confirm are filled, match, and password meets server minimum (8).
  bool get canSubmit =>
      _password.length >= 8 &&
      _confirmPassword.isNotEmpty &&
      _password == _confirmPassword;

  void refreshId() {
    _uniqueId = generateUniqueId();
    notifyListeners();
  }

  void copyId(void Function(String text) copyToClipboard) {
    final raw = _uniqueId.replaceAll(' ', '');
    copyToClipboard(raw);
  }

  void setPassword(String value) {
    _password = value;
    _passwordError = value.isNotEmpty && value.length < 8 ? 'Use at least 8 characters' : null;
    notifyListeners();
  }

  void setConfirmPassword(String value) {
    _confirmPassword = value;
    notifyListeners();
  }

  void togglePasswordVisible() {
    _passwordVisible = !_passwordVisible;
    notifyListeners();
  }

  void toggleConfirmPasswordVisible() {
    _confirmPasswordVisible = !_confirmPasswordVisible;
    notifyListeners();
  }

  bool validate() {
    _passwordError = null;
    if (_password.length < 8) {
      _passwordError = 'Use at least 8 characters';
      notifyListeners();
      return false;
    }
    if (_password != _confirmPassword) {
      notifyListeners();
      return false;
    }
    notifyListeners();
    return true;
  }

  Future<void> submit(Future<void> Function() action) async {
    if (!validate()) return;
    _isLoading = true;
    notifyListeners();
    try {
      await action();
    } catch (_) {
      // ApiClient shows errors
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
