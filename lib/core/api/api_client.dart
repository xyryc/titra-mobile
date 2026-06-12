import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../services/snackbar_service.dart';
import '../session/session_controller.dart';

const String _kSkipErrorSnack = 'skipErrorSnack';

/// Dio resolves paths starting with `/` from the host root, which drops `/api/v1`.
/// We keep [baseUrl] with a trailing slash and send paths without a leading `/`.
String _normalizeBaseUrl(String url) {
  final t = url.trim();
  return t.endsWith('/') ? t : '$t/';
}

String _relativeApiPath(String path) {
  final p = path.trim();
  if (p.startsWith('/')) return p.substring(1);
  return p;
}

/// Single global API client. All API calls in the app must go through this class.
/// Handles success/error via [SnackbarService] when [showGlobalFeedback] is true.
/// Attaches [x-session-token] from [SessionController] when present.
class ApiClient {
  ApiClient({
    required SnackbarService snackbarService,
    required SessionController sessionController,
    String? baseUrl,
    Map<String, String>? headers,
    bool showGlobalFeedback = true,
  }) : _snackbarService = snackbarService,
       _sessionController = sessionController,
       _showGlobalFeedback = showGlobalFeedback {
    _dio = Dio(
      BaseOptions(
        baseUrl: _normalizeBaseUrl(baseUrl ?? ApiConstants.baseUrl),
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        sendTimeout: ApiConstants.sendTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
          ...?headers,
        },
      ),
    );
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _sessionController.sessionToken;
          if (token != null && token.isNotEmpty) {
            options.headers['x-session-token'] = token;
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          if (error.response?.statusCode == 401) {
            await _sessionController.applyUnauthorized();
          }
          final skip = error.requestOptions.extra[_kSkipErrorSnack] == true;
          if (_showGlobalFeedback && !skip) {
            _snackbarService.showError(parseErrorMessage(error));
          }
          handler.next(error);
        },
      ),
    );
  }

  late final Dio _dio;
  final SnackbarService _snackbarService;
  final SessionController _sessionController;
  final bool _showGlobalFeedback;

  Dio get dio => _dio;

  void showSuccessMessage(String message) {
    _snackbarService.showSuccess(message);
  }

  void showFloatingSuccessMessage(String message) {
    _snackbarService.showFloatingSuccess(message);
  }

  static String parseErrorMessage(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timeout. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection.';
      case DioExceptionType.badResponse:
        final data = error.response?.data;
        if (data is Map) {
          if (data['message'] != null) return data['message'].toString();
          if (data['msg'] != null) return data['msg'].toString();
          if (data['error'] != null) return data['error'].toString();
        }
        final code = error.response?.statusCode;
        if (code == 401) return 'Unauthorized.';
        if (code == 403) return 'Access denied.';
        if (code == 404) return 'Resource not found.';
        if (code != null && code >= 500) {
          return 'Server error. Please try later.';
        }
        return 'Request failed. Please try again.';
      case DioExceptionType.cancel:
        return 'Request cancelled.';
      default:
        return error.message ?? 'Something went wrong.';
    }
  }

  Options _optionsWithFeedback(Options? options, bool showFeedback) {
    final extra = Map<String, Object?>.from(options?.extra ?? {});
    extra[_kSkipErrorSnack] = !showFeedback;
    return (options ?? Options()).copyWith(extra: extra);
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool showFeedback = true,
  }) {
    return _dio.get<T>(
      _relativeApiPath(path),
      queryParameters: queryParameters,
      options: _optionsWithFeedback(options, showFeedback),
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool showFeedback = true,
  }) {
    return _dio.post<T>(
      _relativeApiPath(path),
      data: data,
      queryParameters: queryParameters,
      options: _optionsWithFeedback(options, showFeedback),
      cancelToken: cancelToken,
    );
  }

  /// Multipart upload (e.g. profile photo).
  ///
  /// Base [Dio] uses `Content-Type: application/json`; setting [Options.contentType]
  /// to multipart replaces that in [Options.compose] so Dio does not throw a
  /// contentType/header mismatch. [FormData] is then sent with the correct boundary
  /// in [DioMixin._transformData].
  Future<Response<T>> postMultipart<T>(
    String path, {
    required FormData data,
    Map<String, dynamic>? headers,
    CancelToken? cancelToken,
    bool showFeedback = true,
  }) {
    final feedback = _optionsWithFeedback(null, showFeedback);
    return _dio.post<T>(
      _relativeApiPath(path),
      data: data,
      options: Options(
        extra: feedback.extra,
        contentType: Headers.multipartFormDataContentType,
        headers: headers,
      ),
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool showFeedback = true,
  }) {
    return _dio.put<T>(
      _relativeApiPath(path),
      data: data,
      queryParameters: queryParameters,
      options: _optionsWithFeedback(options, showFeedback),
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool showFeedback = true,
  }) {
    return _dio.patch<T>(
      _relativeApiPath(path),
      data: data,
      queryParameters: queryParameters,
      options: _optionsWithFeedback(options, showFeedback),
      cancelToken: cancelToken,
    );
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    bool showFeedback = true,
  }) {
    return _dio.delete<T>(
      _relativeApiPath(path),
      data: data,
      queryParameters: queryParameters,
      options: _optionsWithFeedback(options, showFeedback),
      cancelToken: cancelToken,
    );
  }

  Dio get raw => _dio;
}
