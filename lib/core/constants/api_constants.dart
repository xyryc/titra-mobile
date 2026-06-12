/// Global API configuration. Update baseUrl for your environment.
class ApiConstants {
  ApiConstants._();

  static const String baseUrl = 'https://tietra.xdtunnel.icu/api/v1';
  //static const String baseUrl = 'https://plays-simpson-seeking-ruling.trycloudflare.com/api/v1';
  

  //static const String baseUrl = 'https://methodology-theology-tests-coaches.trycloudflare.com/api/v1';

  static const Duration connectTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout = Duration(seconds: 30);

  /// Fallback when message attachments omit `publicUrl` (should match server `STORAGE_PUBLIC_BASE_URL`).
  static const String storagePublicBaseUrl = String.fromEnvironment(
    'STORAGE_PUBLIC_BASE_URL',
    defaultValue: '',
  );
}
