import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:titra/core/services/snackbar_service.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/core/theme/app_colors.dart';
import 'package:titra/core/utils/titra_id_utils.dart';
import 'package:titra/features/auth/data/user_lookup_coordinator.dart';
import 'package:titra/features/auth/data/user_repository.dart';
import 'package:titra/features/chat/presentation/view/chat_screen.dart';
import 'package:titra/features/home/data/chat_model.dart';
import 'package:titra/features/home/presentation/view_models/home_view_model.dart';

/// Chats tab screen: search, encrypted banner, chat list.
class ChatsTabContent extends StatefulWidget {
  const ChatsTabContent({super.key, required this.scrollController});

  final ScrollController scrollController;

  @override
  State<ChatsTabContent> createState() => _ChatsTabContentState();
}

class _ChatsTabContentState extends State<ChatsTabContent> {
  late final TextEditingController _searchController;
  bool _directoryLookupBusy = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _submitDirectoryLookup() async {
    final digits = _searchController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 10 || _directoryLookupBusy) return;
    FocusScope.of(context).unfocus();
    setState(() => _directoryLookupBusy = true);
    try {
      await UserLookupCoordinator.openChatForTenDigitId(
        context,
        tenDigits: digits,
        repo: context.read<UserRepository>(),
        session: context.read<SessionController>(),
        onError: (message) {
          if (mounted) context.read<SnackbarService>().showError(message);
        },
      );
    } finally {
      if (mounted) setState(() => _directoryLookupBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildSearch(context),
        _buildEncryptedBanner(),
         Expanded(child: _buildChatList(context)),
      ],
    );
  }

  Widget _buildSearch(BuildContext context) {
    final vm = context.read<HomeViewModel>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        textInputAction: TextInputAction.search,
        onChanged: (_) => vm.setSearchQuery(_searchController.text),
        onSubmitted: (_) => _submitDirectoryLookup(),
        decoration: InputDecoration(
          hintText: 'Search by ID or Name...',
          hintStyle: TextStyle(
            color: Colors.black.withValues(alpha: 0.45),
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),

          prefixIcon: Padding(
            padding: const EdgeInsets.only(left: 10, right: 6),
            child: Icon(
              Icons.search_rounded,
              size: 22,
              color: Colors.black.withValues(alpha: 0.45),
            ),
          ),

          prefixIconConstraints: const BoxConstraints(
            minWidth: 42,
          ),

          filled: true,

          fillColor: Colors.white.withValues(alpha: 0.75),

          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(18),
            borderSide: BorderSide.none,
          ),

          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(
              color: Colors.black.withValues(alpha: 0.04),
              width: 1,
            ),
          ),

          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(11),
            borderSide: BorderSide(
              color: AppColors.primary.withValues(alpha: 8),
              width: 1.2,
            ),
          ),

          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),

          suffixIcon: ListenableBuilder(
            listenable: _searchController,
            builder: (context, _) {
              final digits = _searchController.text.replaceAll(
                RegExp(r'[^0-9]'),
                '',
              );

              if (digits.length != 10) {
                return const SizedBox.shrink();
              }

              if (_directoryLookupBusy) {
                return const Padding(
                  padding: EdgeInsets.all(14),
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: IconButton(
                  icon: const Icon(
                    Icons.arrow_forward_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: _submitDirectoryLookup,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildEncryptedBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: AppColors.backgroundLight,
        border: Border.all(color: AppColors.black.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.lock_rounded, size: 14, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            'END-TO-END ENCRYPTED',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: AppColors.primary,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatList(BuildContext context) {
    final vm = context.watch<HomeViewModel>();
    if (vm.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (vm.loadError != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(vm.loadError!, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            TextButton(
              onPressed: vm.loadConversations,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
    final chats = vm.filteredChats;
    if (chats.isEmpty) {
      return Center(
        child: Text(
          vm.searchQuery.isEmpty ? 'No conversations yet' : 'No chats match your search',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return ListView.separated(
      controller: widget.scrollController,
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: chats.length,
      separatorBuilder: (context, index) => Padding(
        padding: const EdgeInsets.only(left: 72),
        child: Divider(height: 1, color: Colors.grey.shade200),
      ),
      itemBuilder: (context, index) {
        final c = chats[index];
        return _ChatTile(
          chat: c,
          onTap: () {
            final contactId = c.contactDisplayId ?? c.id;
            Navigator.of(context).push<void>(
              MaterialPageRoute<void>(
                builder: (_) => ChatScreen(
                  conversationId: c.id,
                  contactName: c.name,
                  contactId: contactId,
                  avatarUrl: c.avatarUrl,
                  isGroup: c.isGroup,
                  participantNames: c.memberNames,
                  peerUserId: c.peerUserId,
                  groupMemberUserIds: c.memberUserIds,
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class _ChatTile extends StatelessWidget {
  const _ChatTile({required this.chat, this.onTap});

  final ChatModel chat;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final hasUnread = chat.unreadCount > 0;
    final isRead = chat.status == ChatMessageStatus.read;
    final lastMsgColor = hasUnread
        ? AppColors.onBackgroundLight
        : (isRead ? Colors.grey.shade600 : AppColors.onBackgroundLight);
    final unreadLabel = chat.unreadCount > 99 ? '99+' : '${chat.unreadCount}';

    return InkWell(
      onTap: onTap,
      child: Container(
        decoration: hasUnread
            ? const BoxDecoration(
                border: Border(
                  left: BorderSide(color: AppColors.primary, width: 4),
                ),
              )
            : null,
        padding: EdgeInsets.fromLTRB(hasUnread ? 12 : 16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _Avatar(chat: chat),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.isNumericId ? formatTitraIdWithPrefix(chat.name) : chat.name,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: hasUnread ? FontWeight.w800 : FontWeight.bold,
                            color: AppColors.onBackgroundLight,
                            fontFamily: chat.isNumericId ? 'monospace' : null,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        chat.timestamp,
                        style: TextStyle(
                          fontSize: 12,
                          color: hasUnread ? AppColors.primary : (isRead ? Colors.grey.shade500 : AppColors.primary),
                          fontWeight: hasUnread ? FontWeight.w700 : (isRead ? FontWeight.w500 : FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (!hasUnread && isRead)
                        Icon(Icons.done_all_rounded, size: 16, color: AppColors.primary)
                      else if (!hasUnread && chat.status == ChatMessageStatus.sent)
                        Icon(Icons.done_rounded, size: 16, color: Colors.grey.shade500)
                      else
                        const SizedBox.shrink(),
                      if (!hasUnread && (isRead || chat.status == ChatMessageStatus.sent))
                        const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          chat.lastMessage,
                          style: TextStyle(
                            fontSize: 14,
                            color: lastMsgColor,
                            fontWeight: hasUnread ? FontWeight.w600 : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(minWidth: 22),
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            unreadLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.chat});

  final ChatModel chat;

  @override
  Widget build(BuildContext context) {
    if (chat.isGroup) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFE8F0FE),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        child: const Icon(Icons.groups_rounded, size: 30, color: AppColors.primary),
      );
    }
    if (chat.avatarUrl != null && chat.avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 28,
        backgroundImage: NetworkImage(chat.avatarUrl!),
      );
    }
    if (chat.isNumericId && chat.name.contains('-')) {
      return Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: const Color(0xFFF3F4F6),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.outlineLight),
        ),
        child: const Center(
          child: Text('#', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Color(0xFF9CA3AF))),
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.grey.shade300, Colors.grey.shade400],
        ),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white70),
      ),
      child: Icon(Icons.person_rounded, size: 28, color: Colors.grey.shade600),
    );
  }
}
