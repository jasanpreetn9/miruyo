// A title's Stats tab: its rankings, how many people have it on each list,
// and how they score it, all from AniList's own counts across every user
// (titleStatsQuery). Ported from apps/web/src/lib/page-data/title-stats.ts.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anilist/types.dart';
import '../../core/catalog/status.dart';
import '../../core/providers.dart';
import 'detail_data.dart' show formatCompact;

class RankingRow {
  const RankingRow({
    required this.key,
    required this.rank,
    required this.label,
    required this.when,
    required this.format,
    required this.href,
  });

  final int key;
  final int rank;

  /// "Highest rated" / "Most popular".
  final String label;

  /// "All time", "2023", "Fall 2023".
  final String when;

  /// "TV": the ranking is among titles of this format.
  final String format;

  /// The same list in Browse, when Browse can show it.
  final String? href;
}

class StatusRow {
  const StatusRow({
    required this.status,
    required this.label,
    required this.count,
    required this.shown,
    required this.percent,
  });

  final MediaListStatus status;
  final String label;
  final int count;

  /// "1.2k".
  final String shown;

  /// Of everyone with it on a list, 0–100, to one decimal.
  final double percent;
}

class ScoreBar {
  const ScoreBar({required this.score, required this.count, required this.height});

  /// 1–10.
  final int score;
  final int count;

  /// Of the tallest bar, 0–100.
  final int height;
}

class TitleStats {
  const TitleStats({
    required this.rankings,
    required this.statuses,
    required this.members,
    required this.scores,
    required this.scored,
    required this.average,
    required this.favourites,
  });

  final List<RankingRow> rankings;
  final List<StatusRow> statuses;

  /// Everyone with it on a list.
  final String members;
  final List<ScoreBar> scores;

  /// "211k".
  final String scored;

  /// "9.1", or null with no average yet.
  final String? average;
  final String? favourites;
}

const _seasons = {'WINTER': 'Winter', 'SPRING': 'Spring', 'SUMMER': 'Summer', 'FALL': 'Fall'};
const _formats = {
  'TV': 'TV',
  'TV_SHORT': 'TV Short',
  'MOVIE': 'Movie',
  'SPECIAL': 'Special',
  'OVA': 'OVA',
  'ONA': 'ONA',
  'MUSIC': 'Music',
  'MANGA': 'Manga',
  'NOVEL': 'Light novel',
  'ONE_SHOT': 'One-shot',
};

/// Browse sorted the same way, narrowed to the same format and (anime only:
/// Browse has no year for manga) the same season and year.
String? _rankingHref(Json r, {required bool isAnime}) {
  final allTime = r['allTime'] == true;
  if (!allTime && !isAnime) return null;
  final format = r['format'] as String?;
  final season = r['season'] as String?;
  final year = (r['year'] as num?)?.toInt();
  final params = [
    if (r['type'] == 'RATED') 'sort=score',
    if (format != null && format.isNotEmpty) 'format=${Uri.encodeQueryComponent(format)}',
    if (!allTime && season != null) 'season=$season',
    if (!allTime && year != null) 'year=$year',
  ];
  return params.isEmpty ? '/browse' : '/browse?${params.join('&')}';
}

TitleStats buildTitleStats(Json media, {required bool isAnime}) {
  final ranked = [for (final r in (media['rankings'] as List? ?? const [])) r as Json];
  int flag(bool b) => b ? 1 : 0;
  // all time first, then the year, then the season; rated before popular
  ranked.sort(
    (a, b) => switch (flag(b['allTime'] == true) - flag(a['allTime'] == true)) {
      0 => switch (flag(a['season'] != null) - flag(b['season'] != null)) {
        0 => flag(a['type'] != 'RATED') - flag(b['type'] != 'RATED'),
        final n => n,
      },
      final n => n,
    },
  );
  final rankings = [
    for (final r in ranked)
      RankingRow(
        key: (r['id'] as num).toInt(),
        rank: (r['rank'] as num).toInt(),
        label: r['type'] == 'RATED' ? 'Highest rated' : 'Most popular',
        when: r['allTime'] == true
            ? 'All time'
            : [
                if (r['season'] != null) _seasons[r['season']] ?? '',
                if (r['year'] != null) '${r['year']}',
              ].where((s) => s.isNotEmpty).join(' '),
        format: _formats[r['format']] ?? (r['format'] as String? ?? ''),
        href: _rankingHref(r, isAnime: isAnime),
      ),
  ];

  final stats = media['stats'] as Json?;
  final byStatus = <MediaListStatus, int>{
    for (final s in (stats?['statusDistribution'] as List? ?? const []))
      MediaListStatus.parse((s as Json)['status']): (s['amount'] as num?)?.toInt() ?? 0,
  };
  final total = byStatus.values.fold(0, (a, n) => a + n);
  final statuses = [
    for (final status in listStatuses)
      if ((byStatus[status] ?? 0) > 0)
        StatusRow(
          status: status,
          label: statusLabel(status, isAnime: isAnime),
          count: byStatus[status]!,
          shown: formatCompact(byStatus[status]),
          percent: total == 0 ? 0 : (byStatus[status]! / total * 1000).round() / 10,
        ),
  ];

  final byScore = <int, int>{
    for (final s in (stats?['scoreDistribution'] as List? ?? const []))
      ((s as Json)['score'] as num).toInt(): (s['amount'] as num?)?.toInt() ?? 0,
  };
  final counts = [for (var i = 1; i <= 10; i++) byScore[i * 10] ?? 0];
  final tallest = counts.fold(0, (m, n) => n > m ? n : m);
  final scores = [
    for (final (i, count) in counts.indexed)
      ScoreBar(
        score: i + 1,
        count: count,
        height: tallest == 0
            ? 0
            : switch ((count / tallest * 100).round()) {
                final h when count > 0 && h < 2 => 2,
                final h => h,
              },
      ),
  ];

  final average = (media['averageScore'] as num?)?.toInt();
  final favourites = (media['favourites'] as num?)?.toInt();
  return TitleStats(
    rankings: rankings,
    statuses: statuses,
    members: formatCompact(total),
    scores: scores,
    scored: formatCompact(counts.fold<int>(0, (a, n) => a + n)),
    average: average == null || average == 0 ? null : (average / 10).toStringAsFixed(1),
    favourites: favourites == null || favourites == 0 ? null : formatCompact(favourites),
  );
}

/// The Stats tab's data, fetched when the tab first opens.
final titleStatsProvider = FutureProvider.autoDispose.family<Json, int>(
  (ref, id) => ref.watch(anilistClientProvider).fetchTitleStats(id),
);
