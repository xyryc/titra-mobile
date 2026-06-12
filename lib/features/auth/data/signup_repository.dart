import 'dart:math';

/// Generates a 10-digit unique identifier (displayed as XXX XXX XXXX).
String generateUniqueId() {
  final r = Random();
  final digits = List.generate(10, (_) => r.nextInt(10));
  return '${digits.take(3).join()} ${digits.skip(3).take(3).join()} ${digits.skip(6).join()}';
}

/// Returns password strength 0–4 (for 4 bars) and a label.
/// Uses length + character variety (upper, lower, digit, symbol). Same-character
/// passwords like "12345678" stay Weak/Fair; mixed types needed for Good/Strong.
(int level, String label) getPasswordStrength(String password) {
  if (password.isEmpty) return (0, '');

  final hasUpper = RegExp(r'[A-Z]').hasMatch(password);
  final hasLower = RegExp(r'[a-z]').hasMatch(password);
  final hasDigit = RegExp(r'[0-9]').hasMatch(password);
  final hasSymbol = RegExp(r'[^A-Za-z0-9]').hasMatch(password); // non-alphanumeric

  final typeCount = (hasUpper ? 1 : 0) + (hasLower ? 1 : 0) + (hasDigit ? 1 : 0) + (hasSymbol ? 1 : 0);
  final len = password.length;

  int score;
  if (len < 8) {
    score = 0;
  } else if (typeCount == 1) {
    // Only digits or only letters (e.g. "12345678") → weak
    score = 1;
  } else if (typeCount >= 4 && len >= 8) {
    score = 4; // Strong: upper + lower + digit + symbol
  } else if (typeCount >= 3 && len >= 8) {
    score = 3; // Good: e.g. upper + lower + digit
  } else if (typeCount == 2 && len >= 8) {
    score = 2; // Fair: e.g. letters + digits
  } else if (len >= 10 && typeCount >= 2) {
    score = 3;
  } else if (len >= 8) {
    score = 2;
  } else {
    score = 1;
  }

  if (score > 4) score = 4;
  const labels = ['', 'Weak', 'Fair', 'Good', 'Strong'];
  return (score, labels[score]);
}
