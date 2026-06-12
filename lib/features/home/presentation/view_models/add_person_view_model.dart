import 'package:flutter/material.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/core/widgets/floatingbar/floatingbar.dart';
import 'package:titra/features/auth/data/user_lookup_coordinator.dart';
import 'package:titra/features/auth/data/user_repository.dart';

class AddPersonViewModel extends ChangeNotifier {
  final TextEditingController idController = TextEditingController();
  final FocusNode idFocusNode = FocusNode();

  String? _searchError;
  String? get searchError => _searchError;

  bool _searching = false;
  bool get searching => _searching;

  bool _disposed = false;

  String get digitsOnly => idController.text.replaceAll(RegExp(r'[^0-9]'), '');
  bool get isValidId => digitsOnly.length == 10;

  void onIdChanged(String _) {
    if (_searchError == null) {
      notifyListeners();
      return;
    }
    _searchError = null;
    notifyListeners();
  }

  Future<void> search(
    BuildContext context, {
    required UserRepository repo,
    required SessionController session,
  }) async {
    if (!isValidId || _searching) return;

    idFocusNode.unfocus();
    _searchError = null;
    _searching = true;
    notifyListeners();

    try {
      await UserLookupCoordinator.openChatForTenDigitId(
        context,
        tenDigits: digitsOnly,
        repo: repo,
        session: session,
        replace: true,
        onError: (message) {
          FloatingErrorBar.show(context, message: message);
          _searchError = message;
          _safeNotify();
        },
      );
    } finally {
      _searching = false;
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
    idController.dispose();
    idFocusNode.dispose();
    super.dispose();
  }
}
