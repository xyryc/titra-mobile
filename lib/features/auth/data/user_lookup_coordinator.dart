import 'package:flutter/material.dart';
import 'package:titra/core/session/session_controller.dart';
import 'package:titra/features/auth/data/user_repository.dart';
import 'package:titra/features/chat/presentation/view/chat_screen.dart';

/// Shared directory lookup used by [AddPersonScreen] and chats search (10-digit ID).
class UserLookupCoordinator {
  UserLookupCoordinator._();

  /// Looks up [tenDigits] in the signup directory and opens a read-only chat, or reports an error.
  static Future<void> openChatForTenDigitId(
    BuildContext context, {
    required String tenDigits,
    required UserRepository repo,
    required SessionController session,
    required void Function(String message) onError,
    bool replace = false,
  }) async {
    if (tenDigits.length != 10) return;

    try {
      final outcome = await repo.searchByAccountId(
        tenDigits: tenDigits,
        currentAccountId: session.user?.accountId,
      );
      if (!context.mounted) return;

      switch (outcome.result) {
        case UserSearchResult.notFound:
          onError('No user found with this Titra ID.');
          return;
        case UserSearchResult.isSelf:
          onError('That is your own Titra ID.');
          return;
        case UserSearchResult.found:
          final u = outcome.user!;
          final route = MaterialPageRoute<void>(
            builder: (_) => ChatScreen(
              conversationId: null,
              contactName: u.profileName,
              contactId: u.accountId,
              peerUserId: u.id,
            ),
          );

          if (replace) {
            await Navigator.of(context).pushReplacement(route);
          } else {
            await Navigator.of(context).push(route);
          }
      }
    } catch (_) {
      if (context.mounted) {
        onError('Could not search. Check your connection and API URL.');
      }
    }
  }
}
