// The season chart and the week's schedule, ported from
// apps/web/src/lib/page-data/season-chart.ts and seasonal.ts.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/humanize.dart';
import '../../core/catalog/season.dart';
import '../../core/catalog/title.dart';
import '../../core/list/list_entry.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _longMonths = [
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

SeasonYear shiftSeason(SeasonYear s, int by) {
  final index = s.year * 4 + MediaSeason.values.indexOf(s.season) + by;
  return (season: MediaSeason.values[index % 4], year: index ~/ 4);
}

/// The season tabs: the one before, the shown one and the two after.
List<SeasonYear> seasonWindow(SeasonYear shown) => [
  for (final by in [-1, 0, 1, 2]) shiftSeason(shown, by),
];

/// The first year with a chart: AniList has next to nothing before it.
const firstChartYear = 1940;

/// How many years past this one have a chart: little is announced further out.
const _yearsAhead = 2;

/// Whether a season has a chart. Past the range there's nothing to show, and
/// far enough out its airing week overflows AniList's 32-bit timestamps.
bool hasChart(SeasonYear s, DateTime now) => s.year >= firstChartYear && s.year <= now.year + _yearsAhead;

/// `?season=FALL&year=2026`; anything missing, invalid or without a chart
/// means the current season (null here, so the caller picks it).
SeasonYear? parseSeasonQuery(Map<String, String> query, DateTime now) {
  final season = MediaSeason.parse(query['season']?.toUpperCase());
  final year = int.tryParse(query['year'] ?? '');
  if (season == null || year == null) return null;
  final ref = (season: season, year: year);
  return hasChart(ref, now) ? ref : null;
}

String seasonName(SeasonYear s) => '${humanizeSeason(s.season)} ${s.year}';

/// AniChart's countdown: "1 day, 6 hours", "18 hours, 31 mins", "35 mins".
String longDuration(int seconds) {
  final s = seconds < 0 ? 0 : seconds;
  final days = s ~/ 86400, hours = (s % 86400) ~/ 3600, mins = (s % 3600) ~/ 60;
  String part(int n, String one, String many) => '$n ${n == 1 ? one : many}';
  if (days > 0) return [part(days, 'day', 'days'), if (hours > 0) part(hours, 'hour', 'hours')].join(', ');
  if (hours > 0) return [part(hours, 'hour', 'hours'), if (mins > 0) part(mins, 'min', 'mins')].join(', ');
  return part(mins, 'min', 'mins');
}

enum ScoreFace { good, ok, bad }

ScoreFace? scoreFace(int? score) {
  if (score == null || score == 0) return null;
  if (score >= 75) return ScoreFace.good;
  if (score >= 60) return ScoreFace.ok;
  return ScoreFace.bad;
}

const _sources = {
  'ORIGINAL': 'Original',
  'MANGA': 'Manga',
  'LIGHT_NOVEL': 'Light Novel',
  'VISUAL_NOVEL': 'Visual Novel',
  'VIDEO_GAME': 'Video Game',
  'WEB_NOVEL': 'Web Novel',
  'NOVEL': 'Novel',
  'DOUJINSHI': 'Doujinshi',
  'ANIME': 'Anime',
  'LIVE_ACTION': 'Live Action',
  'GAME': 'Game',
  'COMIC': 'Comic',
  'MULTIMEDIA_PROJECT': 'Multimedia Project',
  'PICTURE_BOOK': 'Picture Book',
  'OTHER': 'Other',
};

class SeasonCard {
  const SeasonCard({
    required this.title,
    required this.whenLabel,
    required this.when,
    required this.nextAt,
    required this.origin,
    required this.genres,
    required this.score,
    required this.face,
    required this.popularRank,
    required this.studio,
  });

  final Title title;

  /// "Ep 2 of 12 airing in", "Premieres", "Released"…
  final String whenLabel;

  /// "18 hours, 31 mins", "Oct 12, 2026", "TBA".
  final String when;

  /// Unix seconds of the next episode, for "Airing soonest".
  final int? nextAt;

  /// "Sequel to …", else "Source • Light Novel".
  final String origin;
  final List<String> genres;

  /// AniList's average, 0–100; null before there is one.
  final int? score;
  final ScoreFace? face;

  /// "#7" most popular this season; null for leftovers and unranked titles.
  final int? popularRank;
  final String studio;
}

String? _dateLabel(AniListDate d) {
  if (d.year == null) return null;
  if (d.month == null) return '${d.year}';
  if (d.day == null) return '${_longMonths[d.month! - 1]} ${d.year}';
  return '${_months[d.month! - 1]} ${d.day}, ${d.year}';
}

SeasonCard buildCard(
  AniListMedia m, {
  required SeasonYear season,
  required int nowSeconds,
  TitlePreference titles = TitlePreference.userPreferred,
  bool leftover = false,
}) {
  final title = adaptMedia(m, titles: titles);
  final raw = m.raw;
  final next = m.nextAiringEpisode;
  final start = _dateLabel(AniListDate.fromJson(raw['startDate'] as Json?));

  final (String, String, int?) timing = switch (next) {
    final n? => (
      'Ep ${n.episode}${m.episodes != null ? ' of ${m.episodes}' : ''} airing in',
      longDuration(n.airingAt - nowSeconds),
      n.airingAt,
    ),
    null when m.status == 'FINISHED' => (
      m.format == 'MOVIE' ? 'Released' : (m.episodes != null ? '${m.episodes} episodes · aired' : 'Aired'),
      start ?? '—',
      null,
    ),
    null when m.status == 'NOT_YET_RELEASED' => ('Premieres', start ?? 'TBA', null),
    null => ('Airing', start ?? 'TBA', null),
  };

  // the anime it's a sequel to, in the viewer's title language
  final prequel = (((raw['relations'] as Json?)?['edges'] as List?) ?? const [])
      .whereType<Json>()
      .where((e) => e['relationType'] == 'PREQUEL' && (e['node'] as Json?)?['type'] == 'ANIME')
      .firstOrNull;
  String? sequelTo;
  if (prequel != null) {
    final t = (prequel['node'] as Json)['title'] as Json? ?? const {};
    sequelTo =
        ((titles == TitlePreference.english ? t['english'] : t['userPreferred']) ?? t['english'] ?? t['romaji'])
            as String?;
  }

  final rank = leftover
      ? null
      : ((raw['rankings'] as List?) ?? const [])
            .whereType<Json>()
            .where(
              (r) =>
                  r['type'] == 'POPULAR' &&
                  r['allTime'] != true &&
                  r['season'] == season.season.api &&
                  r['year'] == season.year,
            )
            .firstOrNull;
  final source = raw['source'] as String?;

  return SeasonCard(
    title: title,
    whenLabel: timing.$1,
    when: timing.$2,
    nextAt: timing.$3,
    origin: sequelTo != null
        ? 'Sequel to $sequelTo'
        : source != null
        ? 'Source • ${_sources[source] ?? source}'
        : 'Source • Unknown',
    genres: m.genres.take(3).toList(),
    score: (m.averageScore ?? 0) > 0 ? m.averageScore : null,
    face: scoreFace(m.averageScore),
    popularRank: (rank?['rank'] as num?)?.toInt(),
    studio: m.studios.firstOrNull ?? '',
  );
}

enum ChartSort {
  popularity('Popularity'),
  score('Score'),
  airing('Airing soonest'),
  title('Title');

  const ChartSort(this.label);
  final String label;
}

class ChartSection {
  const ChartSection(this.key, this.label, this.cards);
  final String key;
  final String label;
  final List<SeasonCard> cards;
}

const _sections = <(String, String, List<String>)>[
  ('tv', 'TV', ['TV']),
  ('short', 'TV Short', ['TV_SHORT']),
  ('leftovers', 'Leftovers', []),
  ('movie', 'Movie', ['MOVIE']),
  ('other', 'OVA / ONA / Special', ['OVA', 'ONA', 'SPECIAL']),
];

List<SeasonCard> _sorted(List<SeasonCard> cards, ChartSort sort) {
  final s = [...cards];
  switch (sort) {
    case ChartSort.score:
      s.sort((a, b) => (b.score ?? -1).compareTo(a.score ?? -1));
    case ChartSort.airing:
      s.sort((a, b) => (a.nextAt ?? 1 << 40).compareTo(b.nextAt ?? 1 << 40));
    case ChartSort.title:
      s.sort((a, b) => a.title.title.toLowerCase().compareTo(b.title.title.toLowerCase()));
    case ChartSort.popularity:
      break; // AniList's own order
  }
  return s;
}

/// The chart's sections in AniChart's order; empty ones are left out.
List<ChartSection> buildSeasonChart(
  List<AniListMedia> media,
  List<AniListMedia> leftovers, {
  required SeasonYear season,
  required int nowSeconds,
  TitlePreference titles = TitlePreference.userPreferred,
  ChartSort sort = ChartSort.popularity,
}) => [
  for (final (key, label, formats) in _sections)
    ChartSection(
      key,
      label,
      _sorted([
        for (final m in key == 'leftovers' ? leftovers : media.where((m) => formats.contains(m.format)))
          buildCard(m, season: season, nowSeconds: nowSeconds, titles: titles, leftover: key == 'leftovers'),
      ], sort),
    ),
].where((s) => s.cards.isNotEmpty).toList();

// ── The week ──

const _dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
String _pad(int n) => n.toString().padLeft(2, '0');

/// Local midnight of the Monday of [date]'s week.
DateTime mondayOf(DateTime date) {
  final d = DateTime(date.year, date.month, date.day);
  return DateTime(d.year, d.month, d.day - (d.weekday - 1));
}

DateTime addDays(DateTime d, int days) => DateTime(d.year, d.month, d.day + days);

/// "Oct 5 – 11", "Sep 28 – Oct 4": the week the Airing view shows.
String weekLabel(DateTime monday) {
  final sunday = addDays(monday, 6);
  final start = '${_months[monday.month - 1]} ${monday.day}';
  return sunday.month == monday.month
      ? '$start – ${sunday.day}'
      : '$start – ${_months[sunday.month - 1]} ${sunday.day}';
}

class CalendarSlot {
  const CalendarSlot({
    required this.id,
    required this.title,
    required this.episode,
    required this.airingAt,
    required this.time,
    required this.aired,
    required this.mine,
    required this.soon,
    required this.canAddOne,
  });

  final int id;
  final Title title;
  final int episode;
  final int airingAt;

  /// Local "HH:MM".
  final String time;
  final bool aired;

  /// On the viewer's list as Watching or Rewatching.
  final bool mine;

  /// Airs within a day: the countdown turns the accent.
  final bool soon;

  /// Mine, out, and not watched yet: offer +1.
  final bool canAddOne;
}

class CalendarDay {
  CalendarDay({
    required this.date,
    required this.name,
    required this.weekday,
    required this.past,
    required this.isToday,
  });

  final DateTime date;

  /// "Today", or "Mon"…
  final String name;
  final String weekday;

  /// Before today, in the week that contains now.
  final bool past;
  final bool isToday;
  final slots = <CalendarSlot>[];

  /// "Oct 5".
  String get label => '${_months[date.month - 1]} ${date.day}';
}

/// Seven days from [monday], each with its airings in local time. In the
/// week that contains now: today first, the rest of the week, then the days
/// already past ("Earlier this week").
List<CalendarDay> buildCalendar(
  List<AiringSlot> slots,
  DateTime monday, {
  required DateTime now,
  TitlePreference titles = TitlePreference.userPreferred,
  ({MediaListStatus status, int progress})? Function(int mediaId)? entry,
  bool mineOnly = false,
}) {
  final nowSeconds = now.millisecondsSinceEpoch ~/ 1000;
  final today = mondayOf(now) == monday ? now.weekday - 1 : -1;
  final days = [
    for (var i = 0; i < 7; i++)
      CalendarDay(
        date: addDays(monday, i),
        name: i == today ? 'Today' : _dayNames[i],
        weekday: _weekdays[i],
        past: today >= 0 && i < today,
        isToday: i == today,
      ),
  ];
  for (final slot in slots) {
    final at = DateTime.fromMillisecondsSinceEpoch(slot.airingAt * 1000);
    if (mondayOf(at) != monday) continue;
    final e = entry?.call(slot.media.id);
    final mine = e != null && (e.status == MediaListStatus.current || e.status == MediaListStatus.repeating);
    if (mineOnly && !mine) continue;
    final aired = slot.airingAt <= nowSeconds;
    days[at.weekday - 1].slots.add(
      CalendarSlot(
        id: slot.id,
        title: adaptMedia(slot.media, entry: e, titles: titles),
        episode: slot.episode,
        airingAt: slot.airingAt,
        time: '${_pad(at.hour)}:${_pad(at.minute)}',
        aired: aired,
        mine: mine,
        soon: !aired && slot.airingAt - nowSeconds < 86400,
        canAddOne: mine && aired && e.progress < slot.episode,
      ),
    );
  }
  for (final d in days) {
    d.slots.sort((a, b) => a.airingAt.compareTo(b.airingAt));
  }
  return [...days.where((d) => !d.past), ...days.where((d) => d.past)];
}

// ── Providers ──

final seasonChartProvider = FutureProvider.autoDispose
    .family<({List<AniListMedia> media, List<AniListMedia> leftovers}), SeasonYear>((ref, season) {
      ref.cacheFor(screenCache);
      final session = ref.watch(sessionProvider.select((s) => (s.signedIn, s.showAdultContent)));
      return ref.watch(anilistClientProvider).fetchSeasonChart(season, signedIn: session.$1, showAdult: session.$2);
    });

/// The week starting [monday] (local midnight), soonest first.
final airingWeekProvider = FutureProvider.autoDispose.family<List<AiringSlot>, DateTime>((ref, monday) async {
  ref.cacheFor(screenCache);
  final session = ref.watch(sessionProvider.select((s) => (s.signedIn, s.showAdultContent)));
  final start = monday.millisecondsSinceEpoch ~/ 1000;
  final end = addDays(monday, 7).millisecondsSinceEpoch ~/ 1000;
  final slots = await ref
      .watch(anilistClientProvider)
      .fetchAiringWeek(start, end, signedIn: session.$1, showAdult: session.$2);
  // the week's media carry no list state; fetch the viewer's entries for
  // them (50 a request) and share them with every slot
  final userId = ref.read(sessionProvider).user?.id;
  if (session.$1 && userId != null) {
    final store = ref.read(listStoreProvider.notifier);
    final since = store.stamp();
    final ids = {for (final s in slots) s.media.id}.toList();
    final client = ref.read(anilistClientProvider);
    try {
      for (var i = 0; i < ids.length; i += 50) {
        final found = await client.fetchListEntries(userId, ids.sublist(i, (i + 50).clamp(0, ids.length)));
        store.seed([
          for (final e in found)
            if (e.mediaId != null) ListEntry(id: e.id, mediaId: e.mediaId!, status: e.status, progress: e.progress),
        ], since: since);
      }
    } catch (_) {
      // without list state the slots still show; they just can't be "mine"
    }
  }
  return slots;
});

/// Manga's New releases: popular series that started serializing in the
/// last few months and are still running.
final newMangaProvider = FutureProvider.autoDispose<List<Title>>((ref) async {
  ref.cacheFor(screenCache);
  final session = ref.watch(sessionProvider);
  final now = DateTime.now();
  final media = await ref
      .watch(anilistClientProvider)
      .fetchNewManga(
        DateTime(now.year, now.month - 3),
        signedIn: session.signedIn,
        showAdult: session.showAdultContent,
      );
  return [for (final m in media) adaptMedia(m, titles: session.titles)];
});

/// Which Seasonal view anime mode shows.
enum SeasonalView { season, airing }
