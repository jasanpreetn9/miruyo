import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/client.dart';
import 'package:miruyo/core/anilist/errors.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/storage/database.dart';
import 'package:miruyo/core/sync/edit_queue.dart';

import '../helpers.dart';

void main() {
  late MemoryEditStore store;
  late EditQueue queue;
  late FakeEditApi api;

  setUp(() {
    store = MemoryEditStore();
    queue = EditQueue(store);
    api = FakeEditApi();
  });

  test('merges back-to-back saves for one title', () async {
    await queue.enqueueSave(1, const EntryInput(progress: 6));
    await queue.enqueueSave(1, const EntryInput(progress: 7, status: MediaListStatus.completed));
    final edits = await queue.pending();
    expect(edits, hasLength(1));
    expect(edits.single.input.toJson(), {'status': 'COMPLETED', 'progress': 7});
  });

  test('keeps saves for different titles apart, in order', () async {
    await queue.enqueueSave(1, const EntryInput(progress: 6));
    await queue.enqueueSave(2, const EntryInput(progress: 1));
    await queue.flush(api);
    expect(api.saves.map((s) => s.$1), [1, 2]);
    expect(await queue.pending(), isEmpty);
  });

  test('a delete drops the saves still waiting for that title', () async {
    await queue.enqueueSave(1, const EntryInput(progress: 6));
    await queue.enqueueDelete(1, 70);
    final edits = await queue.pending();
    expect(edits.single.op, EditOp.delete);
    await queue.flush(api);
    expect(api.saves, isEmpty);
    expect(api.deletes, [70]);
  });

  test('deleting an entry that only existed offline sends nothing', () async {
    await queue.enqueueSave(3, const EntryInput(status: MediaListStatus.planning));
    await queue.enqueueDelete(3, null);
    expect(await queue.pending(), isEmpty);
  });

  test('stops at the first edit AniList cannot take yet, keeping the rest', () async {
    await queue.enqueueSave(1, const EntryInput(progress: 6));
    await queue.enqueueSave(2, const EntryInput(progress: 1));
    api.saveResults.add(offline);
    final result = await queue.flush(api);
    expect(result.stopped?.kind, AniListErrorKind.network);
    final left = await queue.pending();
    expect(left.map((e) => e.mediaId), [1, 2]);
    expect(left.first.attempts, 1);
  });

  test('drops an edit AniList refuses and carries on', () async {
    await queue.enqueueSave(1, const EntryInput(progress: 999));
    await queue.enqueueSave(2, const EntryInput(progress: 1));
    api.saveResults.add(refused);
    final result = await queue.flush(api);
    expect(result.rejected.single.$1.mediaId, 1);
    expect(result.saved.single.mediaId, 2);
    expect(await queue.pending(), isEmpty);
  });

  test('persists in the database between launches', () async {
    final db = AppDatabase.memory();
    addTearDown(db.close);
    await EditQueue(DriftEditStore(db)).enqueueSave(5, const EntryInput(progress: 2, notes: 'hi'));
    final reopened = await EditQueue(DriftEditStore(db)).pending();
    expect(reopened.single.mediaId, 5);
    expect(reopened.single.input.toJson(), {'progress': 2, 'notes': 'hi'});
  });

  test('EntryInput round-trips dates, including a cleared one', () {
    const input = EntryInput(startedAt: AniListDate(year: 2026, month: 10, day: 9), completedAt: AniListDate.empty);
    final back = EntryInput.fromJson(input.toJson());
    expect(back.startedAt, const AniListDate(year: 2026, month: 10, day: 9));
    expect(back.completedAt?.isEmpty, isTrue);
  });
}
