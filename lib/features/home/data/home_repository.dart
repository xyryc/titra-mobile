import 'package:titra/core/api/api_client.dart';

/// Repository for home feature. All API calls go through [ApiClient].
class HomeRepository {
  HomeRepository(this._api);

  final ApiClient _api;

  /// Example: fetch something. Use _api.get/post/put/delete for all calls.
  Future<Map<String, dynamic>?> fetchExample() async {
    final response = await _api.get<Map<String, dynamic>>('/example');
    return response.data;
  }
}
