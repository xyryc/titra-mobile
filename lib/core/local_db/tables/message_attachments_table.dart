import 'package:drift/drift.dart';

class MessageAttachments extends Table {
  TextColumn get id => text()();
  TextColumn get messageLocalId => text()();
  TextColumn get type => text().nullable()();
  TextColumn get remoteUrl => text().nullable()();
  TextColumn get storageKey => text().nullable()();
  TextColumn get localPath => text().nullable()();
  TextColumn get fileName => text().nullable()();
  TextColumn get mimeType => text().nullable()();
  IntColumn get sizeBytes => integer().nullable()();
  IntColumn get width => integer().nullable()();
  IntColumn get height => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
