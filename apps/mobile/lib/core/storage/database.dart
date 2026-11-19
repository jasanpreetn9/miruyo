import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../anilist/client.dart';
import '../anilist/types.dart';

part 'database.g.dart';

/// The last good copy of responses the app must show offline (the list,
/// Home's rows), keyed by query name and variables.
class KvCache extends Table {
  TextColumn get key => text()();
  TextColumn get data => text()();
  DateTimeColumn get savedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {key};
}

/// List edits made while AniList couldn't be reached, sent in order once it can.
@DataClassName('PendingEditRow')
class PendingEdits extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get mediaId => integer()();

  /// 'save' or 'delete'.
  TextColumn get op => text()();

  /// The EntryInput fields, as JSON (saves only).
  TextColumn get payload => text().withDefault(const Constant('{}'))();

  /// The list entry's id (deletes only).
  IntColumn get entryId => integer().nullable()();

  /// The title, for "Couldn't sync X" messages.
  TextColumn get label => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
}

@DriftDatabase(tables: [KvCache, PendingEdits])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  /// The app's database file, opened off the UI thread.
  factory AppDatabase.open() => AppDatabase(
    LazyDatabase(() async {
      final dir = await getApplicationSupportDirectory();
      return NativeDatabase.createInBackground(File(p.join(dir.path, 'miruyo.sqlite')));
    }),
  );

  /// For tests.
  factory AppDatabase.memory() => AppDatabase(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  /// Forgets everything the signed-in viewer left on the device.
  Future<void> clearViewerData() => transaction(() async {
    await delete(kvCache).go();
    await delete(pendingEdits).go();
  });
}

/// The client's [ResponseStore], backed by [KvCache].
class DriftResponseStore implements ResponseStore {
  DriftResponseStore(this.db);

  final AppDatabase db;

  @override
  Future<({Json data, DateTime savedAt})?> read(String key) async {
    final row = await (db.select(db.kvCache)..where((t) => t.key.equals(key))).getSingleOrNull();
    if (row == null) return null;
    return (data: jsonDecode(row.data) as Json, savedAt: row.savedAt);
  }

  @override
  Future<void> write(String key, Json data) => db
      .into(db.kvCache)
      .insertOnConflictUpdate(KvCacheCompanion.insert(key: key, data: jsonEncode(data), savedAt: DateTime.now()));

  @override
  Future<void> clear() => db.delete(db.kvCache).go();
}
