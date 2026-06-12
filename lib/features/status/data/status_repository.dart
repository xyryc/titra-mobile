import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:titra/core/api/api_client.dart';
import 'package:titra/features/status/data/story_model.dart';

/// Loads status feed and story actions from `GET/POST /stories/*`.
class StatusRepository extends ChangeNotifier {
  StatusRepository(this._api);
  DateTime? _lastLoaded;
  final ApiClient _api;

  StatusContact _myStatus = StatusContact(id: '', name: '', stories: []);
  List<StatusContact> _contacts = [];
  bool _loading = false;
  String? _loadError;

  StatusContact get myStatusContact => _myStatus;
  List<StatusContact> get contactsWithActiveStories => _contacts;
  bool get loading => _loading;
  String? get loadError => _loadError;

  dynamic _unwrapData(Response<dynamic> response) {
    final data = response.data;
    if (data is Map && data['data'] != null) {
      return data['data'];
    }
    if (data is Map) {
      return data;
    }
    return null;
  }

  /// Loads feed from API (call when Status tab opens or after posting).
  Future<void> loadFeed({bool force = false}) async {
    if (!force &&
        _lastLoaded != null &&
        DateTime.now().difference(_lastLoaded!) < const Duration(minutes: 2)) {
      return;
    }
    _loading = true;
    _loadError = null;
    notifyListeners();
    try {
      final response = await _api.get<dynamic>(
        'stories/feed',
        showFeedback: false,
      );
      final raw = _unwrapData(response);
      if (raw is! Map) {
        throw StateError('Invalid stories feed response');
      }
      final map = Map<String, dynamic>.from(raw);
      final myRaw = map['myStatus'];
      if (myRaw is Map) {
        _myStatus = StatusContact.fromJson(Map<String, dynamic>.from(myRaw));
      } else {
        _myStatus = StatusContact(id: '', name: '', stories: []);
      }
      final listRaw = map['contacts'];
      if (listRaw is List) {
        _contacts = listRaw
            .whereType<Map>()
            .map((e) => StatusContact.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } else {
        _contacts = [];
      }
      _lastLoaded = DateTime.now();
      _loadError = null;
    } catch (e) {
      _loadError = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Legacy hook: same as [loadFeed].
  Future<void> ensureLoaded() => loadFeed();

  /// Uploads media and creates a story; then refreshes feed.
  Future<StoryModel> createStoryFromFile({
    required String filePath,
    required StoryMediaType mediaType,
    String? caption,
  }) async {
    final name = filePath.split(RegExp(r'[/\\]')).last;
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath, filename: name),
      if (caption != null && caption.trim().isNotEmpty)
        'caption': caption.trim(),
    });
    final response = await _api.postMultipart<dynamic>(
      'stories',
      data: formData,
      showFeedback: false,
    );
    final raw = _unwrapData(response);
    if (raw is! Map) {
      throw StateError('Invalid create story response');
    }
    final story = StoryModel.fromJson(Map<String, dynamic>.from(raw));
    await loadFeed(force: true);
    return story;
  }

  Future<void> recordView(String storyId) async {
    await _api.post<dynamic>(
      'stories/$storyId/view',
      data: const <String, dynamic>{},
      showFeedback: false,
    );
  }

  Future<List<StoryViewer>> fetchViewers(String storyId) async {
    final response = await _api.get<dynamic>(
      'stories/$storyId/viewers',
      showFeedback: false,
    );
    final raw = _unwrapData(response);
    if (raw is! List) {
      return [];
    }
    return raw
        .whereType<Map>()
        .map((e) => StoryViewer.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }
}
