// Ported from the web's lib/editor/draft.test.ts.

import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/client.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/list/list_entry.dart';
import 'package:miruyo/features/editor/draft.dart';

const today = AniListDate(year: 2026, month: 10, day: 10);
const anime = DraftTotals(total: 28);
const ongoing = DraftTotals();

const entry = ListEntry(
  id: 7,
  mediaId: 1,
  status: MediaListStatus.current,
  progress: 7,
  score: 8.5,
  startedAt: AniListDate(year: 2026, month: 10, day: 2),
  notes: 'Fern!',
);

void main() {
  test('copies an existing entry', () {
    final d = EntryDraft.from(entry);
    expect((d.status, d.progress, d.score, d.notes), (MediaListStatus.current, 7, 8.5, 'Fern!'));
    expect(d.startedAt, const AniListDate(year: 2026, month: 10, day: 2));
  });

  test('starts a new entry as Planning', () {
    expect(EntryDraft.from(null).status, MediaListStatus.planning);
  });

  test('starting fills the start date with today, but keeps one already set', () {
    expect(withStatus(EntryDraft.from(null), MediaListStatus.current, anime, on: today).startedAt, today);
    expect(
      withStatus(EntryDraft.from(entry), MediaListStatus.current, anime, on: today).startedAt,
      const AniListDate(year: 2026, month: 10, day: 2),
    );
  });

  test('completing fills progress to the total and the finish date', () {
    final done = withStatus(EntryDraft.from(entry), MediaListStatus.completed, anime, on: today);
    expect((done.status, done.progress, done.completedAt), (MediaListStatus.completed, 28, today));
  });

  test('completing a manga fills volumes too, and leaves unknown totals alone', () {
    final manga = withStatus(
      EntryDraft.from(null),
      MediaListStatus.completed,
      const DraftTotals(total: 93, volumes: 8),
      on: today,
    );
    expect((manga.progress, manga.progressVolumes), (93, 8));
    final open = withStatus(EntryDraft.from(entry), MediaListStatus.completed, ongoing, on: today);
    expect(open.progress, 7);
  });

  test('offers completion at the last episode, never completes on its own', () {
    final atEnd = withProgress(EntryDraft.from(entry), 28, anime);
    expect(atEnd.status, MediaListStatus.current);
    expect(offersCompletion(atEnd, anime), isTrue);
    expect(offersCompletion(withProgress(EntryDraft.from(entry), 27, anime), anime), isFalse);
    expect(offersCompletion(atEnd, ongoing), isFalse);
  });

  test('clamps progress and volumes to their totals', () {
    expect(withProgress(EntryDraft.from(entry), 99, anime).progress, 28);
    expect(withProgress(EntryDraft.from(entry), -3, anime).progress, 0);
    expect(withProgress(EntryDraft.from(entry), 500, ongoing).progress, 500);
    expect(withVolumes(EntryDraft.from(null), 12, const DraftTotals(volumes: 8)).progressVolumes, 8);
  });

  test('sends only what changed', () {
    final initial = EntryDraft.from(entry);
    final d = initial.copyWith(progress: 9, score: 9);
    expect(changes(initial, d).toJson(), {'progress': 9, 'score': 9.0});
  });

  test('clears a date by sending an all-null date', () {
    final initial = EntryDraft.from(entry);
    expect(changes(initial, initial.copyWith(startedAt: AniListDate.empty)).toJson(), {
      'startedAt': {'year': null, 'month': null, 'day': null},
    });
  });

  test('knows when nothing changed', () {
    final initial = EntryDraft.from(entry);
    expect(isDirty(initial, initial.copyWith()), isFalse);
    expect(isDirty(initial, initial.copyWith(private: true)), isTrue);
  });

  group('custom lists', () {
    final saved = AniListSavedEntry.fromJson({
      'id': 7,
      'mediaId': 1,
      'status': 'CURRENT',
      'progress': 7,
      'customLists': [
        {'name': 'Rewatch someday', 'enabled': true},
        {'name': 'Comfort shows', 'enabled': false},
      ],
    });
    const order = ['Rewatch someday', 'Comfort shows', 'Empty one'];

    test('reads the lists an entry is on', () {
      expect(EntryDraft.from(ListEntry.fromSaved(saved)).customLists, ['Rewatch someday']);
      expect(EntryDraft.from(entry).customLists, isEmpty);
    });

    test('toggles a list, keeping the account order', () {
      final initial = EntryDraft.from(ListEntry.fromSaved(saved));
      final added = withCustomList(initial, 'Empty one', order);
      expect(added.customLists, ['Rewatch someday', 'Empty one']);
      expect(withCustomList(added, 'Rewatch someday', order).customLists, ['Empty one']);
    });

    test('sends the whole set only when it changed, and it survives the offline queue', () {
      final initial = EntryDraft.from(ListEntry.fromSaved(saved));
      final added = withCustomList(initial, 'Empty one', order);
      final patch = changes(initial, added);
      expect(patch.toJson(), {
        'customLists': ['Rewatch someday', 'Empty one'],
      });
      expect(EntryInput.fromJson(patch.toJson()).customLists, ['Rewatch someday', 'Empty one']);
      expect(isDirty(initial, withCustomList(added, 'Empty one', order)), isFalse);
    });

    test("lists the account's lists, empty ones too, then any only the entry knows", () {
      expect(customListNames(['Comfort shows', 'Empty one'], saved.customLists), [
        'Comfort shows',
        'Empty one',
        'Rewatch someday',
      ]);
      expect(customListNames(const [], null), isEmpty);
    });

    test("reads the account's list names", () {
      final user = AniListUser.fromJson({
        'id': 1,
        'name': 'rin',
        'mediaListOptions': {
          'scoreFormat': 'POINT_10',
          'animeList': {
            'customLists': ['Rewatch someday'],
          },
          'mangaList': {'customLists': null},
        },
      });
      expect(user.customLists(isAnime: true), ['Rewatch someday']);
      expect(user.customLists(isAnime: false), isEmpty);
      // a settings save keeps them
      expect(user.copyWith(scoreFormat: ScoreFormat.point100).customLists(isAnime: true), ['Rewatch someday']);
    });
  });

  group('mergeLoaded', () {
    // what a Home card knows: status and progress only
    const opened = EntryDraft(status: MediaListStatus.current, progress: 7);
    const loaded = EntryDraft(
      status: MediaListStatus.current,
      progress: 7,
      score: 8.5,
      notes: 'Fern!',
      customLists: ['Rewatch someday'],
    );

    test('keeps what was edited before the full entry arrived, and takes the rest', () {
      final merged = mergeLoaded(opened: opened, draft: opened.copyWith(progress: 8), loaded: loaded);
      expect((merged.progress, merged.score, merged.notes), (8, 8.5, 'Fern!'));
      expect(merged.customLists, ['Rewatch someday']);
      // so the next save sends the +1 alone, not the card's blanks
      expect(changes(loaded.copyWith(progress: 8), merged).isEmpty, isTrue);
    });

    test('an untouched draft becomes the loaded entry', () {
      final merged = mergeLoaded(opened: opened, draft: opened, loaded: loaded);
      expect(isDirty(loaded, merged), isFalse);
    });
  });

  test("a saved entry without list data doesn't read as on no lists", () {
    final known = ListEntry.fromSaved(
      AniListSavedEntry.fromJson({
        'id': 7,
        'mediaId': 1,
        'status': 'CURRENT',
        'progress': 7,
        'customLists': [
          {'name': 'Rewatch someday', 'enabled': false},
        ],
      }),
    );
    final unknown = ListEntry.fromSaved(
      AniListSavedEntry.fromJson({'id': 7, 'mediaId': 1, 'status': 'CURRENT', 'progress': 7}),
    );
    expect(known.customLists, isEmpty);
    expect(unknown.customLists, isNull);
    // so an Undo built from it doesn't send an empty set
    expect(unknown.toInput().toJson().containsKey('customLists'), isFalse);
  });
}
