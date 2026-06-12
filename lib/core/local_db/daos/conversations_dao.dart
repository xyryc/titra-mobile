import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/conversation_members_table.dart';
import '../tables/conversations_table.dart';
import '../tables/users_table.dart';

part 'conversations_dao.g.dart';

@DriftAccessor(tables: [Conversations, ConversationMembers, Users])
class ConversationsDao extends DatabaseAccessor<AppDatabase>
    with _$ConversationsDaoMixin {
  ConversationsDao(super.db);

  Stream<List<ConversationWithMembers>> watchConversationsWithMembers() {
    final query =
        (select(conversations)..orderBy([
              (c) => OrderingTerm.desc(c.lastMessageAt),
              (c) => OrderingTerm.desc(c.updatedAt),
            ]))
            .join([
              leftOuterJoin(
                conversationMembers,
                conversationMembers.conversationId.equalsExp(conversations.id),
              ),
              leftOuterJoin(
                users,
                users.id.equalsExp(conversationMembers.userId),
              ),
            ]);

    return query.watch().map((rows) {
      final byId = <String, _ConversationAccumulator>{};
      final orderedIds = <String>[];

      for (final row in rows) {
        final conversation = row.readTable(conversations);
        final accumulator = byId.putIfAbsent(conversation.id, () {
          orderedIds.add(conversation.id);
          return _ConversationAccumulator(conversation);
        });
        final member = row.readTableOrNull(users);
        if (member != null && accumulator.memberIds.add(member.id)) {
          accumulator.members.add(member);
        }
      }

      return [for (final id in orderedIds) byId[id]!.toView()];
    });
  }

  Stream<Conversation?> watchConversation(String conversationId) {
    return (select(
      conversations,
    )..where((c) => c.id.equals(conversationId))).watchSingleOrNull();
  }

  Future<Conversation?> getConversation(String conversationId) {
    return (select(
      conversations,
    )..where((c) => c.id.equals(conversationId))).getSingleOrNull();
  }

  Future<void> upsertConversation(ConversationsCompanion data) {
    return into(conversations).insert(data, mode: InsertMode.insertOrReplace);
  }

  Future<void> upsertConversations(Iterable<ConversationsCompanion> items) {
    return batch((batch) {
      for (final item in items) {
        batch.insert(conversations, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> replaceMembers(
    String conversationId,
    Iterable<ConversationMembersCompanion> members,
  ) async {
    await transaction(() async {
      await (delete(
        conversationMembers,
      )..where((m) => m.conversationId.equals(conversationId))).go();
      await batch((batch) {
        for (final member in members) {
          batch.insert(
            conversationMembers,
            member,
            mode: InsertMode.insertOrReplace,
          );
        }
      });
    });
  }

  Future<void> setUnreadCount(String conversationId, int count) {
    return (update(conversations)..where((c) => c.id.equals(conversationId)))
        .write(ConversationsCompanion(unreadCount: Value(count)));
  }

  Future<void> clearUnreadCount(String conversationId) {
    return setUnreadCount(conversationId, 0);
  }

  Future<void> incrementUnreadCount(String conversationId) async {
    final current = await getConversation(conversationId);
    if (current == null) return;
    await setUnreadCount(conversationId, current.unreadCount + 1);
  }

  Future<void> updateLastMessage({
    required String conversationId,
    required String lastMessageId,
    required String preview,
    required int timestamp,
    required String senderId,
    bool? isGroup,
    String? title,
    String? avatarUrl,
  }) {
    return (update(
      conversations,
    )..where((c) => c.id.equals(conversationId))).write(
      ConversationsCompanion(
        type: isGroup == null
            ? const Value.absent()
            : Value(isGroup ? 'GROUP' : 'DIRECT'),
        title: title != null ? Value(title) : const Value.absent(),
        avatarUrl: avatarUrl != null ? Value(avatarUrl) : const Value.absent(),
        lastMessageId: Value(lastMessageId),
        lastMessagePreview: Value(preview),
        lastMessageAt: Value(timestamp),
        lastMessageSenderId: Value(senderId),
        updatedAt: Value(timestamp),
      ),
    );
  }
}

class ConversationWithMembers {
  final Conversation conversation;
  final List<User> members;

  const ConversationWithMembers({
    required this.conversation,
    required this.members,
  });
}

class _ConversationAccumulator {
  _ConversationAccumulator(this.conversation);

  final Conversation conversation;
  final List<User> members = <User>[];
  final Set<String> memberIds = <String>{};

  ConversationWithMembers toView() {
    return ConversationWithMembers(
      conversation: conversation,
      members: List<User>.unmodifiable(members),
    );
  }
}
