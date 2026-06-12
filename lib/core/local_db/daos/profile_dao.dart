import 'package:drift/drift.dart';

import '../app_database.dart';
import '../tables/profiles_table.dart';

part 'profile_dao.g.dart';

@DriftAccessor(tables: [Profiles])
class ProfilesDao extends DatabaseAccessor<AppDatabase>
    with _$ProfilesDaoMixin {
  ProfilesDao(super.db);

  Stream<Profile?> watchProfile(String userId) {
    return (select(
      profiles,
    )..where((p) => p.userId.equals(userId))).watchSingleOrNull();
  }

  Future<Profile?> getProfile(String userId) {
    return (select(
      profiles,
    )..where((p) => p.userId.equals(userId))).getSingleOrNull();
  }

  Future<void> upsertProfile(ProfilesCompanion profile) {
    return into(profiles).insert(profile, mode: InsertMode.insertOrReplace);
  }
}
