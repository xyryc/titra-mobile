import 'package:titra/core/constants/api_constants.dart';

/// Socket.IO runs on the HTTP origin, not under `/api/v1`.
///
/// Override with `--dart-define=REALTIME_ORIGIN=https://your-host` if needed.
String realtimeSocketUrl() {
  const override = String.fromEnvironment('REALTIME_ORIGIN', defaultValue: '');
  final origin = override.trim().isNotEmpty
      ? override.trim().replaceAll(RegExp(r'/+$'), '')
      : _originFromApiBase(ApiConstants.baseUrl);
  return '$origin/realtime';
}

String _originFromApiBase(String baseUrl) {
  var u = baseUrl.trim();
  if (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  const suffix = '/api/v1';
  if (u.endsWith(suffix)) {
    return u.substring(0, u.length - suffix.length);
  }
  final uri = Uri.parse(u);
  if (uri.hasScheme && uri.host.isNotEmpty) {
    return uri.hasPort ? '${uri.scheme}://${uri.host}:${uri.port}' : '${uri.scheme}://${uri.host}';
  }
  return u;
}
