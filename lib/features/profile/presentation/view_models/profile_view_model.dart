import 'package:flutter/foundation.dart';
import 'package:titra/features/auth/data/auth_repository.dart';

const List<String> presetStatuses = [
  'Available',
  'Busy',
  'At the gym 🏋️',
];

class ProfileViewModel extends ChangeNotifier {
  ProfileViewModel({required AuthRepository authRepository})
      : _repo = authRepository;

  final AuthRepository _repo;

  String status = presetStatuses[2];

  bool profileLoading = false;
  bool photoUploading = false;

  void setStatus(String value) {
    status = value;
    notifyListeners();
  }

  Future<void> refreshProfile({bool silent = false}) async {
    if (!silent) {
      profileLoading = true;
      notifyListeners();
    }
    try {
      await _repo.refreshMe();
    } catch (_) {
      if (!silent) rethrow;
    } finally {
      profileLoading = false;
      notifyListeners();
    }
  }

  Future<void> uploadPhoto(String filePath) async {
    if (photoUploading) return;
    photoUploading = true;
    notifyListeners();
    try {
      await _repo.uploadProfilePhotoFromPath(filePath);
    } finally {
      photoUploading = false;
      notifyListeners();
    }
  }
}
