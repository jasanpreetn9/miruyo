import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/list/list_entry.dart';
import 'package:miruyo/core/list/list_store.dart';
import 'package:miruyo/core/theme/tokens.dart';
import 'package:miruyo/features/list/list_data.dart';

const now = 1800000000;
const hour = 3600;
const day = 86400;

CollectionEntry entry(
  int id, {
  String type = 'ANIME',
  String format = 'TV',
  String? english,
  String? romaji,
  Json? next,
  String status = 'CURRENT',
  int progress = 0,
  double score = 0,
  int priority = 0,
  int updatedAt = now,
  Json? completedAt,

  /// More media fields (genres, countryOfOrigin, seasonYear, startDate…).
  Json media = const {},
}) => CollectionEntry.fromJson({
  'id': id * 10,
  'mediaId': id,
  'status': status,
  'progress': progress,
  'score': score,
  'priority': priority,
  'updatedAt': updatedAt,
  'completedAt': ?completedAt,
  'media': {
    'id': id,
    'type': type,
    'format': format,
    'episodes': 24,
    'title': {'romaji': romaji ?? 'T$id', 'english': english, 'userPreferred': romaji ?? 'T$id'},
    'coverImage': <String, Object>{},
    'nextAiringEpisode': ?next,
    ...media,
  },
});

ListRow row(int id, int priority) => ListRow(
  title: buildListView([entry(id)], tab: MediaListStatus.current, isAnime: true, now: now).rows.single.title,
  status: MediaListStatus.planning,
  progress: 0,
  score: 0,
  priority: priority,
  updatedAt: 0,
  note: '',
  noteColor: TextTone.low,
);

void main() {
  group('buildListView', () {
    final watching = entry(
      1,
      romaji: 'Frieren',
      next: {'episode': 9, 'airingAt': now + 2 * day + 4 * hour, 'timeUntilAiring': 0},
      progress: 6,
      updatedAt: now - hour,
      score: 9.5,
    );
    final caughtUp = entry(
      2,
      romaji: 'Apothecary',
      english: 'The Apothecary Diaries',
      format: 'MOVIE',
      next: {'episode': 13, 'airingAt': now + 19 * hour, 'timeUntilAiring': 0},
      progress: 12,
      updatedAt: now - 3 * day,
      score: 8,
    );
    final done = entry(3, status: 'COMPLETED', progress: 24);
    final planned = entry(4, status: 'PLANNING');
    final entries = [caughtUp, watching, done, planned];

    test('counts every tab and shows the current one, newest first', () {
      final view = buildListView(entries, tab: MediaListStatus.current, isAnime: true, now: now);
      expect(view.tabs.map((t) => (t.label, t.count)), [
        ('Watching', 2),
        ('Completed', 1),
        ('Planning', 1),
        ('Paused', 0),
        ('Dropped', 0),
        ('Rewatching', 0),
      ]);
      expect(view.rows.map((r) => r.id), [1, 2]);
    });

    test('gives watching rows airing context', () {
      final [behind, upToDate] = buildListView(entries, tab: MediaListStatus.current, isAnime: true, now: now).rows;
      expect((behind.note, behind.noteColor), ('2 new · EP 9 in 2d 4h', Accent.green));
      expect((upToDate.note, upToDate.noteColor), ('Caught up · EP 13 in 19h 00m', Accent.soraText));
    });

    test('filters by text (either title) and format, and sorts', () {
      List<int> ids({String filter = '', String format = '', ListSort? sort}) => buildListView(
        entries,
        tab: MediaListStatus.current,
        isAnime: true,
        now: now,
        filter: filter,
        format: format,
        sort: sort,
      ).rows.map((r) => r.id).toList();
      expect(ids(filter: 'diaries'), [2]);
      expect(ids(format: 'Movie'), [2]);
      expect(ids(sort: ListSort.title), [2, 1]);
      expect(ids(sort: ListSort.airing), [2, 1]);
      expect(ids(sort: ListSort.score), [1, 2]);
      expect(buildListView(entries, tab: MediaListStatus.current, isAnime: true, now: now).formats, ['Movie', 'TV']);
    });

    test('applies local edits: a completed row moves tabs, a removed one disappears', () {
      final live = const ListState().copyWith(
        entries: {1: const ListEntry(mediaId: 1, status: MediaListStatus.completed, progress: 24)},
        removed: {3},
      );
      final view = buildListView(entries, tab: MediaListStatus.completed, isAnime: true, now: now, live: live);
      expect(view.rows.map((r) => r.id), [1]);
      expect(view.tabs.first.count, 1);
    });

    test('a custom list holds its titles whatever their status, each saying which', () {
      final view = buildListView(entries, tab: MediaListStatus.current, only: {3, 4}, isAnime: true, now: now);
      expect(view.rows.map((r) => r.id).toList()..sort(), [3, 4]);
      expect(view.rows.firstWhere((r) => r.id == 4).note, startsWith('Planning · '));
    });

    test('titles hidden from status lists stay off the status tabs', () {
      final view = buildListView(entries, tab: MediaListStatus.current, hidden: {1}, isAnime: true, now: now);
      expect(view.rows.map((r) => r.id), [2]);
      expect((view.tabs.first.label, view.tabs.first.count), ('Watching', 1));
      // still on its custom list
      final custom = buildListView(
        entries,
        tab: MediaListStatus.current,
        only: {1},
        hidden: {1},
        isAnime: true,
        now: now,
      );
      expect(custom.rows.map((r) => r.id), [1]);
    });

    test('summarizes anime by episodes and days, manga by chapters and mean score', () {
      final anime = buildListView([watching, caughtUp], tab: MediaListStatus.current, isAnime: true, now: now);
      // (6 + 12) × 24 min = 432 min = 0.3 days
      expect(anime.summary, '2 titles · 18 episodes · 0.3 days watched');

      final manga = buildListView(
        [
          entry(5, type: 'MANGA', format: 'MANGA', progress: 100, score: 9),
          entry(6, type: 'MANGA', format: 'MANGA', progress: 20, score: 8),
        ],
        tab: MediaListStatus.current,
        isAnime: false,
        now: now,
      );
      expect(manga.summary, '2 titles · 120 chapters · mean score 8.5');
      expect(manga.tabs.first.label, 'Reading');
    });

    test('Planning defaults to Up next: highest priority first, numbered', () {
      final view = buildListView(
        [
          entry(7, status: 'PLANNING', updatedAt: now - day),
          entry(8, status: 'PLANNING', priority: 3),
          entry(9, status: 'PLANNING', updatedAt: now),
        ],
        tab: MediaListStatus.planning,
        isAnime: true,
        now: now,
      );
      expect(view.rows.map((r) => r.id), [8, 9, 7]);
      expect(view.rows.map((r) => r.note.split(' · ').first), ['Up next #1', 'Up next #2', 'Up next #3']);
      expect(ListSort.on(MediaListStatus.planning, isAnime: true).first, ListSort.upNext);
      expect(ListSort.on(MediaListStatus.current, isAnime: true), isNot(contains(ListSort.upNext)));
    });

    test('a reorder shows at once through the list store', () {
      final planning = [entry(7, status: 'PLANNING'), entry(8, status: 'PLANNING', priority: 1)];
      final live = const ListState().copyWith(
        entries: {7: const ListEntry(mediaId: 7, status: MediaListStatus.planning, progress: 0, priority: 2)},
      );
      final view = buildListView(planning, tab: MediaListStatus.planning, isAnime: true, now: now, live: live);
      expect(view.rows.map((r) => r.id), [7, 8]);
    });
  });

  test('relativeTime reads like the design', () {
    expect(relativeTime(now - 10, now), 'Just now');
    expect(relativeTime(now - 12 * 60, now), '12m ago');
    expect(relativeTime(now - 2 * hour, now), '2h ago');
    expect(relativeTime(now - 30 * hour, now), 'Yesterday');
    expect(relativeTime(now - 3 * day, now), '3d ago');
  });

  test('reading rows say when you last updated them, or a hiatus', () {
    final view = buildListView(
      [
        entry(1, type: 'MANGA', format: 'MANGA', progress: 5, updatedAt: now - 3 * day),
        entry(2, type: 'MANGA', format: 'MANGA', progress: 5, updatedAt: now - 10),
      ],
      tab: MediaListStatus.current,
      isAnime: false,
      now: now,
    );
    expect(view.rows.map((r) => r.note), ['Updated just now', 'Updated 3d ago']);
  });

  group('upNextPriorities', () {
    test('moving to the top of an unordered list saves one entry', () {
      // [A0, B0, C0], C dragged to the top
      expect(upNextPriorities([row(3, 0), row(1, 0), row(2, 0)], 0), {3: 1});
    });

    test('a row that fits between its neighbours changes alone', () {
      // [A9, B5, C1]: C dragged between A and B
      expect(upNextPriorities([row(1, 9), row(3, 1), row(2, 5)], 1), {3: 6});
      // already in a valid spot: nothing to save
      expect(upNextPriorities([row(1, 9), row(3, 6), row(2, 5)], 1), isEmpty);
    });

    test('without room, the rows above are raised only as far as needed', () {
      // [B0, C0, A0]: A dragged to the bottom of an unordered list
      expect(upNextPriorities([row(2, 0), row(3, 0), row(1, 0)], 2), {2: 2, 3: 1});
      // [X9, B3, A3, C3]: A dropped below B; X already clears everything
      expect(upNextPriorities([row(9, 9), row(2, 3), row(1, 3), row(3, 3)], 2), {2: 5, 1: 4});
    });

    test('every result sorts into the dragged order', () {
      final start = [row(1, 4), row(2, 4), row(3, 2), row(4, 0), row(5, 0)];
      for (var from = 0; from < start.length; from++) {
        for (var to = 0; to < start.length; to++) {
          final order = [...start];
          order.insert(to, order.removeAt(from));
          final changes = upNextPriorities(order, to);
          final priorities = [for (final r in order) changes[r.id] ?? r.priority];
          // strictly descending around the moved row, never increasing anywhere
          for (var i = 0; i + 1 < priorities.length; i++) {
            expect(priorities[i] >= priorities[i + 1], isTrue, reason: 'from $from to $to: $priorities');
          }
          if (to > 0) expect(priorities[to - 1] > priorities[to], isTrue, reason: 'from $from to $to: $priorities');
          if (to + 1 < order.length) {
            expect(priorities[to] > priorities[to + 1], isTrue, reason: 'from $from to $to: $priorities');
          }
        }
      }
    });
  });
}
