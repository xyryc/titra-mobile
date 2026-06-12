import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/call_history_table.dart';

part 'calls_dao.g.dart';

@DriftAccessor(tables: [CallHistory])
class CallHistoryDao extends DatabaseAccessor<AppDatabase>
    with _$CallHistoryDaoMixin {
  CallHistoryDao(super.db);

  Stream<List<CallHistoryData>> watchCallHistory() {
    return (select(callHistory)..orderBy([
          (c) => OrderingTerm.desc(c.endedAt),
          (c) => OrderingTerm.desc(c.startedAt),
          (c) => OrderingTerm.desc(c.updatedAt),
        ]))
        .watch();
  }

  Future<void> upsertCallHistory(CallHistoryCompanion data) {
    return into(callHistory).insert(data, mode: InsertMode.insertOrReplace);
  }

  Future<void> upsertCallHistoryBatch(Iterable<CallHistoryCompanion> items) {
    return batch((batch) {
      for (final item in items) {
        batch.insert(callHistory, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Future<void> updateCallStatus({
    required String callId,
    required String status,
    int? answeredAt,
    int? endedAt,
    int? durationSeconds,
  }) {
    return (update(callHistory)..where((c) => c.id.equals(callId))).write(
      CallHistoryCompanion(
        status: Value(status),
        answeredAt: answeredAt != null
            ? Value(answeredAt)
            : const Value.absent(),
        endedAt: endedAt != null ? Value(endedAt) : const Value.absent(),
        durationSeconds: durationSeconds != null
            ? Value(durationSeconds)
            : const Value.absent(),
        updatedAt: Value(DateTime.now().millisecondsSinceEpoch),
      ),
    );
  }
}
