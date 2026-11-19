// List edits that couldn't reach AniList, kept on the device and sent in
// order once they can. Every edit is optimistic, so the list already shows
// the change; this only makes sure AniList ends up agreeing.

import 'dart:convert';

import 'package:drift/drift.dart';

import '../anilist/client.dart';
import '../anilist/errors.dart';
import '../anilist/types.dart';
import '../storage/database.dart';

enum EditOp { save, delete }

class PendingEdit {
  const PendingEdit({
    required this.mediaId,
    required this.op,
    this.id,
    this.input = const EntryInput(),
    this.entryId,
    this.label = '',
    this.attempts = 0,
  });

  final int? id;
  final int mediaId;
  final EditOp op;

  /// Saves: the fields to send.
  final EntryInput input;

  /// Deletes: the list entry to remove.
  final int? entryId;

  /// The title, for messages.
  final String label;
  final int attempts;
}

/// Where the queue is kept. [DriftEditStore] in the app, a list in tests.
abstract interface class EditStore {
  Future<List<PendingEdit>> all();
  Future<void> add(PendingEdit edit);
  Future<void> update(PendingEdit edit);
  Future<void> remove(int id);
}

/// What sending an edit takes; [AniListClient] in the app.
abstract interface class EditApi {
  Future<AniListSavedEntry> saveEntry(int mediaId, EntryInput input);
  Future<bool> deleteEntry(int entryId);
}

class ClientEditApi implements EditApi {
  ClientEditApi(this.client);

  final AniListClient client;

  @override
  Future<AniListSavedEntry> saveEntry(int mediaId, EntryInput input) => client.saveEntry(mediaId, input);

  @override
  Future<bool> deleteEntry(int entryId) => client.deleteEntry(entryId);
}

/// How a flush went.
class FlushResult {
  const FlushResult({this.saved = const [], this.deleted = const [], this.rejected = const [], this.stopped});

  /// Saves AniList accepted, with what it now holds.
  final List<AniListSavedEntry> saved;

  /// Media ids whose entries were removed.
  final List<int> deleted;

  /// Edits AniList refused outright; they're dropped from the queue.
  final List<(PendingEdit, AniListError)> rejected;

  /// Why the flush stopped early (offline, rate limit, signed out); null if
  /// the queue emptied.
  final AniListError? stopped;
}

class EditQueue {
  EditQueue(this.store);

  final EditStore store;
  bool _flushing = false;

  Future<List<PendingEdit>> pending() => store.all();

  Future<bool> hasPendingFor(int mediaId) async => (await store.all()).any((e) => e.mediaId == mediaId);

  /// Queues a save. Back-to-back saves for one title merge into one.
  Future<void> enqueueSave(int mediaId, EntryInput input, {String label = ''}) async {
    final edits = await store.all();
    final last = edits.where((e) => e.mediaId == mediaId).lastOrNull;
    if (last != null && last.op == EditOp.save && last.attempts == 0) {
      await store.update(
        PendingEdit(
          id: last.id,
          mediaId: mediaId,
          op: EditOp.save,
          input: last.input.merge(input),
          label: label.isEmpty ? last.label : label,
        ),
      );
      return;
    }
    await store.add(PendingEdit(mediaId: mediaId, op: EditOp.save, input: input, label: label));
  }

  /// Queues taking a title off the list. Saves still waiting for it are
  /// dropped. With no [entryId], the entry only ever existed in those
  /// queued saves, so there's nothing left to send.
  Future<void> enqueueDelete(int mediaId, int? entryId, {String label = ''}) async {
    for (final e in await store.all()) {
      if (e.mediaId == mediaId && e.op == EditOp.save && e.id != null) await store.remove(e.id!);
    }
    if (entryId == null) return;
    await store.add(PendingEdit(mediaId: mediaId, op: EditOp.delete, entryId: entryId, label: label));
  }

  /// Sends queued edits in order. Stops at the first edit AniList can't take
  /// right now (offline, rate limit, signed out) and keeps it and the rest.
  Future<FlushResult> flush(EditApi api) async {
    if (_flushing) return const FlushResult();
    _flushing = true;
    final saved = <AniListSavedEntry>[];
    final deleted = <int>[];
    final rejected = <(PendingEdit, AniListError)>[];
    try {
      for (final edit in await store.all()) {
        try {
          if (edit.op == EditOp.save) {
            saved.add(await api.saveEntry(edit.mediaId, edit.input));
          } else {
            await api.deleteEntry(edit.entryId!);
            deleted.add(edit.mediaId);
          }
          await store.remove(edit.id!);
        } on AniListError catch (err) {
          if (err.isTransient || err.isUnauthorized) {
            await store.update(
              PendingEdit(
                id: edit.id,
                mediaId: edit.mediaId,
                op: edit.op,
                input: edit.input,
                entryId: edit.entryId,
                label: edit.label,
                attempts: edit.attempts + 1,
              ),
            );
            return FlushResult(saved: saved, deleted: deleted, rejected: rejected, stopped: err);
          }
          // AniList refused this one: retrying won't help
          await store.remove(edit.id!);
          rejected.add((edit, err));
        }
      }
      return FlushResult(saved: saved, deleted: deleted, rejected: rejected);
    } finally {
      _flushing = false;
    }
  }
}

/// [EditStore] backed by the PendingEdits table.
class DriftEditStore implements EditStore {
  DriftEditStore(this.db);

  final AppDatabase db;

  PendingEdit _fromRow(PendingEditRow r) => PendingEdit(
    id: r.id,
    mediaId: r.mediaId,
    op: r.op == 'delete' ? EditOp.delete : EditOp.save,
    input: EntryInput.fromJson(jsonDecode(r.payload) as Json),
    entryId: r.entryId,
    label: r.label,
    attempts: r.attempts,
  );

  PendingEditsCompanion _toCompanion(PendingEdit e) => PendingEditsCompanion.insert(
    mediaId: e.mediaId,
    op: e.op.name,
    payload: Value(jsonEncode(e.input.toJson())),
    entryId: Value(e.entryId),
    label: Value(e.label),
    createdAt: DateTime.now(),
    attempts: Value(e.attempts),
  );

  @override
  Future<List<PendingEdit>> all() async {
    final rows = await (db.select(db.pendingEdits)..orderBy([(t) => OrderingTerm.asc(t.id)])).get();
    return rows.map(_fromRow).toList();
  }

  @override
  Future<void> add(PendingEdit edit) => db.into(db.pendingEdits).insert(_toCompanion(edit));

  @override
  Future<void> update(PendingEdit edit) => (db.update(db.pendingEdits)..where((t) => t.id.equals(edit.id!))).write(
    PendingEditsCompanion(
      payload: Value(jsonEncode(edit.input.toJson())),
      label: Value(edit.label),
      attempts: Value(edit.attempts),
    ),
  );

  @override
  Future<void> remove(int id) => (db.delete(db.pendingEdits)..where((t) => t.id.equals(id))).go();
}
