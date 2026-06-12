import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../app_database.dart';
import '../tables/sync_queue_table.dart';
import '../tables/sync_state_table.dart';

part 'sync_dao.g.dart';

@DriftAccessor(tables: [SyncQueue, SyncState])
class SyncDao extends DatabaseAccessor<AppDatabase> with _$SyncDaoMixin {
  SyncDao(super.db);

  Future<String> queueOperation({
    required String entityType,
    required String entityId,
    required String operation,
    required Map<String, dynamic> payload,
  }) {
    final id = const Uuid().v4();
    return into(syncQueue)
        .insert(
          SyncQueueCompanion.insert(
            id: id,
            entityType: entityType,
            entityId: entityId,
            operation: operation,
            payloadJson: jsonEncode(payload),
            createdAt: DateTime.now().millisecondsSinceEpoch,
          ),
          mode: InsertMode.insertOrReplace,
        )
        .then((_) => id);
  }

  Future<List<SyncQueueData>> getPendingOperations({int limit = 20}) {
    return (select(syncQueue)
          ..where(
            (s) =>
                s.nextRetryAt.isNull() |
                s.nextRetryAt.isSmallerOrEqualValue(
                  DateTime.now().millisecondsSinceEpoch,
                ),
          )
          ..orderBy([(s) => OrderingTerm.asc(s.createdAt)])
          ..limit(limit))
        .get();
  }

  Future<void> markOperationSynced(String operationId) {
    return (delete(syncQueue)..where((s) => s.id.equals(operationId))).go();
  }

  Future<void> scheduleRetry(
    String operationId, {
    int delaySeconds = 30,
    String? lastError,
  }) async {
    final current = await (select(
      syncQueue,
    )..where((s) => s.id.equals(operationId))).getSingleOrNull();
    if (current == null) return;
    await (update(syncQueue)..where((s) => s.id.equals(operationId))).write(
      SyncQueueCompanion(
        attemptCount: Value(current.attemptCount + 1),
        nextRetryAt: Value(
          DateTime.now()
              .add(Duration(seconds: delaySeconds))
              .millisecondsSinceEpoch,
        ),
        lastError: lastError != null ? Value(lastError) : const Value.absent(),
      ),
    );
  }

  Future<void> setSyncCursor(String key, String value) {
    return into(syncState).insert(
      SyncStateCompanion.insert(
        key: key,
        value: Value(value),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
      mode: InsertMode.insertOrReplace,
    );
  }

  Future<String?> getSyncCursor(String key) async {
    final result = await (select(
      syncState,
    )..where((s) => s.key.equals(key))).getSingleOrNull();
    return result?.value;
  }
}
