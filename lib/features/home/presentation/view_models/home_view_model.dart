import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/features/home/data/chat_model.dart';
import 'package:titra/features/home/data/conversations_repository.dart';

/// ViewModel for home screen: chats list from API, search, loading state.
class HomeViewModel extends ChangeNotifier {
  HomeViewModel({
    required ConversationsRepository conversationsRepository,
    required SessionController sessionController,
    required RealtimeService realtimeService,
  }) : _conversationsRepository = conversationsRepository,
       _session = sessionController,
       _realtime = realtimeService {
    _messageCreatedSub = _realtime.onMessageCreated.listen((_) {
      _scheduleSilentConversationsRefresh();
    });
  }

  final ConversationsRepository _conversationsRepository;
  final SessionController _session;
  final RealtimeService _realtime;

  StreamSubscription<List<ChatModel>>? _conversationsSub;
  StreamSubscription<Map<String, dynamic>>? _messageCreatedSub;
  Timer? _refreshDebounce;
  String? _boundUserId;

  List<ChatModel> _allChats = [];
  List<ChatModel> _filteredChats = [];
  List<ChatModel> get filteredChats => _filteredChats;
  int get totalUnreadCount =>
      _allChats.fold(0, (sum, chat) => sum + chat.unreadCount);

  String _searchQuery = '';
  String get searchQuery => _searchQuery;

  int _selectedNavIndex = 0;
  int get selectedNavIndex => _selectedNavIndex;

  bool _loading = false;
  bool get loading => _loading;

  String? _loadError;
  String? get loadError => _loadError;

  void setSearchQuery(String value) {
    _searchQuery = value.trim().toLowerCase();
    _applyFilter();
    notifyListeners();
  }

  static String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  void _applyFilter() {
    if (_searchQuery.isEmpty) {
      _filteredChats = List.from(_allChats);
      return;
    }
    final qDigits = _digitsOnly(_searchQuery);
    _filteredChats = _allChats.where((c) {
      final nameMatch = c.name.toLowerCase().contains(_searchQuery);
      final msgMatch = c.lastMessage.toLowerCase().contains(_searchQuery);
      final convIdMatch = c.id.toLowerCase().contains(_searchQuery);
      final contact = c.contactDisplayId ?? '';
      final contactDigits = _digitsOnly(contact);
      final titraIdMatch =
          qDigits.isNotEmpty &&
          contactDigits.isNotEmpty &&
          (contactDigits == qDigits ||
              contactDigits.contains(qDigits) ||
              qDigits.contains(contactDigits));
      final memberMatch =
          c.memberNames?.any((n) => n.toLowerCase().contains(_searchQuery)) ??
          false;
      return nameMatch ||
          msgMatch ||
          convIdMatch ||
          titraIdMatch ||
          memberMatch;
    }).toList();
  }

  void setSelectedNavIndex(int index) {
    _selectedNavIndex = index;
    notifyListeners();
  }

  /// Refreshes the chat list. Use [silent] for realtime-driven updates to avoid a full-screen spinner.
  Future<void> loadConversations({bool silent = false}) async {
    final uid = _session.user?.id;
    if (uid == null) return;

    if (_boundUserId != uid || _conversationsSub == null) {
      await _conversationsSub?.cancel();
      _boundUserId = uid;
      _conversationsSub = _conversationsRepository
          .watchChatsForUser(uid)
          .listen((chats) {
            _allChats = chats;
            _applyFilter();
            _loadError = null;
            if (_loading) {
              _loading = false;
            }
            notifyListeners();
          });
    }

    if (!silent) {
      _loading = true;
      _loadError = null;
      notifyListeners();
    }

    try {
      await _conversationsRepository.refreshConversations(uid);
      _loadError = null;
    } catch (_) {
      if (!silent) {
        _loadError = 'Could not load conversations';
      }
    } finally {
      if (!silent) {
        _loading = false;
      }
      notifyListeners();
    }
  }

  void _scheduleSilentConversationsRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 400), () {
      _refreshDebounce = null;
      unawaited(loadConversations(silent: true));
    });
  }

  @override
  void dispose() {
    _refreshDebounce?.cancel();
    unawaited(_conversationsSub?.cancel());
    _conversationsSub = null;
    unawaited(_messageCreatedSub?.cancel());
    _messageCreatedSub = null;
    super.dispose();
  }
}
