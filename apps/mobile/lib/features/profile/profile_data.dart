// Profile and Stats (07, 18), ported from apps/web/src/lib/page-data/
// profile.ts (buildProfile) and stats.ts (buildStats, buildHeatmap). Stats
// are computed from the list collection rather than AniList's
// User.statistics, whose breakdowns are often stale or empty, and a list can
// be filtered by time.

import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anilist/types.dart';
import '../../core/catalog/humanize.dart';
import '../../core/catalog/score.dart';
import '../../core/catalog/season.dart';
import '../../core/catalog/status.dart';
import '../../core/catalog/title.dart';
import '../../core/providers.dart';

// ── Profile ──

/// An AniList page link from the API (siteUrl), or [fallback] when it isn't
/// an https anilist.co URL: it's opened outside the app, so an unexpected
/// value (another scheme, a malformed URL) never becomes a link.
Uri? anilistLink(String? url, [String? fallback]) {
  final uri = url == null ? null : Uri.tryParse(url);
  if (uri != null && uri.scheme == 'https' && uri.host == 'anilist.co') return uri;
  return fallback == null ? null : Uri.parse(fallback);
}

/// A favourite character or staff member, opening their page in miruyo.
class ProfilePerson {
  const ProfilePerson({required this.id, required this.name, required this.image, required this.href});

  final int id;
  final String name;
  final String? image;

  /// "/character/12", "/staff/34".
  final String href;
}

class ProfileView {
  const ProfileView({
    required this.memberSince,
    required this.anilist,
    required this.anime,
    required this.manga,
    required this.titlesError,
    required this.characters,
    required this.staff,
    required this.studios,
  });

  /// "Member since March 2019", or null when AniList doesn't say.
  final String? memberSince;

  /// The viewer's page on AniList.
  final Uri? anilist;
  final List<Title> anime;
  final List<Title> manga;

  /// Why the favourite titles didn't load; the rest of the profile still shows.
  final String? titlesError;
  final List<ProfilePerson> characters;
  final List<ProfilePerson> staff;

  /// Each opens its miruyo page.
  final List<({String name, String href})> studios;
}

const _monthNames = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Someone's profile (yours or anyone's) as AniList sends it, with their
/// favourite titles filled in.
typedef ProfileData = ({Json account, List<AniListMedia>? anime, List<AniListMedia>? manga, String? titlesError});

ProfileView buildProfile(ProfileData profile, {required bool showAdult}) {
  final viewer = profile.account;
  final fav = viewer['favourites'] as Json?;
  // each id once, the first kept: AniList can list a favourite twice
  List<Title> media(List<AniListMedia>? list) {
    final seen = <int>{};
    return [
      for (final m in list ?? const <AniListMedia>[])
        if ((showAdult || !m.isAdult) && seen.add(m.id)) adaptMedia(m),
    ];
  }

  List<Json> nodes(String key) {
    final seen = <Object?>{};
    return [
      for (final n in ((((fav?[key] as Json?)?['nodes']) as List?) ?? const []).whereType<Json>())
        if (seen.add(n['id'])) n,
    ];
  }

  ProfilePerson person(Json p, String kind) {
    final id = (p['id'] as num).toInt();
    final image = p['image'] as Json?;
    return ProfilePerson(
      id: id,
      name: (p['name'] as Json?)?['userPreferred'] as String? ?? 'Unknown',
      image: image?['large'] as String? ?? image?['medium'] as String?,
      href: '/$kind/$id',
    );
  }

  final createdAt = (viewer['createdAt'] as num?)?.toInt();
  final since = createdAt == null ? null : DateTime.fromMillisecondsSinceEpoch(createdAt * 1000);
  final site = viewer['siteUrl'] as String?;
  return ProfileView(
    memberSince: since == null ? null : 'Member since ${_monthNames[since.month - 1]} ${since.year}',
    anilist: anilistLink(site),
    anime: media(profile.anime),
    manga: media(profile.manga),
    titlesError: profile.titlesError,
    characters: [for (final c in nodes('characters')) person(c, 'character')],
    staff: [for (final c in nodes('staff')) person(c, 'staff')],
    studios: [for (final s in nodes('studios')) (name: s['name'] as String? ?? '', href: '/studio/${s['id']}')],
  );
}

// ── Stats ──

enum StatsRange {
  all,
  year,
  twelveMonths;

  String label(DateTime now) => switch (this) {
    all => 'All time',
    year => '${now.year}',
    twelveMonths => 'Last 12 months',
  };

  /// Start of the range, or null for all time.
  DateTime? start(DateTime now) => switch (this) {
    all => null,
    year => DateTime(now.year),
    twelveMonths => DateTime(now.year - 1, now.month, now.day),
  };
}

/// Which colour a mark takes: the mode accent, a softer accent, or a neutral.
enum Tone { accent, accentSoft, ink, dim, mute }

class StatCard {
  const StatCard({required this.label, required this.value, required this.detail, this.positive = false});

  final String label;
  final String value;
  final String detail;

  /// Good news (green) vs. plain context.
  final bool positive;
}

class Bar {
  const Bar({required this.label, required this.name, required this.count, required this.tone});

  /// Under the bar: "8", or a month's letter.
  final String label;

  /// The readout while scrubbing: "Score 8", "October 2026".
  final String name;
  final int count;
  final Tone tone;
}

class Slice {
  const Slice({required this.label, required this.count, required this.share, required this.tone});

  final String label;
  final int count;

  /// 0–1 of the total.
  final double share;
  final Tone tone;
}

class GenreRow {
  const GenreRow({
    required this.genre,
    required this.count,
    required this.mean,
    required this.width,
    required this.tone,
  });

  final String genre;
  final int count;

  /// Mean of your scores in this genre, 10-point; null when none are scored.
  final double? mean;

  /// 0–1, relative to the top genre.
  final double width;
  final Tone tone;
}

class Stats {
  const Stats({
    required this.total,
    required this.cards,
    required this.mean,
    required this.deviation,
    required this.scored,
    required this.scores,
    required this.formats,
    required this.statuses,
    required this.genres,
    required this.months,
  });

  final int total;
  final List<StatCard> cards;

  /// 10-point; null when nothing in range is scored.
  final double? mean;
  final double? deviation;
  final int scored;
  final List<Bar> scores;
  final List<Slice> formats;
  final List<({MediaListStatus status, String label, int count})> statuses;
  final List<GenreRow> genres;

  /// Titles finished per month, oldest first, ending with the current month.
  final List<Bar> months;
}

DateTime? _date(AniListDate d) => d.year == null ? null : DateTime(d.year!, d.month ?? 1, d.day ?? 1);

/// You started or finished it in the range; with neither date, when it was
/// last updated.
bool _inRange(CollectionEntry c, DateTime? start) {
  if (start == null) return true;
  final dates = [_date(c.entry.startedAt), _date(c.entry.completedAt)].whereType<DateTime>();
  if (dates.isEmpty) return c.updatedAt * 1000 >= start.millisecondsSinceEpoch;
  return dates.any((d) => !d.isBefore(start));
}

/// A score on AniList's 10-point axis (0 = unscored).
double toTenPoint(double score, [ScoreFormat? format]) => score == 0 ? 0 : score / scoreScale(format).max * 10;

/// Episodes (or chapters) consumed, counting each rewatch as a full run.
int _units(CollectionEntry c, bool isAnime) {
  final e = c.entry;
  final total = (isAnime ? c.media.episodes : c.media.chapters) ?? e.progress;
  return e.progress + e.repeat * total;
}

int _volumes(CollectionEntry c) {
  final read = c.entry.progressVolumes ?? 0;
  return read + c.entry.repeat * (c.media.volumes ?? read);
}

const _formatTones = [Tone.accent, Tone.ink, Tone.dim, Tone.mute];
const _maxFormats = 4;
const _maxGenres = 7;

/// Finished first, then what's moving.
const _statusOrder = [
  MediaListStatus.completed,
  MediaListStatus.current,
  MediaListStatus.repeating,
  MediaListStatus.planning,
  MediaListStatus.paused,
  MediaListStatus.dropped,
];

const _monthLetters = ['J', 'F', 'M', 'A', 'M', 'J', 'J', 'A', 'S', 'O', 'N', 'D'];

String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

Stats buildStats(
  List<CollectionEntry> entries, {
  required bool isAnime,
  required StatsRange range,
  required DateTime now,
  ScoreFormat? scoreFormat,
}) {
  final start = range.start(now);
  final shown = [
    for (final c in entries)
      if (_inRange(c, start)) c,
  ];

  // ── Scores ──
  final scored = [
    for (final c in shown)
      if (toTenPoint(c.entry.score, scoreFormat) > 0) toTenPoint(c.entry.score, scoreFormat),
  ];
  final mean = scored.isEmpty ? null : scored.reduce((a, b) => a + b) / scored.length;
  final deviation = mean == null
      ? null
      : math.sqrt(scored.fold(0.0, (a, s) => a + (s - mean) * (s - mean)) / scored.length);
  final buckets = List.filled(10, 0);
  for (final s in scored) {
    buckets[s.round().clamp(1, 10) - 1]++;
  }
  final scores = [
    for (var i = 0; i < 10; i++)
      Bar(label: '${i + 1}', name: 'Score ${i + 1}', count: buckets[i], tone: i + 1 >= 7 ? Tone.accent : Tone.mute),
  ];

  // ── Formats ──
  final formatCounts = <String, int>{};
  for (final c in shown) {
    final label = humanizeFormat(c.media.format);
    formatCounts[label] = (formatCounts[label] ?? 0) + 1;
  }
  var formatList = formatCounts.entries.map((e) => (e.key, e.value)).toList()..sort((a, b) => b.$2.compareTo(a.$2));
  if (formatList.length > _maxFormats) {
    final rest = formatList.skip(_maxFormats - 1).fold(0, (a, f) => a + f.$2);
    formatList = [...formatList.take(_maxFormats - 1), ('Other', rest)];
  }
  final formats = [
    for (final (i, (label, count)) in formatList.indexed)
      Slice(label: label, count: count, share: shown.isEmpty ? 0 : count / shown.length, tone: _formatTones[i]),
  ];

  // ── Statuses ──
  final statusCounts = <MediaListStatus, int>{};
  for (final c in shown) {
    statusCounts[c.entry.status] = (statusCounts[c.entry.status] ?? 0) + 1;
  }
  final statuses = [
    for (final s in _statusOrder)
      if ((statusCounts[s] ?? 0) > 0) (status: s, label: statusLabel(s, isAnime: isAnime), count: statusCounts[s]!),
  ];

  // ── Genres ──
  final genreStats = <String, ({int count, double sum, int scored})>{};
  for (final c in shown) {
    final s = toTenPoint(c.entry.score, scoreFormat);
    for (final genre in c.media.genres) {
      final g = genreStats[genre] ?? (count: 0, sum: 0.0, scored: 0);
      genreStats[genre] = (count: g.count + 1, sum: g.sum + s, scored: g.scored + (s > 0 ? 1 : 0));
    }
  }
  final topGenres = genreStats.entries.toList()
    ..sort((a, b) => b.value.count != a.value.count ? b.value.count.compareTo(a.value.count) : a.key.compareTo(b.key));
  final top = topGenres.take(_maxGenres).toList();
  final topCount = top.isEmpty ? 1 : top.first.value.count;
  final genres = [
    for (final (i, MapEntry(key: genre, value: g)) in top.indexed)
      GenreRow(
        genre: genre,
        count: g.count,
        mean: g.scored > 0 ? g.sum / g.scored : null,
        width: g.count / topCount,
        tone: i == 0 ? Tone.accent : Tone.accentSoft,
      ),
  ];

  // ── Finished per month (last 12, whatever the range) ──
  final monthCounts = List.filled(12, 0);
  final firstMonth = DateTime(now.year, now.month - 11);
  for (final c in entries) {
    final done = _date(c.entry.completedAt);
    if (done == null || done.isBefore(firstMonth) || done.isAfter(now)) continue;
    final i = (done.year - firstMonth.year) * 12 + done.month - firstMonth.month;
    if (i >= 0 && i < 12) monthCounts[i]++;
  }
  final months = [
    for (var i = 0; i < 12; i++)
      () {
        final d = DateTime(now.year, now.month - 11 + i);
        return Bar(
          label: _monthLetters[d.month - 1],
          name: '${_monthNames[d.month - 1]} ${d.year}',
          count: monthCounts[i],
          // every month with something finished in the accent; empty ones stay quiet
          tone: monthCounts[i] > 0 ? Tone.accent : Tone.mute,
        );
      }(),
  ];

  // ── Cards ──
  final season = currentSeason(now);
  final finishedThisSeason = entries.where((c) {
    final done = _date(c.entry.completedAt);
    if (done == null || done.isAfter(now)) return false;
    return currentSeason(done) == season;
  }).length;

  final units = shown.fold(0, (a, c) => a + _units(c, isAnime));
  final perWeek = _unitsPerWeek(shown, units, start, now);
  final siteScores = [
    for (final c in shown)
      if (c.entry.score > 0 && c.media.averageScore != null) c.media.averageScore! / 10,
  ];
  final siteMean = siteScores.isEmpty ? null : siteScores.reduce((a, b) => a + b) / siteScores.length;

  final third = isAnime
      ? () {
          final minutes = shown.fold(0, (a, c) => a + _units(c, true) * (c.media.duration ?? 0));
          return StatCard(
            label: 'Days watched',
            value: (minutes / 1440).toStringAsFixed(1),
            detail: '${_thousands((minutes / 60).round())} hours',
          );
        }()
      : () {
          final volumes = shown.fold(0, (a, c) => a + _volumes(c));
          final series = shown.where((c) => (c.entry.progressVolumes ?? 0) > 0).length;
          return StatCard(
            label: 'Volumes read',
            value: _thousands(volumes),
            detail: series > 0 ? 'Across ${_thousands(series)} series' : 'No volumes tracked',
          );
        }();

  return Stats(
    total: shown.length,
    cards: [
      StatCard(
        label: isAnime ? 'Total anime' : 'Total manga',
        value: _thousands(shown.length),
        detail: finishedThisSeason > 0 ? '+$finishedThisSeason finished this season' : 'None finished this season',
        positive: finishedThisSeason > 0,
      ),
      StatCard(
        label: isAnime ? 'Episodes watched' : 'Chapters read',
        value: _thousands(units),
        detail: perWeek == null ? '' : '≈ ${_thousands(perWeek)} per week',
      ),
      third,
      StatCard(
        label: 'Mean score',
        value: mean == null ? '—' : mean.toStringAsFixed(1),
        detail: siteMean == null ? 'Nothing scored yet' : 'AniList mean ${siteMean.toStringAsFixed(1)}',
      ),
    ],
    mean: mean,
    deviation: deviation,
    scored: scored.length,
    scores: scores,
    formats: formats,
    statuses: statuses,
    genres: genres,
    months: months,
  );
}

/// Average per week across the range (for all time, since the earliest
/// date on the list). Null when there's no span to average over.
int? _unitsPerWeek(List<CollectionEntry> entries, int units, DateTime? start, DateTime now) {
  var from = start;
  if (from == null) {
    final times = [
      for (final c in entries) ...[_date(c.entry.startedAt), _date(c.entry.completedAt)],
    ].whereType<DateTime>();
    if (times.isEmpty) return null;
    from = times.reduce((a, b) => a.isBefore(b) ? a : b);
  }
  final weeks = now.difference(from).inHours / (24 * 7);
  if (weeks < 1) return null;
  return (units / weeks).round();
}

// ── Daily activity heatmap ──

const heatmapWeeks = 26;

class HeatCell {
  const HeatCell({required this.date, required this.amount, required this.level});

  /// "Oct 3", for the readout.
  final String date;
  final int amount;

  /// 0 = nothing, 1–4 = quartiles of active days.
  final int level;
}

const _shortMonths = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// The last 26 weeks as columns of Monday → Sunday, ending this week; days
/// after today are null. [history] is AniList's activityHistory: one entry
/// per active day, dated at the start of that day.
List<List<HeatCell?>> buildHeatmap(List<({int date, int amount, int level})> history, DateTime now) {
  // AniList dates days at midnight in the account's timezone; reading them
  // at noon keeps them on the right calendar day here
  String key(DateTime d) => '${d.year}-${d.month}-${d.day}';
  final byDay = <String, int>{};
  for (final h in history) {
    final k = key(DateTime.fromMillisecondsSinceEpoch(h.date * 1000 + 12 * 3600 * 1000));
    byDay[k] = (byDay[k] ?? 0) + h.amount;
  }

  final today = DateTime(now.year, now.month, now.day);
  final weekday = today.weekday - 1; // Monday = 0
  final first = DateTime(today.year, today.month, today.day - weekday - (heatmapWeeks - 1) * 7);

  final amounts = <int>[];
  final raw = <List<(DateTime, int)?>>[];
  for (var w = 0; w < heatmapWeeks; w++) {
    final column = <(DateTime, int)?>[];
    for (var d = 0; d < 7; d++) {
      final day = DateTime(first.year, first.month, first.day + w * 7 + d);
      if (day.isAfter(today)) {
        column.add(null);
        continue;
      }
      final amount = byDay[key(day)] ?? 0;
      if (amount > 0) amounts.add(amount);
      column.add((day, amount));
    }
    raw.add(column);
  }

  // levels by quartile of the active days, so one huge import day doesn't
  // flatten the rest
  amounts.sort();
  int cut(double q) => amounts[((amounts.length - 1) * q).floor()];
  final thresholds = amounts.isEmpty ? <int>[] : [cut(0.25), cut(0.5), cut(0.75)];
  return [
    for (final column in raw)
      [
        for (final cell in column)
          cell == null
              ? null
              : HeatCell(
                  date: '${_shortMonths[cell.$1.month - 1]} ${cell.$1.day}',
                  amount: cell.$2,
                  level: cell.$2 == 0 ? 0 : 1 + thresholds.where((t) => cell.$2 > t).length,
                ),
      ],
  ];
}

// ── Providers ──

/// Someone's daily list activity (about six months), for the heatmap.
final activityProvider = FutureProvider.autoDispose.family<List<List<HeatCell?>>, int>((ref, userId) async {
  ref.cacheFor(screenCache);
  final history = await ref.watch(anilistClientProvider).fetchActivityHistory(userId);
  return buildHeatmap(history, DateTime.now());
});
