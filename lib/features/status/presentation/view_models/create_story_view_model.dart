import 'package:flutter/foundation.dart';
import 'package:titra/features/status/data/status_repository.dart';
import 'package:titra/features/status/data/story_model.dart';

class CreateStoryViewModel extends ChangeNotifier {
  CreateStoryViewModel({required StatusRepository statusRepository})
      : _repo = statusRepository;

  final StatusRepository _repo;

  String? pickedPath;
  StoryMediaType? mediaType;
  bool posting = false;

  bool get hasMedia => pickedPath != null && mediaType != null;

  void setMedia(String path, StoryMediaType type) {
    pickedPath = path;
    mediaType = type;
    notifyListeners();
  }

  void clearMedia() {
    pickedPath = null;
    mediaType = null;
    notifyListeners();
  }

  /// Posts and navigates away. Returns true on success.
  Future<bool> post(String? caption) async {
    if (!hasMedia || posting) return false;
    posting = true;
    notifyListeners();
    try {
      await _repo.createStoryFromFile(
        filePath: pickedPath!,
        mediaType: mediaType!,
        caption: caption,
      );
      return true;
    } catch (_) {
      rethrow;
    } finally {
      posting = false;
      notifyListeners();
    }
  }

  /// Posts then resets media so user can add another.
  Future<void> postAndReset(String? caption) async {
    if (!hasMedia || posting) return;
    posting = true;
    notifyListeners();
    try {
      await _repo.createStoryFromFile(
        filePath: pickedPath!,
        mediaType: mediaType!,
        caption: caption,
      );
      pickedPath = null;
      mediaType = null;
    } finally {
      posting = false;
      notifyListeners();
    }
  }
}
