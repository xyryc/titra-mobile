// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calls_dao.dart';

// ignore_for_file: type=lint
mixin _$CallHistoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $CallHistoryTable get callHistory => attachedDatabase.callHistory;
  CallHistoryDaoManager get managers => CallHistoryDaoManager(this);
}

class CallHistoryDaoManager {
  final _$CallHistoryDaoMixin _db;
  CallHistoryDaoManager(this._db);
  $$CallHistoryTableTableManager get callHistory =>
      $$CallHistoryTableTableManager(_db.attachedDatabase, _db.callHistory);
}
