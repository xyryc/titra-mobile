import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/users_table.dart';

part 'users_dao.g.dart';

@DriftAccessor(tables: [Users])
class UsersDao extends DatabaseAccessor<AppDatabase> with _$UsersDaoMixin {
  UsersDao(super.db);

  Future<void> upsertUser(UsersCompanion user) {
    return into(users).insert(user, mode: InsertMode.insertOrReplace);
  }

  Future<void> upsertUsers(Iterable<UsersCompanion> items) {
    return batch((batch) {
      for (final item in items) {
        batch.insert(users, item, mode: InsertMode.insertOrReplace);
      }
    });
  }

  Stream<User?> watchUser(String userId) {
    return (select(
      users,
    )..where((u) => u.id.equals(userId))).watchSingleOrNull();
  }

  Future<User?> getUser(String userId) {
    return (select(users)..where((u) => u.id.equals(userId))).getSingleOrNull();
  }

  Future<List<User>> getUsersByIds(List<String> userIds) {
    if (userIds.isEmpty) return Future.value(const []);
    return (select(users)..where((u) => u.id.isIn(userIds))).get();
  }
}
