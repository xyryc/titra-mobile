import 'package:drift/drift.dart';

class Profiles extends Table {
  TextColumn get userId => text()();
  TextColumn get statusText => text().nullable()();
  TextColumn get bio => text().nullable()();
  TextColumn get photoUrl => text().nullable()();
  TextColumn get rawJson => text().nullable()();
  IntColumn get updatedAt => integer().withDefault(const Constant(0))();
  TextColumn get syncState => text().withDefault(const Constant('synced'))();

  @override
  Set<Column> get primaryKey => {userId};
}
