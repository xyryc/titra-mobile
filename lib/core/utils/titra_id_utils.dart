// Titra ID display formatting. All Titra numbers are shown with a +0 prefix.

/// Formats a 10-digit Titra ID as XXX-XXX-XXXX.
String formatTitraIdDashed(String digits) {
  if (digits.isEmpty) return '';
  final d = digits.replaceAll(RegExp(r'[^0-9]'), '');
  if (d.length > 6) {
    return '${d.substring(0, 3)}-${d.substring(3, 6)}-${d.substring(6)}';
  }
  if (d.length > 3) {
    return '${d.substring(0, 3)}-${d.substring(3)}';
  }
  return d;
}

/// Returns Titra ID for display with +0 prefix (e.g. "+0 884-902-1102").
/// [id] can be "884-902-1102", "8849021102", or any string. If it contains
/// exactly 10 digits, returns "+0 " + dashed format; otherwise returns [id] unchanged.
String formatTitraIdWithPrefix(String? id) {
  if (id == null || id.isEmpty) return id ?? '';
  final digits = id.replaceAll(RegExp(r'[^0-9]'), '');
  if (digits.length != 10) return id;
  return '+0 ${formatTitraIdDashed(digits)}';
}
