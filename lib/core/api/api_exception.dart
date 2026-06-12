/// Base exception for API errors. Use for global error handling.
class ApiException implements Exception {
  ApiException({
    this.message = 'Something went wrong',
    this.statusCode,
    this.error,
  });

  final String message;
  final int? statusCode;
  final dynamic error;

  @override
  String toString() => 'ApiException: $message (statusCode: $statusCode)';
}
