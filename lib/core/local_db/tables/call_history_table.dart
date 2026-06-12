import 'package:drift/drift.dart';

class CallHistory extends Table {
  TextColumn get id => text()();
  TextColumn get callSessionId => text().nullable()();
  TextColumn get conversationId => text().nullable()();
  TextColumn get peerUserId => text().nullable()();
  TextColumn get direction => text()();
  TextColumn get type => text()();
  TextColumn get status => text()();
  TextColumn get displayTitle => text().nullable()();
  TextColumn get avatarUrl => text().nullable()();
  TextColumn get conversationType => text().nullable()();
  IntColumn get startedAt => integer().nullable()();
  IntColumn get answeredAt => integer().nullable()();
  IntColumn get endedAt => integer().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  TextColumn get reason => text().nullable()();
  TextColumn get rawJson => text().nullable()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}
