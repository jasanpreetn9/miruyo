// Ported from apps/web/src/lib/page-data/user.test.ts.

import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/features/list/list_data.dart';
import 'package:miruyo/features/user/user_data.dart';

import '../list/list_data_test.dart' show entry;

const now = 1800000000;

CollectionEntry adult(int id, {String status = 'COMPLETED', double score = 0}) {
  final e = entry(id, status: status, score: score);
  return CollectionEntry(
    entry: e.entry,
    updatedAt: e.updatedAt,
    media: AniListMedia.fromJson({
      'id': id,
      'type': 'ANIME',
      'format': 'TV',
      'isAdult': true,
      'title': {'romaji': 'T$id'},
      'coverImage': <String, Object>{},
    }),
  );
}

void main() {
  group('user list', () {
    final entries = [
      entry(1, romaji: 'A', status: 'COMPLETED', score: 7.5),
      entry(2, romaji: 'B', status: 'COMPLETED', score: 9),
      adult(3, score: 10),
      entry(4, status: 'CURRENT'),
    ];

    test('opens Completed best first, leaving out 18+ titles unless the viewer allows them', () {
      final view = buildUserList(entries, status: MediaListStatus.completed, isAnime: true, adult: false, now: now);
      expect(view.rows.map((r) => (r.id, r.score)), [(2, 9.0), (1, 7.5)]);
      expect(view.tabs.map((t) => (t.status, t.count)), [(MediaListStatus.current, 1), (MediaListStatus.completed, 2)]);
      final all = buildUserList(entries, status: MediaListStatus.completed, isAnime: true, adult: true, now: now);
      expect(all.rows.first.id, 3);
    });

    test('keeps the open status as a tab even when it is empty', () {
      final view = buildUserList(entries, status: MediaListStatus.dropped, isAnime: true, adult: false, now: now);
      expect(view.tabs.map((t) => t.status), [
        MediaListStatus.current,
        MediaListStatus.completed,
        MediaListStatus.dropped,
      ]);
      expect(view.rows, isEmpty);
    });

    test('offers My List’s sorts without “Most to watch”', () {
      expect(userSortsFor(MediaListStatus.current, isAnime: true), isNot(contains(ListSort.toWatch)));
      expect(defaultUserSort(MediaListStatus.completed), ListSort.score);
      expect(defaultUserSort(MediaListStatus.current), ListSort.updated);
    });
  });

  group('names', () {
    test('makes possessives', () {
      expect(possessive('matchai'), 'matchai’s');
      expect(possessive('Ines'), 'Ines’');
    });

    test('knows your own profile whatever the case', () {
      expect(isOwnProfile('Matchai', 'matchai'), isTrue);
      expect(isOwnProfile('matchai', null), isFalse);
      expect(isOwnProfile('matchai', 'haruka'), isFalse);
    });
  });

  test('forViewer leaves 18+ titles out unless the viewer shows them', () {
    final safe = entry(1);
    expect(forViewer([safe, adult(2)], adult: false).map((e) => e.entry.mediaId), [1]);
    expect(forViewer([safe, adult(2)], adult: true).map((e) => e.entry.mediaId), [1, 2]);
  });

  test("filters by AniList's genre, country and year, and offers what's on the list", () {
    final list = [
      entry(
        1,
        status: 'COMPLETED',
        media: {
          'genres': ['Action'],
          'countryOfOrigin': 'JP',
          'seasonYear': 2026,
        },
      ),
      entry(
        2,
        status: 'COMPLETED',
        media: {
          'genres': ['Drama'],
          'countryOfOrigin': 'KR',
          'seasonYear': 2024,
        },
      ),
      // a manga's year is its start date's
      entry(
        3,
        type: 'MANGA',
        format: 'MANGA',
        status: 'COMPLETED',
        media: {
          'genres': ['Drama', 'Romance'],
          'startDate': {'year': 2019},
        },
      ),
    ];
    List<int> ids({String genre = '', String country = '', int? year}) => buildUserList(
      list,
      status: MediaListStatus.completed,
      isAnime: true,
      adult: false,
      now: now,
      genre: genre,
      country: country,
      year: year,
    ).rows.map((r) => r.id).toList()..sort();
    expect(ids(), [1, 2, 3]);
    expect(ids(genre: 'Drama'), [2, 3]);
    expect(ids(country: 'KR'), [2]);
    expect(ids(year: 2019), [3]);
    expect(ids(genre: 'Drama', year: 2024), [2]);
    expect(ids(genre: 'Action', country: 'KR'), isEmpty);

    final view = buildUserList(list, status: MediaListStatus.completed, isAnime: true, adult: false, now: now);
    expect(view.genres, ['Action', 'Drama', 'Romance']);
    expect(view.countries, ['JP', 'KR']);
    expect(view.years, [2026, 2024, 2019]);
  });

  test('names countries as AniList does', () {
    expect(['JP', 'KR', 'CN', 'TW', 'FR'].map(countryName), ['Japan', 'South Korea', 'China', 'Taiwan', 'FR']);
  });
}
