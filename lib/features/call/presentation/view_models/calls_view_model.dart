import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:titra/features/call/data/call_history_entry.dart';
import 'package:titra/features/call/data/calls_repository.dart';

class CallsViewModel extends ChangeNotifier {
  CallsViewModel({required CallsRepository callsRepository})
    : _repo = callsRepository {
    _itemsSub = _repo.watchCallHistory().listen((items) {
      _items = items;
      _loading = false;
      notifyListeners();
    });
  }

  final CallsRepository _repo;
  StreamSubscription<List<CallHistoryEntry>>? _itemsSub;

  List<CallHistoryEntry> _items = [];
  List<CallHistoryEntry> get items => _items;

  bool _loading = false;
  bool get loading => _loading;

  String? _error;
  String? get error => _error;

  DateTime? _lastLoaded;

  Future<void> load({bool force = false}) async {
    if (!force &&
        _lastLoaded != null &&
        DateTime.now().difference(_lastLoaded!) < const Duration(minutes: 2)) {
      return;
    }
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _repo.hydrateCallHistory(limit: 80);
      _lastLoaded = DateTime.now();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    unawaited(_itemsSub?.cancel());
    _itemsSub = null;
    super.dispose();
  }
}
