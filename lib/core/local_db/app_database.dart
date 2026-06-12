import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'daos/calls_dao.dart';
import 'daos/conversations_dao.dart';
import 'daos/messages_dao.dart';
import 'daos/profile_dao.dart';
import 'daos/sync_dao.dart';
import 'daos/users_dao.dart';
import 'tables/users_table.dart';
import 'tables/profiles_table.dart';
import 'tables/conversations_table.dart';
import 'tables/conversation_members_table.dart';
import 'tables/messages_table.dart';
import 'tables/message_attachments_table.dart';
import 'tables/call_history_table.dart';
import 'tables/sync_queue_table.dart';
import 'tables/sync_state_table.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Users,
    Profiles,
    Conversations,
    ConversationMembers,
    Messages,
    MessageAttachments,
    CallHistory,
    SyncQueue,
    SyncState,
  ],
  daos: [
    UsersDao,
    ProfilesDao,
    ConversationsDao,
    MessagesDao,
    CallHistoryDao,
    SyncDao,
  ],
)
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(_openConnection());
  AppDatabase.forTesting(super.executor);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (migrator) async {
      await migrator.createAll();
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON') ;
    },
  );
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dbFolder = await getApplicationDocumentsDirectory();
    final file = File(p.join(dbFolder.path, 'titra.sqlite'));
    return NativeDatabase.createInBackground(file);
  });
}
