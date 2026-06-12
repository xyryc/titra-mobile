import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/messages_table.dart';
import '../tables/users_table.dart';

part 'messages_dao.g.dart';

@DriftAccessor(tables: [Messages, Users])
class MessagesDao extends DatabaseAccessor<AppDatabase>
    with _$MessagesDaoMixin {
  MessagesDao(super.db);

  Stream<List<MessageWithSenderRow>> watchMessages(String conversationId) {
    return (select(messages)
          ..where((m) => m.conversationId.equals(conversationId))
          ..orderBy([(m) => OrderingTerm.asc(m.createdAtLocal)]))
        .join([leftOuterJoin(users, users.id.equalsExp(messages.senderId))])
        .map((row) {
          return MessageWithSenderRow(
            message: row.readTable(messages),
            sender: row.readTableOrNull(users),
          );
        })
        .watch();
  }

  Future<void> upsertMessage(MessagesCompanion data) {
    return into(messages).insert(data, mode: InsertMode.insertOrReplace);
  }

  Future<void> upsertMessages(Iterable<MessagesCompanion> items) {
    return batch((batch) {
      for (final item in items) {
        batch.insert(messages, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<Message?> getMessageByLocalId(String localId) {
    return (select(
      messages,
    )..where((m) => m.localId.equals(localId))).getSingleOrNull();
  }

  Future<Message?> getMessageByServerId(String serverId) {
    return (select(
      messages,
    )..where((m) => m.serverId.equals(serverId))).getSingleOrNull();
  }

  Future<Message?> getMessageByClientMessageId(String clientMessageId) {
    return (select(messages)
          ..where((m) => m.clientMessageId.equals(clientMessageId)))
        .getSingleOrNull();
  }

  Future<Message?> findMessage({
    String? localId,
    String? serverId,
    String? clientMessageId,
  }) async {
    if (localId != null && localId.isNotEmpty) {
      final local = await getMessageByLocalId(localId);
      if (local != null) return local;
    }
    if (serverId != null && serverId.isNotEmpty) {
      final remote = await getMessageByServerId(serverId);
      if (remote != null) return remote;
    }
    if (clientMessageId != null && clientMessageId.isNotEmpty) {
      return getMessageByClientMessageId(clientMessageId);
    }
    return null;
  }

  Future<void> updateMessageStatus({
    required String localId,
    required String status,
    String? syncState,
    int? deliveredAt,
    int? readAt,
    String? errorMessage,
  }) {
    return (update(messages)..where((m) => m.localId.equals(localId))).write(
      MessagesCompanion(
        status: Value(status),
        syncState: syncState != null ? Value(syncState) : const Value.absent(),
        deliveredAt: deliveredAt != null
            ? Value(deliveredAt)
            : const Value.absent(),
        readAt: readAt != null ? Value(readAt) : const Value.absent(),
        errorMessage: errorMessage != null
            ? Value(errorMessage)
            : const Value.absent(),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> attachRemoteMessage({
    required String localId,
    required String serverId,
    required String status,
    required String syncState,
    required int sentAt,
    required String rawJson,
  }) {
    return (update(messages)..where((m) => m.localId.equals(localId))).write(
      MessagesCompanion(
        serverId: Value(serverId),
        sentAt: Value(sentAt),
        status: Value(status),
        syncState: Value(syncState),
        rawJson: Value(rawJson),
        errorMessage: const Value(null),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<List<Message>> getPendingMessages({String? conversationId}) {
    final query = select(messages)
      ..where(
        (m) => m.syncState.equals('queued') | m.syncState.equals('failed'),
      )
      ..orderBy([(m) => OrderingTerm.asc(m.createdAtLocal)]);
    if (conversationId != null && conversationId.isNotEmpty) {
      query.where((m) => m.conversationId.equals(conversationId));
    }
    return query.get();
  }

  Future<void> markMessageFailed({
    required String localId,
    required String error,
  }) {
    return (update(messages)..where((m) => m.localId.equals(localId))).write(
      MessagesCompanion(
        status: const Value('failed'),
        syncState: const Value('failed'),
        errorMessage: Value(error),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }

  Future<void> markStatusesByServerIds({
    required List<String> serverIds,
    required String status,
    int? deliveredAt,
    int? readAt,
  }) async {
    if (serverIds.isEmpty) return;
    await (update(messages)..where((m) => m.serverId.isIn(serverIds))).write(
      MessagesCompanion(
        status: Value(status),
        deliveredAt: deliveredAt != null
            ? Value(deliveredAt)
            : const Value.absent(),
        readAt: readAt != null ? Value(readAt) : const Value.absent(),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}

class MessageWithSenderRow {
  const MessageWithSenderRow({required this.message, required this.sender});

  final Message message;
  final User? sender;
}
