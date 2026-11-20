// Ported from apps/web/src/lib/page-data/title-stats.test.ts.

import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/features/detail/title_stats.dart';

Json ranking(
  int id, {
  String type = 'RATED',
  String format = 'TV',
  int? year,
  String? season,
  bool allTime = false,
  int rank = 1,
}) => {
  'id': id,
  'rank': rank,
  'type': type,
  'format': format,
  'year': year,
  'season': season,
  'allTime': allTime,
  'context': '',
};

Json media({
  Object? averageScore = 91,
  Object? favourites = 12345,
  Object? stats = const <String, Object>{'scoreDistribution': [], 'statusDistribution': []},
  Object? rankings = const <Json>[],
}) => {'id': 1, 'averageScore': averageScore, 'favourites': favourites, 'stats': stats, 'rankings': rankings};

void main() {
  test('puts all-time rankings first, then the year, then the season, rated before popular', () {
    final rankings = buildTitleStats(
      media(
        rankings: [
          ranking(1, type: 'POPULAR', season: 'FALL', year: 2023),
          ranking(2, type: 'POPULAR', year: 2023),
          ranking(3, season: 'FALL', year: 2023),
          ranking(4, type: 'POPULAR', allTime: true, rank: 50),
          ranking(5, year: 2023),
          ranking(6, allTime: true),
        ],
      ),
      isAnime: true,
    ).rankings;
    expect(rankings.map((r) => r.key), [6, 4, 5, 2, 3, 1]);
    expect(rankings.map((r) => '${r.label} · ${r.when} · ${r.format}'), [
      'Highest rated · All time · TV',
      'Most popular · All time · TV',
      'Highest rated · 2023 · TV',
      'Most popular · 2023 · TV',
      'Highest rated · Fall 2023 · TV',
      'Most popular · Fall 2023 · TV',
    ]);
  });

  test('links each ranking to the same list in Browse', () {
    final rankings = buildTitleStats(
      media(
        rankings: [
          ranking(1, allTime: true, format: 'MOVIE'),
          ranking(2, type: 'POPULAR', allTime: true),
          ranking(3, season: 'FALL', year: 2023),
        ],
      ),
      isAnime: true,
    ).rankings;
    expect(rankings.map((r) => r.href), [
      '/browse?sort=score&format=MOVIE',
      '/browse?format=TV',
      '/browse?sort=score&format=TV&season=FALL&year=2023',
    ]);
    expect(rankings.first.format, 'Movie');
  });

  test("doesn't link a manga's yearly ranking, since Browse has no year for manga", () {
    final rankings = buildTitleStats(
      media(
        rankings: [
          ranking(1, allTime: true, format: 'MANGA'),
          ranking(2, year: 2020, format: 'MANGA'),
        ],
      ),
      isAnime: false,
    ).rankings;
    expect(rankings.map((r) => r.href), ['/browse?sort=score&format=MANGA', null]);
  });

  test('counts each list in list order, with its share of everyone', () {
    final view = buildTitleStats(
      media(
        stats: {
          'scoreDistribution': <Json>[],
          'statusDistribution': [
            {'status': 'PLANNING', 'amount': 1000},
            {'status': 'DROPPED', 'amount': 0},
            {'status': 'CURRENT', 'amount': 3000},
            {'status': 'COMPLETED', 'amount': 6000},
          ],
        },
      ),
      isAnime: false,
    );
    expect(view.statuses.map((s) => (s.status, s.label, s.count, s.shown, s.percent)), [
      (MediaListStatus.current, 'Reading', 3000, '3k', 30.0),
      (MediaListStatus.completed, 'Completed', 6000, '6k', 60.0),
      (MediaListStatus.planning, 'Planning', 1000, '1k', 10.0),
    ]);
    expect(view.members, '10k');
  });

  test('draws ten score bars against the tallest, keeping small ones visible', () {
    final view = buildTitleStats(
      media(
        stats: {
          'statusDistribution': <Json>[],
          'scoreDistribution': [
            {'score': 100, 'amount': 10000},
            {'score': 90, 'amount': 5000},
            {'score': 10, 'amount': 1},
          ],
        },
      ),
      isAnime: true,
    );
    expect(view.scores.map((b) => b.score), [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
    expect(view.scores.map((b) => b.height), [2, 0, 0, 0, 0, 0, 0, 0, 50, 100]);
    expect(view.scored, '15k');
    expect(view.average, '9.1');
    expect(view.favourites, '12k');
  });

  test('copes with a title nobody has rated or listed yet', () {
    final view = buildTitleStats(media(averageScore: null, favourites: 0, stats: null, rankings: null), isAnime: true);
    expect(view.rankings, isEmpty);
    expect(view.statuses, isEmpty);
    expect(view.scores.every((b) => b.count == 0 && b.height == 0), isTrue);
    expect(view.average, isNull);
    expect(view.favourites, isNull);
  });
}
