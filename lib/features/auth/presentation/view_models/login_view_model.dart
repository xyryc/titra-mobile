import 'package:flutter/foundation.dart';

class LoginViewModel extends ChangeNotifier {
  String _userId = '';
  String get userId => _userId;

  String _password = '';
  String get password => _password;

  bool _passwordVisible = false;
  bool get passwordVisible => _passwordVisible;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  String? _userIdError;
  String? get userIdError => _userIdError;

  String? _passwordError;
  String? get passwordError => _passwordError;

  void setUserId(String value) {
    _userId = value.replaceAll(RegExp(r'[^0-9]'), '');
    _userIdError = null;
    notifyListeners();
  }

  /// Formatted for display (XXX XXX XXXX).
  String get userIdDisplay {
    final d = _userId.replaceAll(' ', '');
    if (d.length <= 3) return d;
    if (d.length <= 6) return '${d.substring(0, 3)} ${d.substring(3)}';
    return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
  }

  void setPassword(String value) {
    _password = value;
    _passwordError = null;
    notifyListeners();
  }

  void togglePasswordVisible() {
    _passwordVisible = !_passwordVisible;
    notifyListeners();
  }

  bool validate() {
    _userIdError = null;
    _passwordError = null;
    if (_userId.length != 10) {
      _userIdError = 'Enter a valid 10-digit ID';
      notifyListeners();
      return false;
    }
    if (_password.isEmpty) {
      _passwordError = 'Enter your password';
      notifyListeners();
      return false;
    }
    if (_password.length < 8) {
      _passwordError = 'Password must be at least 8 characters';
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
      // Errors surfaced via ApiClient / snackbar
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
