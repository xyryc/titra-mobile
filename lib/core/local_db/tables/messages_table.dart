import 'package:drift/drift.dart';

class Messages extends Table {
  TextColumn get localId => text()();
  TextColumn get clientMessageId => text().nullable()();
  TextColumn get serverId => text().nullable()();
  TextColumn get conversationId => text()();
  TextColumn get senderId => text()();
  TextColumn get type => text()();
  TextColumn get messageText => text().named('text').nullable()();
  IntColumn get attachmentCount => integer().withDefault(const Constant(0))();
  TextColumn get replyToServerId => text().nullable()();
  TextColumn get replyToLocalId => text().nullable()();
  IntColumn get sentAt => integer().nullable()();
  IntColumn get createdAtLocal => integer()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  IntColumn get deliveredAt => integer().nullable()();
  IntColumn get readAt => integer().nullable()();
  TextColumn get status => text().withDefault(const Constant('pending'))();
  TextColumn get syncState => text().withDefault(const Constant('queued'))();
  TextColumn get errorMessage => text().nullable()();
  TextColumn get rawJson => text().nullable()();

  @override
  Set<Column> get primaryKey => {localId};
}
