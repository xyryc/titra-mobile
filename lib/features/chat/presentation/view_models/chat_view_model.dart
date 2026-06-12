// import 'dart:async';
// import 'dart:io';
//
// import 'package:flutter/material.dart';
// import 'package:titra/core/realtime/realtime_service.dart';
// import 'package:titra/core/services/snackbar_service.dart';
// import 'package:titra/core/session/session_controller.dart';
// import 'package:titra/features/chat/data/message_model.dart';
// import 'package:titra/features/chat/data/messaging_repository.dart';
// import 'package:titra/features/home/data/conversations_repository.dart';
//
// class ChatViewModel extends ChangeNotifier {
//   ChatViewModel({
//     required SessionController sessionController,
//     required ConversationsRepository conversationsRepository,
//     required MessagingRepository messagingRepository,
//     required SnackbarService snackbarService,
//     required RealtimeService realtimeService,
//     required this.contactName,
//     required this.contactId,
//     this.conversationId,
//     this.avatarUrl,
//     this.isGroup = false,
//     this.participantNames,
//     this.messagingEnabled = true,
//     this.peerUserId,
//     this.groupMemberUserIds,
//   }) : _session = sessionController,
//        _conversations = conversationsRepository,
//        _messaging = messagingRepository,
//        _snackbar = snackbarService,
//        _realtime = realtimeService;
//
//   final SessionController _session;
//   final ConversationsRepository _conversations;
//   final MessagingRepository _messaging;
//   final SnackbarService _snackbar;
//   final RealtimeService _realtime;
//
//   final String contactName;
//   final String contactId;
//   final String? conversationId;
//   final String? avatarUrl;
//   final bool isGroup;
//   final List<String>? participantNames;
//   final bool messagingEnabled;
//
//   /// Peer UUID for direct chats (presence). Resolved via API if omitted.
//   final String? peerUserId;
//
//   /// Group member user UUIDs (from list API or [fetchGroupConversationDetail]). Fetched in bootstrap if null.
//   final List<String>? groupMemberUserIds;
//
//   final FocusNode messageFocusNode = FocusNode();
//
//   List<String>? _resolvedGroupMemberUserIds;
//
//   String? _resolvedPeerUserId;
//   bool _peerOnline = false;
//   bool disposed = false;
//
//   /// Whether the other person appears online (realtime). Always false for groups.
//   bool get peerOnline => _peerOnline;
//
//   String? _resolvedConversationId;
//   String? _myUserId;
//
//   List<MessageModel> _messages = [];
//   List<MessageModel> get messages => _messages;
//   final ScrollController _messageBundleController = ScrollController();
//
//   bool _loading = false;
//   bool get loading => _loading;
//   String? _loadError;
//   String? get loadError => _loadError;
//   bool _peerTyping = false;
//   bool get peerTyping => _peerTyping;
//   String get peerTypingLabel => isGroup ? 'Someone is typing' : '$contactName is typing';
//   bool _sending = false;
//
//   @override
//   bool get sending => _sending;
//
//   bool get inputEnabled =>
//       messagingEnabled &&
//       !_loading &&
//       _loadError == null &&
//       _resolvedConversationId != null;
//
//   /// Resolved direct peer UUID when available.
//   String? get effectivePeerUserId => _resolvedPeerUserId ?? peerUserId;
//
//   ScrollController get messageScrollController => _messageBundleController;
//
//   String? get effectiveConversationId => _resolvedConversationId;
//
//
//   /// 1:1 WebRTC calls only when we have a conversation and peer id.
//   bool get canPlaceWebrtcCall =>
//       !isGroup &&
//       messagingEnabled &&
//       _loadError == null &&
//       !_loading &&
//       effectiveConversationId != null &&
//       effectivePeerUserId != null &&
//       effectivePeerUserId!.isNotEmpty;
//
//   /// Other members’ user ids for mesh group calls (excludes self). Max ~4 remotes recommended.
//   List<String> get remoteUserIdsForGroupCall {
//     final my = _myUserId;
//     if (my == null || my.isEmpty) return const [];
//     final ids = _resolvedGroupMemberUserIds ?? const <String>[];
//     return ids.where((id) => id != my).toList();
//   }
//
//   bool get canPlaceGroupWebrtcCall =>
//       isGroup &&
//       messagingEnabled &&
//       _loadError == null &&
//       !_loading &&
//       effectiveConversationId != null &&
//       remoteUserIdsForGroupCall.isNotEmpty &&
//       remoteUserIdsForGroupCall.length <= 4;
//
//   /// Ensures [effectivePeerUserId] is loaded for direct chats (for WebRTC).
//   Future<bool> ensurePeerForCall() async {
//     if (isGroup || effectiveConversationId == null) return false;
//     await _resolvePeerUserIdIfNeeded();
//     notifyListeners();
//     final p = effectivePeerUserId;
//     return p != null && p.isNotEmpty;
//   }
//
//   void scrollToBottom({bool animated = true}) {
//     if (!_messageBundleController.hasClients) return;
//     WidgetsBinding.instance.addPostFrameCallback((_) {
//       if (!_messageBundleController.hasClients) return;
//       const position = 0.0;
//
//       if (animated) {
//         _messageBundleController.animateTo(
//           position,
//           duration: const Duration(milliseconds: 250),
//           curve: Curves.easeOut,
//         );
//       } else {
//         _messageBundleController.jumpTo(position);
//       }
//     });
//   }
//
//   /// Loads member ids for group calls when not passed from the chat list.
//   Future<bool> ensureGroupMembersForCall() async {
//     if (!isGroup || effectiveConversationId == null) return false;
//     if (remoteUserIdsForGroupCall.isNotEmpty) return true;
//     try {
//       final detail = await _conversations.fetchGroupConversationDetail(
//         effectiveConversationId!,
//       );
//       _resolvedGroupMemberUserIds = List<String>.from(detail.memberUserIds);
//       notifyListeners();
//     } catch (_) {
//       return false;
//     }
//     return remoteUserIdsForGroupCall.isNotEmpty;
//   }
//
//   bool get _canEmitTyping =>
//       messagingEnabled &&
//       _resolvedConversationId != null &&
//       _loadError == null &&
//       !_loading;
//
//   final TextEditingController _inputController = TextEditingController();
//   TextEditingController get inputController => _inputController;
//
//   StreamSubscription<List<MessageModel>>? _localMessagesSub;
//   StreamSubscription<Map<String, dynamic>>? _typingSub;
//   StreamSubscription<Map<String, dynamic>>? _presenceSub;
//   Timer? _typingDebounceTimer;
//   Timer? _typingIdleTimer;
//   Timer? _readAckTimer;
//   final Set<String> _pendingReadAckIds = <String>{};
//
//   VoidCallback? _realtimeRoomListener;
//   String? _roomJoinedId;
//   bool _composerTypingActive = false;
//
//   //Replace both safeNotify() and _safeNotify() with this:
//   void _safeNotify() {
//     if (!disposed && hasListeners) {
//       notifyListeners();
//     }
//   }
//
//   // Future<void> bootstrap() async {
//   //   _detachRealtime();
//   //   if (!messagingEnabled) {
//   //     _loading = false;
//   //     if (!disposed) _safeNotify();
//   //     return;
//   //   }
//   //
//   //   _loading = true;
//   //   _loadError = null;
//   //   if (!disposed) _safeNotify();
//   //
//   //   //  SAFETY TIMEOUT: Prevent infinite loading if conversation resolution hangs
//   //   final timeout = Timer(const Duration(seconds: 8), () {
//   //     if (_loading && !disposed) {
//   //       debugPrint('[ChatVM] ⚠️ bootstrap() timeout, forcing loading=false');
//   //       _loading = false;
//   //       _loadError = 'Conversation setup timed out. Check network or API.';
//   //       _safeNotify();
//   //     }
//   //   });
//   //
//   //   try {
//   //     final myId = _session.user?.id;
//   //     if (myId == null || myId.isEmpty) {
//   //       _loadError = 'Not signed in';
//   //       if (!disposed) _safeNotify();
//   //       return;
//   //     }
//   //     _myUserId = myId;
//   //
//   //     if (conversationId != null && conversationId!.isNotEmpty) {
//   //       _resolvedConversationId = conversationId;
//   //       debugPrint('[ChatVM]  Resolved conversationId from params: $_resolvedConversationId');
//   //     } else if (!isGroup) {
//   //       final digits = _digitsOnly(contactId);
//   //       if (digits.length != 10) {
//   //         _loadError = 'Invalid Titra ID';
//   //         if (!disposed) _safeNotify();
//   //         return;
//   //       }
//   //       debugPrint('[ChatVM] 🔄 Creating direct conversation for: $digits');
//   //       _resolvedConversationId = await _conversations.createDirectConversation(digits, currentUserId: myId);
//   //       debugPrint('[ChatVM]  Direct conversation created: $_resolvedConversationId');
//   //     } else {
//   //       _loadError = 'Missing conversation';
//   //       if (!disposed) _safeNotify();
//   //       return;
//   //     }
//   //
//   //     if (isGroup) {
//   //       if (groupMemberUserIds != null && groupMemberUserIds!.isNotEmpty) {
//   //         _resolvedGroupMemberUserIds = List<String>.from(groupMemberUserIds!);
//   //       } else {
//   //         try {
//   //           final detail = await _conversations.fetchGroupConversationDetail(_resolvedConversationId!);
//   //           _resolvedGroupMemberUserIds = List<String>.from(detail.memberUserIds);
//   //         } catch (_) {
//   //           _resolvedGroupMemberUserIds = [];
//   //         }
//   //       }
//   //     }
//   //
//   //     if (!disposed) {
//   //       _subscribeToLocalMessages();
//   //       await _conversations.refreshConversationDetail(_resolvedConversationId!, currentUserId: myId);
//   //       await _messaging.hydrateConversation(_resolvedConversationId!, currentUserId: myId, isGroup: isGroup);
//   //       _attachRealtime();
//   //       final existingPeerIds = _peerMessageIdsForAck();
//   //       _scheduleDeliveredPeerMessages(existingPeerIds);
//   //       _scheduleReadPeerMessages(existingPeerIds);
//   //     }
//   //   } catch (e, st) {
//   //     debugPrint('[ChatVM] ❌ bootstrap failed: $e\n$st');
//   //     _loadError = 'Could not load messages: ${e.toString().split('\n').first}';
//   //     _messages = [];
//   //   } finally {
//   //     timeout.cancel(); //  Cancel safety timer
//   //     _loading = false;
//   //     debugPrint('[ChatVM] 📊 State -> loading: $_loading, error: $_loadError, convId: $_resolvedConversationId');
//   //     if (!disposed) _safeNotify();
//   //   }
//   // }
//
//   Future<void> bootstrap() async {
//     _detachRealtime();
//     if (!messagingEnabled) {
//       _loading = false;
//       if (!disposed) _safeNotify();
//       return;
//     }
//
//     _loadError = null;
//
//     try {
//       final myId = _session.user?.id;
//       if (myId == null || myId.isEmpty) {
//         _loadError = 'Not signed in';
//         if (!disposed) _safeNotify();
//         return;
//       }
//       _myUserId = myId;
//
//       // Set conversation ID immediately (sync)
//       if (conversationId != null && conversationId!.isNotEmpty) {
//         _resolvedConversationId = conversationId;
//       } else if (!isGroup) {
//         final digits = _digitsOnly(contactId);
//         if (digits.length != 10) {
//           _loadError = 'Invalid Titra ID';
//           if (!disposed) _safeNotify();
//           return;
//         }
//         // Don't await here. Resolve ID, then hydrate in background.
//         _resolvedConversationId = await _conversations.createDirectConversation(digits, currentUserId: myId);
//       } else {
//         _loadError = 'Missing conversation';
//         if (!disposed) _safeNotify();
//         return;
//       }
//
//       // Enable input immediately by setting loading = false
//       _loading = false;
//       if (!disposed) _safeNotify();
//
//       // Run heavy sync in background (doesn't block UI)
//       unawaited(_hydrateInBackground());
//
//       // Attach realtime & local streams
//       if (!disposed) {
//         _subscribeToLocalMessages();
//         _attachRealtime();
//         final existingPeerIds = _peerMessageIdsForAck();
//         _scheduleDeliveredPeerMessages(existingPeerIds);
//         _scheduleReadPeerMessages(existingPeerIds);
//       }
//
//     } catch (e, st) {
//       _loading = false;
//       _loadError = 'Could not load messages';
//       _messages = [];
//       if (!disposed) _safeNotify();
//       debugPrint('[ChatVM] bootstrap failed: $e\n$st');
//     }
//   }
//
//   // NEW: Background hydration (API → SQLite)
//   Future<void> _hydrateInBackground() async {
//     try {
//       if (_resolvedConversationId == null || _myUserId == null) return;
//
//       // Fetch from API and save to SQLite (takes time, but UI is already enabled)
//       await _conversations.refreshConversationDetail(
//         _resolvedConversationId!,
//         currentUserId: _myUserId!,
//       );
//       await _messaging.hydrateConversation(
//         _resolvedConversationId!,
//         currentUserId: _myUserId!,
//         isGroup: isGroup,
//       );
//     } catch (e, st) {
//       debugPrint('[ChatVM] Background hydration failed: $e\n$st');
//       // Don't show error UI; SQLite stream will still show cached messages
//     }
//   }
//
//   void _attachRealtime() {
//     _detachRealtimeListenersOnly();
//     if (!messagingEnabled ||
//         _resolvedConversationId == null ||
//         _myUserId == null) {
//       return;
//     }
//
//     _realtimeRoomListener = () {
//       final id = _resolvedConversationId;
//       if (id == null || !_realtime.isConnected) return;
//       if (_roomJoinedId == id) return;
//       if (_roomJoinedId != null) {
//         _realtime.leaveConversation(_roomJoinedId!);
//       }
//       _realtime.joinConversation(id);
//       _roomJoinedId = id;
//       if (!isGroup) {
//         unawaited(_syncPeerOnlineFromApi());
//       }
//     };
//     _realtime.addListener(_realtimeRoomListener!);
//     _realtimeRoomListener!();
//
//     _typingSub = _realtime.onTypingUpdated.listen(_onTypingUpdated);
//
//     if (!isGroup) {
//       _presenceSub = _realtime.onPresenceUpdated.listen(_onPresencePayload);
//       unawaited(_syncPeerOnlineFromApi());
//     }
//   }
//
//   void _detachRealtimeListenersOnly() {
//     if (_realtimeRoomListener != null) {
//       _realtime.removeListener(_realtimeRoomListener!);
//       _realtimeRoomListener = null;
//     }
//     _typingSub?.cancel();
//     _typingSub = null;
//     _presenceSub?.cancel();
//     _presenceSub = null;
//   }
//
//   void _leaveConversationRoom() {
//     final id = _roomJoinedId;
//     if (id != null) {
//       _realtime.leaveConversation(id);
//       _roomJoinedId = null;
//     }
//   }
//
//   void _detachRealtime() {
//     _leaveConversationRoom();
//     _detachRealtimeListenersOnly();
//     _readAckTimer?.cancel();
//     _readAckTimer = null;
//     _pendingReadAckIds.clear();
//     _stopTypingEmit();
//     _typingDebounceTimer?.cancel();
//     _typingIdleTimer?.cancel();
//     _peerTyping = false;
//     _peerOnline = false;
//   }
//
//   void _subscribeToLocalMessages() {
//     final convId = _resolvedConversationId;
//     final myId = _myUserId;
//     if (convId == null || myId == null) return;
//
//     _localMessagesSub?.cancel();
//     _localMessagesSub = _messaging
//         .watchMessages(convId, currentUserId: myId, isGroup: isGroup)
//         .listen((nextMessages) {
//       if (disposed) return; //  Guard
//
//       final previousLength = _messages.length;
//       _messages = nextMessages;
//       if (_messages.isNotEmpty && previousLength < _messages.length) {
//         scrollToBottom();
//       }
//       final peerIds = _peerMessageIdsForAck();
//       _scheduleDeliveredPeerMessages(peerIds);
//       _scheduleReadPeerMessages(peerIds);
//       if (!disposed) _safeNotify(); //  Guard
//     });
//   }
//
//
//   Future<void> _resolvePeerUserIdIfNeeded() async {
//     if (peerUserId != null && peerUserId!.isNotEmpty) {
//       _resolvedPeerUserId = peerUserId;
//       return;
//     }
//     final conv = _resolvedConversationId;
//     final my = _myUserId;
//     if (conv == null || my == null || isGroup) return;
//     _resolvedPeerUserId ??= await _conversations.fetchDirectPeerUserId(
//       conv,
//       my,
//     );
//   }
//
//   Future<void> _syncPeerOnlineFromApi() async {
//     if (isGroup || !messagingEnabled) return;
//     await _resolvePeerUserIdIfNeeded();
//     final peer = _resolvedPeerUserId ?? peerUserId;
//     if (peer == null || peer.isEmpty) return;
//     try {
//       final on = await _conversations.fetchUserOnline(peer);
//       if (_peerOnline != on) {
//         _peerOnline = on;
//         notifyListeners();
//       }
//     } catch (_) {}
//   }
//
//   void _onPresencePayload(Map<String, dynamic> p) {
//     if (disposed) return; //  Guard
//     if (isGroup) return;
//     final peer = _resolvedPeerUserId ?? peerUserId;
//     if (peer == null) return;
//     final uid = p['userId']?.toString();
//     if (uid != peer) return;
//     final online = p['online'] == true || p['online'] == 1;
//     if (_peerOnline == online) return;
//     _peerOnline = online;
//     if (!disposed) _safeNotify(); //  Guard
//   }
//
//   List<String> _peerMessageIdsForAck() {
//     return [
//       for (final m in _messages)
//         if (!m.isFromMe &&
//             m.id.isNotEmpty &&
//             !m.id.startsWith('local_') &&
//             m.status != MessageStatus.read)
//           m.id,
//     ];
//   }
//
//   void _scheduleDeliveredPeerMessages(List<String> messageIds) {
//     if (messageIds.isEmpty || !messagingEnabled) return;
//     final conv = _resolvedConversationId;
//     if (conv == null) return;
//     unawaited(_ackDeliveredAsync(conv, messageIds));
//   }
//
//   void _scheduleReadPeerMessages(List<String> messageIds) {
//     if (messageIds.isEmpty || !messagingEnabled) return;
//     final conv = _resolvedConversationId;
//     if (conv == null) return;
//     _pendingReadAckIds.addAll(messageIds);
//     _readAckTimer?.cancel();
//     _readAckTimer = Timer(const Duration(milliseconds: 900), () {
//       final ids = List<String>.from(_pendingReadAckIds);
//       _pendingReadAckIds.clear();
//       if (ids.isEmpty) return;
//       unawaited(_ackReadAsync(conv, ids));
//     });
//   }
//
//   Future<void> _ackDeliveredAsync(
//     String conversationId,
//     List<String> messageIds,
//   ) async {
//     try {
//       await _messaging.markMessagesDelivered(
//         conversationId: conversationId,
//         messageIds: messageIds,
//       );
//     } catch (_) {}
//   }
//
//   Future<void> _ackReadAsync(
//     String conversationId,
//     List<String> messageIds,
//   ) async {
//     try {
//       await _messaging.markMessagesRead(
//         conversationId: conversationId,
//         messageIds: messageIds,
//       );
//     } catch (_) {}
//   }
//
//   static bool _coerceBool(dynamic v) {
//     if (v == true || v == 1) return true;
//     if (v is String && v.toLowerCase() == 'true') return true;
//     return false;
//   }
//
//   void _onTypingUpdated(Map<String, dynamic> p) {
//     if (disposed) return; //  Guard
//     final conv = p['conversationId']?.toString();
//     if (conv != _resolvedConversationId) return;
//     final uid = p['userId']?.toString();
//     if (uid == null || uid == _myUserId) return;
//     final typing = _coerceBool(p['isTyping']);
//     _peerTyping = typing;
//     if (!disposed) _safeNotify(); //  Guard
//   }
//
//   static String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');
//
//   void onComposerTextChanged() {
//     if (!_canEmitTyping) return;
//     final id = _resolvedConversationId;
//     if (id == null) return;
//
//     if (!_composerTypingActive) {
//       _composerTypingActive = true;
//       _realtime.emitTypingUpdate(conversationId: id, isTyping: true);
//     }
//
//     _typingDebounceTimer?.cancel();
//     _typingDebounceTimer = Timer(const Duration(milliseconds: 800), () {
//       _realtime.emitTypingUpdate(conversationId: id, isTyping: true);
//     });
//
//     _typingIdleTimer?.cancel();
//     _typingIdleTimer = Timer(const Duration(seconds: 2), () {
//       _realtime.emitTypingUpdate(conversationId: id, isTyping: false);
//       _composerTypingActive = false;
//     });
//   }
//
//   void _stopTypingEmit() {
//     _typingDebounceTimer?.cancel();
//     _typingDebounceTimer = null;
//     _typingIdleTimer?.cancel();
//     _typingIdleTimer = null;
//     _composerTypingActive = false;
//     final id = _resolvedConversationId;
//     if (id != null) {
//       _realtime.emitTypingUpdate(conversationId: id, isTyping: false);
//     }
//   }
//
//   Future<void> sendMessage() async {
//     if (!inputEnabled) return;
//
//     final text = _inputController.text.trim();
//     if (text.isEmpty) return;
//
//     final convId = _resolvedConversationId;
//     final myId = _myUserId;
//     if (convId == null || myId == null) return;
//
//     final me = _session.user;
//
//     _stopTypingEmit();
//     _inputController.clear();
//
//     //  sending true করলে inputEnabled false হবে না এখন
//     _sending = true;
//     _safeNotify();
//
//     try {
//       await _messaging.sendTextMessageLocal(
//         conversationId: convId,
//         senderId: myId,
//         senderName: me?.profileName ?? 'You',
//         senderAvatarUrl: me?.profileImageUrl,
//         senderAccountId: me?.accountId,
//         isGroup: isGroup,
//         plaintext: text,
//       );
//     } catch (_) {
//       _inputController.text = text;
//       _snackbar.showError('Could not send message');
//     } finally {
//       _sending = false;
//       _safeNotify();
//       // send শেষে focus ফিরিয়ে দাও
//       messageFocusNode.requestFocus();
//     }
//   }
//
//
//   void showVoiceRecordHint() {
//     _snackbar.showInfo('Press and hold to record a voice message');
//   }
//
//   Future<void> sendVoiceFromFile(String filePath, int durationMs) async {
//     final convId = _resolvedConversationId;
//     final myId = _myUserId;
//     if (convId == null || myId == null) return;
//     if (!messagingEnabled || _loadError != null) return;
//     final me = _session.user;
//
//     if (durationMs < 600) {
//       _snackbar.showInfo('Hold a bit longer to record');
//       try {
//         await File(filePath).delete();
//       } catch (_) {}
//       return;
//     }
//
//     _stopTypingEmit();
//
//     try {
//       await _messaging.sendVoiceMessageLocal(
//         conversationId: convId,
//         senderId: myId,
//         senderName: me?.profileName ?? 'You',
//         senderAvatarUrl: me?.profileImageUrl,
//         senderAccountId: me?.accountId,
//         isGroup: isGroup,
//         filePath: filePath,
//         durationMs: durationMs,
//         conversationTitle: isGroup ? contactName : null,
//         conversationAvatarUrl: avatarUrl,
//       );
//     } catch (_) {
//       _snackbar.showError('Could not queue voice message');
//     }
//   }
//
//   Future<void> sendImageFromPath(String filePath) async {
//     final convId = _resolvedConversationId;
//     final myId = _myUserId;
//     if (convId == null || myId == null) return;
//     if (!messagingEnabled || _loadError != null) return;
//     final me = _session.user;
//
//     _stopTypingEmit();
//
//     try {
//       await _messaging.sendImageMessageLocal(
//         conversationId: convId,
//         senderId: myId,
//         senderName: me?.profileName ?? 'You',
//         senderAvatarUrl: me?.profileImageUrl,
//         senderAccountId: me?.accountId,
//         isGroup: isGroup,
//         filePath: filePath,
//         conversationTitle: isGroup ? contactName : null,
//         conversationAvatarUrl: avatarUrl,
//       );
//     } catch (_) {
//       _snackbar.showError('Could not queue photo');
//     }
//   }
//
//   void insertEmoji(String emoji) {
//     if (!inputEnabled) return;
//     final controller = _inputController;
//     final t = controller.text;
//     final selection = controller.selection;
//     final offset = selection.baseOffset.clamp(0, t.length);
//     controller.text = '${t.substring(0, offset)}$emoji${t.substring(offset)}';
//     controller.selection = TextSelection.collapsed(
//       offset: offset + emoji.length,
//     );
//     onComposerTextChanged();
//     notifyListeners();
//   }
//
//   @override
//   void dispose() {
//     disposed = true; // Set FIRST
//
//     _detachRealtime();
//
//     //  Cancel subscriptions immediately
//     unawaited(_localMessagesSub?.cancel());
//     _localMessagesSub = null;
//
//     //  Cancel timers
//     _readAckTimer?.cancel();
//     _typingDebounceTimer?.cancel();
//     _typingIdleTimer?.cancel();
//     _readAckTimer = null;
//     _typingDebounceTimer = null;
//     _typingIdleTimer = null;
//
//     _pendingReadAckIds.clear();
//     _messageBundleController.dispose();
//     _inputController.dispose();
//
//     super.dispose();
//   }
//
// }

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:titra/core/realtime/realtime_service.dart';
import 'package:titra/core/services/snackbar_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/features/chat/data/message_model.dart';
import 'package:titra/features/chat/data/messaging_repository.dart';
import 'package:titra/features/home/data/conversations_repository.dart';

class ChatViewModel extends ChangeNotifier {
  ChatViewModel({
    required SessionController sessionController,
    required ConversationsRepository conversationsRepository,
    required MessagingRepository messagingRepository,
    required SnackbarService snackbarService,
    required RealtimeService realtimeService,
    required this.contactName,
    required this.contactId,
    this.conversationId,
    this.avatarUrl,
    this.isGroup = false,
    this.participantNames,
    this.messagingEnabled = true,
    this.peerUserId,
    this.groupMemberUserIds,
  }) : _session = sessionController,
       _conversations = conversationsRepository,
       _messaging = messagingRepository,
       _snackbar = snackbarService,
       _realtime = realtimeService;

  final SessionController _session;
  final ConversationsRepository _conversations;
  final MessagingRepository _messaging;
  final SnackbarService _snackbar;
  final RealtimeService _realtime;

  final String contactName;
  final String contactId;
  final String? conversationId;
  final String? avatarUrl;
  final bool isGroup;
  final List<String>? participantNames;
  final bool messagingEnabled;
  final String? peerUserId;
  final List<String>? groupMemberUserIds;

  //  VM এর নিজস্ব focusNode — View এ কোনো আলাদা focusNode নেই
  final FocusNode messageFocusNode = FocusNode();

  List<String>? _resolvedGroupMemberUserIds;
  String? _resolvedPeerUserId;
  bool _peerOnline = false;
  bool disposed = false;

  bool get peerOnline => _peerOnline;

  final ValueNotifier<bool> _sendingNotifier = ValueNotifier<bool>(false);
  ValueNotifier<bool> get sendingNotifier => _sendingNotifier;
  bool get sending => _sendingNotifier.value;

  String? _resolvedConversationId;
  String? _myUserId;

  List<MessageModel> _messages = [];
  List<MessageModel> get messages => _messages;

  final ScrollController _messageBundleController = ScrollController();

  bool _loading = false;
  bool get loading => _loading;

  String? _loadError;
  String? get loadError => _loadError;

  bool _peerTyping = false;
  bool get peerTyping => _peerTyping;

  String get peerTypingLabel =>
      isGroup ? 'Someone is typing' : '$contactName is typing';

  //  KEY FIX: inputEnabled এ _sending নেই
  // sending চলাকালীন inputEnabled false হয় না
  // তাই TextField কখনো disable হয় না → keyboard বন্ধ হয় না
  bool get inputEnabled =>
      messagingEnabled &&
      !_loading &&
      _loadError == null &&
      _resolvedConversationId != null;

  String? get effectivePeerUserId => _resolvedPeerUserId ?? peerUserId;
  ScrollController get messageScrollController => _messageBundleController;
  String? get effectiveConversationId => _resolvedConversationId;

  bool get canPlaceWebrtcCall =>
      !isGroup &&
      messagingEnabled &&
      _loadError == null &&
      !_loading &&
      effectiveConversationId != null &&
      effectivePeerUserId != null &&
      effectivePeerUserId!.isNotEmpty;

  List<String> get remoteUserIdsForGroupCall {
    final my = _myUserId;
    if (my == null || my.isEmpty) return const [];
    final ids = _resolvedGroupMemberUserIds ?? const <String>[];
    return ids.where((id) => id != my).toList();
  }

  bool get canPlaceGroupWebrtcCall =>
      isGroup &&
      messagingEnabled &&
      _loadError == null &&
      !_loading &&
      effectiveConversationId != null &&
      (_resolvedGroupMemberUserIds == null ||
          (remoteUserIdsForGroupCall.isNotEmpty &&
              remoteUserIdsForGroupCall.length <= 4));

  Future<bool> ensurePeerForCall() async {
    if (isGroup || effectiveConversationId == null) return false;
    await _resolvePeerUserIdIfNeeded();
    notifyListeners();
    final p = effectivePeerUserId;
    return p != null && p.isNotEmpty;
  }

  void scrollToBottom({bool animated = true}) {
    if (!_messageBundleController.hasClients) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_messageBundleController.hasClients) return;
      const position = 0.0;
      if (animated) {
        _messageBundleController.animateTo(
          position,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _messageBundleController.jumpTo(position);
      }
    });
  }

  Future<bool> ensureGroupMembersForCall() async {
    if (!isGroup || effectiveConversationId == null) return false;
    if (remoteUserIdsForGroupCall.isNotEmpty) return true;
    try {
      final detail = await _conversations.fetchGroupConversationDetail(
        effectiveConversationId!,
      );
      _resolvedGroupMemberUserIds = List<String>.from(detail.memberUserIds);
      notifyListeners();
    } catch (_) {
      return false;
    }
    return remoteUserIdsForGroupCall.isNotEmpty;
  }

  bool get _canEmitTyping =>
      messagingEnabled &&
      _resolvedConversationId != null &&
      _loadError == null &&
      !_loading;

  //  VM এর নিজস্ব inputController
  final TextEditingController _inputController = TextEditingController();
  TextEditingController get inputController => _inputController;

  StreamSubscription<List<MessageModel>>? _localMessagesSub;
  StreamSubscription<Map<String, dynamic>>? _typingSub;
  StreamSubscription<Map<String, dynamic>>? _presenceSub;
  Timer? _typingDebounceTimer;
  Timer? _typingIdleTimer;
  Timer? _readAckTimer;
  final Set<String> _pendingReadAckIds = <String>{};

  VoidCallback? _realtimeRoomListener;
  String? _roomJoinedId;
  bool _composerTypingActive = false;

  void _safeNotify() {
    if (!disposed && hasListeners) {
      notifyListeners();
    }
  }

  Future<void> bootstrap() async {
    _detachRealtime();
    if (!messagingEnabled) {
      _loading = false;
      if (!disposed) _safeNotify();
      return;
    }

    _loadError = null;

    try {
      final myId = _session.user?.id;
      if (myId == null || myId.isEmpty) {
        _loadError = 'Not signed in';
        if (!disposed) _safeNotify();
        return;
      }
      _myUserId = myId;

      if (conversationId != null && conversationId!.isNotEmpty) {
        _resolvedConversationId = conversationId;
      } else if (!isGroup) {
        final digits = _digitsOnly(contactId);
        if (digits.length != 10) {
          _loadError = 'Invalid Titra ID';
          if (!disposed) _safeNotify();
          return;
        }
        _resolvedConversationId = await _conversations.createDirectConversation(
          digits,
          currentUserId: myId,
        );
      } else {
        _loadError = 'Missing conversation';
        if (!disposed) _safeNotify();
        return;
      }

      if (isGroup &&
          groupMemberUserIds != null &&
          groupMemberUserIds!.isNotEmpty) {
        _resolvedGroupMemberUserIds = List<String>.from(groupMemberUserIds!);
      }

      _loading = false;
      if (!disposed) _safeNotify();

      unawaited(_hydrateInBackground());

      if (!disposed) {
        _subscribeToLocalMessages();
        _attachRealtime();
        final existingPeerIds = _peerMessageIdsForAck();
        _scheduleDeliveredPeerMessages(existingPeerIds);
        _scheduleReadPeerMessages(existingPeerIds);
      }
    } catch (e, st) {
      _loading = false;
      _loadError = 'Could not load messages';
      _messages = [];
      if (!disposed) _safeNotify();
      debugPrint('[ChatVM] bootstrap failed: $e\n$st');
    }
  }

  Future<void> _hydrateInBackground() async {
    try {
      if (_resolvedConversationId == null || _myUserId == null) return;
      await _conversations.refreshConversationDetail(
        _resolvedConversationId!,
        currentUserId: _myUserId!,
      );
      await _messaging.hydrateConversation(
        _resolvedConversationId!,
        currentUserId: _myUserId!,
        isGroup: isGroup,
      );
    } catch (e, st) {
      debugPrint('[ChatVM] Background hydration failed: $e\n$st');
    }
  }

  void _attachRealtime() {
    _detachRealtimeListenersOnly();
    if (!messagingEnabled ||
        _resolvedConversationId == null ||
        _myUserId == null) {
      return;
    }

    _realtimeRoomListener = () {
      final id = _resolvedConversationId;
      if (id == null || !_realtime.isConnected) return;
      if (_roomJoinedId == id) return;
      if (_roomJoinedId != null) {
        _realtime.leaveConversation(_roomJoinedId!);
      }
      _realtime.joinConversation(id);
      _roomJoinedId = id;
      if (!isGroup) {
        unawaited(_syncPeerOnlineFromApi());
      }
    };
    _realtime.addListener(_realtimeRoomListener!);
    _realtimeRoomListener!();

    _typingSub = _realtime.onTypingUpdated.listen(_onTypingUpdated);

    if (!isGroup) {
      _presenceSub = _realtime.onPresenceUpdated.listen(_onPresencePayload);
      unawaited(_syncPeerOnlineFromApi());
    }
  }

  void _detachRealtimeListenersOnly() {
    if (_realtimeRoomListener != null) {
      _realtime.removeListener(_realtimeRoomListener!);
      _realtimeRoomListener = null;
    }
    _typingSub?.cancel();
    _typingSub = null;
    _presenceSub?.cancel();
    _presenceSub = null;
  }

  void _leaveConversationRoom() {
    final id = _roomJoinedId;
    if (id != null) {
      _realtime.leaveConversation(id);
      _roomJoinedId = null;
    }
  }

  void _detachRealtime() {
    _leaveConversationRoom();
    _detachRealtimeListenersOnly();
    _readAckTimer?.cancel();
    _readAckTimer = null;
    _pendingReadAckIds.clear();
    _stopTypingEmit();
    _typingDebounceTimer?.cancel();
    _typingIdleTimer?.cancel();
    _peerTyping = false;
    _peerOnline = false;
  }

  void _subscribeToLocalMessages() {
    final convId = _resolvedConversationId;
    final myId = _myUserId;
    if (convId == null || myId == null) return;

    _localMessagesSub?.cancel();
    _localMessagesSub = _messaging
        .watchMessages(convId, currentUserId: myId, isGroup: isGroup)
        .listen((nextMessages) {
          if (disposed) return;
          final previousLength = _messages.length;
          _messages = nextMessages;
          if (_messages.isNotEmpty && previousLength < _messages.length) {
            scrollToBottom();
          }
          final peerIds = _peerMessageIdsForAck();
          _scheduleDeliveredPeerMessages(peerIds);
          _scheduleReadPeerMessages(peerIds);
          if (!disposed) _safeNotify();
        });
  }

  Future<void> _resolvePeerUserIdIfNeeded() async {
    if (peerUserId != null && peerUserId!.isNotEmpty) {
      _resolvedPeerUserId = peerUserId;
      return;
    }
    final conv = _resolvedConversationId;
    final my = _myUserId;
    if (conv == null || my == null || isGroup) return;
    _resolvedPeerUserId ??= await _conversations.fetchDirectPeerUserId(
      conv,
      my,
    );
  }

  Future<void> _syncPeerOnlineFromApi() async {
    if (isGroup || !messagingEnabled) return;
    await _resolvePeerUserIdIfNeeded();
    final peer = _resolvedPeerUserId ?? peerUserId;
    if (peer == null || peer.isEmpty) return;
    try {
      final on = await _conversations.fetchUserOnline(peer);
      if (_peerOnline != on) {
        _peerOnline = on;
        notifyListeners();
      }
    } catch (_) {}
  }

  void _onPresencePayload(Map<String, dynamic> p) {
    if (disposed) return;
    if (isGroup) return;
    final peer = _resolvedPeerUserId ?? peerUserId;
    if (peer == null) return;
    final uid = p['userId']?.toString();
    if (uid != peer) return;
    final online = p['online'] == true || p['online'] == 1;
    if (_peerOnline == online) return;
    _peerOnline = online;
    if (!disposed) _safeNotify();
  }

  List<String> _peerMessageIdsForAck() {
    return [
      for (final m in _messages)
        if (!m.isFromMe &&
            m.id.isNotEmpty &&
            !m.id.startsWith('local_') &&
            m.status != MessageStatus.read)
          m.id,
    ];
  }

  void _scheduleDeliveredPeerMessages(List<String> messageIds) {
    if (messageIds.isEmpty || !messagingEnabled) return;
    final conv = _resolvedConversationId;
    if (conv == null) return;
    unawaited(_ackDeliveredAsync(conv, messageIds));
  }

  void _scheduleReadPeerMessages(List<String> messageIds) {
    if (messageIds.isEmpty || !messagingEnabled) return;
    final conv = _resolvedConversationId;
    if (conv == null) return;
    _pendingReadAckIds.addAll(messageIds);
    _readAckTimer?.cancel();
    _readAckTimer = Timer(const Duration(milliseconds: 900), () {
      final ids = List<String>.from(_pendingReadAckIds);
      _pendingReadAckIds.clear();
      if (ids.isEmpty) return;
      unawaited(_ackReadAsync(conv, ids));
    });
  }

  Future<void> _ackDeliveredAsync(
    String conversationId,
    List<String> messageIds,
  ) async {
    try {
      await _messaging.markMessagesDelivered(
        conversationId: conversationId,
        messageIds: messageIds,
      );
    } catch (_) {}
  }

  Future<void> _ackReadAsync(
    String conversationId,
    List<String> messageIds,
  ) async {
    try {
      await _messaging.markMessagesRead(
        conversationId: conversationId,
        messageIds: messageIds,
      );
    } catch (_) {}
  }

  static bool _coerceBool(dynamic v) {
    if (v == true || v == 1) return true;
    if (v is String && v.toLowerCase() == 'true') return true;
    return false;
  }

  void _onTypingUpdated(Map<String, dynamic> p) {
    if (disposed) return;
    final conv = p['conversationId']?.toString();
    if (conv != _resolvedConversationId) return;
    final uid = p['userId']?.toString();
    if (uid == null || uid == _myUserId) return;
    final typing = _coerceBool(p['isTyping']);
    _peerTyping = typing;
    if (!disposed) _safeNotify();
  }

  static String _digitsOnly(String s) => s.replaceAll(RegExp(r'[^0-9]'), '');

  void onComposerTextChanged() {
    if (!_canEmitTyping) return;
    final id = _resolvedConversationId;
    if (id == null) return;

    if (!_composerTypingActive) {
      _composerTypingActive = true;
      _realtime.emitTypingUpdate(conversationId: id, isTyping: true);
    }

    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = Timer(const Duration(milliseconds: 800), () {
      _realtime.emitTypingUpdate(conversationId: id, isTyping: true);
    });

    _typingIdleTimer?.cancel();
    _typingIdleTimer = Timer(const Duration(seconds: 2), () {
      _realtime.emitTypingUpdate(conversationId: id, isTyping: false);
      _composerTypingActive = false;
    });
  }

  void _stopTypingEmit() {
    _typingDebounceTimer?.cancel();
    _typingDebounceTimer = null;
    _typingIdleTimer?.cancel();
    _typingIdleTimer = null;
    _composerTypingActive = false;
    final id = _resolvedConversationId;
    if (id != null) {
      _realtime.emitTypingUpdate(conversationId: id, isTyping: false);
    }
  }

  Future<void> sendMessage() async {
    if (!inputEnabled) return;
    final text = _inputController.text.trim();
    if (text.isEmpty) return;
    final convId = _resolvedConversationId;
    final myId = _myUserId;
    if (convId == null || myId == null) return;
    final me = _session.user;

    _stopTypingEmit();
    _inputController.clear();
    // Do NOT touch focus at all — keyboard stays open naturally

    _sendingNotifier.value = true;
    try {
      await _messaging.sendTextMessageLocal(
        conversationId: convId,
        senderId: myId,
        senderName: me?.profileName ?? 'You',
        senderAvatarUrl: me?.profileImageUrl,
        senderAccountId: me?.accountId,
        isGroup: isGroup,
        plaintext: text,
      );
    } catch (_) {
      _inputController.text = text;
      _snackbar.showError('Could not send message');
    } finally {
      _sendingNotifier.value = false;
      // No focus call here
    }
  }




  void showVoiceRecordHint() {
    _snackbar.showInfo('Press and hold to record a voice message');
  }

  //427 038 4756

  Future<void> sendVoiceFromFile(String filePath, int durationMs) async {
    final convId = _resolvedConversationId;
    final myId = _myUserId;
    if (convId == null || myId == null) return;
    if (!messagingEnabled || _loadError != null) return;
    final me = _session.user;

    if (durationMs < 600) {
      _snackbar.showInfo('Hold a bit longer to record');
      try {
        await File(filePath).delete();
      } catch (_) {}
      return;
    }

    _stopTypingEmit();

    try {
      await _messaging.sendVoiceMessageLocal(
        conversationId: convId,
        senderId: myId,
        senderName: me?.profileName ?? 'You',
        senderAvatarUrl: me?.profileImageUrl,
        senderAccountId: me?.accountId,
        isGroup: isGroup,
        filePath: filePath,
        durationMs: durationMs,
        conversationTitle: isGroup ? contactName : null,
        conversationAvatarUrl: avatarUrl,
      );
    } catch (_) {
      _snackbar.showError('Could not queue voice message');
    }
  }

  Future<void> sendImageFromPath(String filePath) async {
    final convId = _resolvedConversationId;
    final myId = _myUserId;
    if (convId == null || myId == null) return;
    if (!messagingEnabled || _loadError != null) return;
    final me = _session.user;

    _stopTypingEmit();

    try {
      await _messaging.sendImageMessageLocal(
        conversationId: convId,
        senderId: myId,
        senderName: me?.profileName ?? 'You',
        senderAvatarUrl: me?.profileImageUrl,
        senderAccountId: me?.accountId,
        isGroup: isGroup,
        filePath: filePath,
        conversationTitle: isGroup ? contactName : null,
        conversationAvatarUrl: avatarUrl,
      );
    } catch (_) {
      _snackbar.showError('Could not queue photo');
    }
  }

  void insertEmoji(String emoji) {
    if (!inputEnabled) return;
    final controller = _inputController;
    final t = controller.text;
    final selection = controller.selection;
    final offset = selection.baseOffset.clamp(0, t.length);
    controller.text = '${t.substring(0, offset)}$emoji${t.substring(offset)}';
    controller.selection = TextSelection.collapsed(
      offset: offset + emoji.length,
    );
    onComposerTextChanged();
  }

  @override
  void dispose() {
    disposed = true;

    _detachRealtime();

    unawaited(_localMessagesSub?.cancel());
    _localMessagesSub = null;

    _readAckTimer?.cancel();
    _typingDebounceTimer?.cancel();
    _typingIdleTimer?.cancel();
    _readAckTimer = null;
    _typingDebounceTimer = null;
    _typingIdleTimer = null;

    _pendingReadAckIds.clear();
    _messageBundleController.dispose();
    _inputController.dispose();
    _sendingNotifier.dispose();

    // messageFocusNode VM এ dispose হয়
    messageFocusNode.dispose();

    super.dispose();
  }
}
