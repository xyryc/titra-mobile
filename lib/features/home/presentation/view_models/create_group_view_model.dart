import 'package:flutter/material.dart';
import 'package:titra/core/services/snackbar_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/features/home/data/conversations_repository.dart';

class CreateGroupViewModel extends ChangeNotifier {
  final TextEditingController titleController = TextEditingController();
  final TextEditingController memberIdController = TextEditingController();
  final FocusNode memberFocus = FocusNode();

  final List<String> _memberAccountIds = <String>[];
  List<String> get memberAccountIds => List.unmodifiable(_memberAccountIds);

  bool _submitting = false;
  bool get submitting => _submitting;

  bool _disposed = false;

  String get digitsOnly =>
      memberIdController.text.replaceAll(RegExp(r'[^0-9]'), '');

  String? myDigits(SessionController session) {
    final raw = session.user?.accountId ?? '';
    final digits = raw.replaceAll(RegExp(r'[^0-9]'), '');
    return digits.length == 10 ? digits : null;
  }

  void onMemberIdChanged(String _) {
    _safeNotify();
  }

  void addMember({
    required SnackbarService snackbar,
    required SessionController session,
  }) {
    final digits = digitsOnly;
    if (digits.length != 10) {
      snackbar.showError('Enter a 10-digit Titra ID');
      return;
    }
    final mine = myDigits(session);
    if (mine != null && digits == mine) {
      snackbar.showError('You are added automatically');
      return;
    }
    if (_memberAccountIds.contains(digits)) {
      snackbar.showInfo('Already in the list');
      return;
    }
    _memberAccountIds.add(digits);
    memberIdController.clear();
    _safeNotify();
  }

  void removeMember(String id) {
    _memberAccountIds.remove(id);
    _safeNotify();
  }

  Future<CreatedGroupConversation?> create({
    required ConversationsRepository repo,
    required SnackbarService snackbar,
  }) async {
    final title = titleController.text.trim();
    if (title.isEmpty) {
      snackbar.showError('Enter a group name');
      return null;
    }
    if (_memberAccountIds.isEmpty) {
      snackbar.showError('Add at least one member');
      return null;
    }
    if (_submitting) return null;

    _submitting = true;
    notifyListeners();

    try {
      return await repo.createGroupConversation(
        title: title,
        memberAccountIdsTenDigits: List<String>.from(_memberAccountIds),
      );
    } catch (_) {
      snackbar.showError('Could not create group. Check IDs and try again.');
      return null;
    } finally {
      _submitting = false;
      _safeNotify();
    }
  }

  void _safeNotify() {
    if (!_disposed && hasListeners) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    titleController.dispose();
    memberIdController.dispose();
    memberFocus.dispose();
    super.dispose();
  }
}
