// My List (05, 21), ported from apps/web/src/lib/page-data/list.ts
// (buildListView), plus Up next: Planning in the order you set, saved to
// AniList as entry priority.

import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anilist/client.dart' show isListRefresh;
import '../../core/anilist/queries.dart' show listCollectionQuery;
import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/humanize.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/progress.dart';
import '../../core/catalog/score.dart';
import '../../core/catalog/status.dart';
import '../../core/catalog/title.dart';
import '../../core/list/list_entry.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';

enum ListSort {
  /// Planning only, and its default: the order set with the drag handles.
  upNext('Up next'),

  /// Watching and Rewatching, and their default: the most new episodes
  /// first, then what airs soonest (Home's order).
  toWatch('Most to watch'),
  updated('Last updated'),
  title('Title'),
  score('Score'),
  progress('Progress'),
  airing('Next episode');

  const ListSort(this.label);

  final String label;

  /// The sorts offered on a tab.
  static List<ListSort> on(MediaListStatus tab, {required bool isAnime}) => [
    if (tab == MediaListStatus.planning) upNext,
    if (_inProgress(tab)) toWatch,
    updated,
    title,
    score,
    progress,
    if (isAnime) airing,
  ];

  static ListSort defaultFor(MediaListStatus tab) => tab == MediaListStatus.planning
      ? upNext
      : _inProgress(tab)
      ? toWatch
      : updated;

  static bool _inProgress(MediaListStatus tab) => tab == MediaListStatus.current || tab == MediaListStatus.repeating;
}

/// Most to watch first: the most new episodes, then whatever airs soonest,
/// then the most recently updated.
int byToWatch(ListRow a, ListRow b) {
  final na = newEpisodesFor(a.title, a.progress) ?? 0, nb = newEpisodesFor(b.title, b.progress) ?? 0;
  if (na != nb) return nb.compareTo(na);
  final aa = a.title.next?.airingAt ?? 1 << 62, ab = b.title.next?.airingAt ?? 1 << 62;
  if (aa != ab) return aa.compareTo(ab);
  return b.updatedAt.compareTo(a.updatedAt);
}

class ListRow {
  const ListRow({
    required this.title,
    required this.status,
    required this.progress,
    required this.score,
    required this.priority,
    required this.updatedAt,
    required this.note,
    required this.noteColor,
    this.completedAt = AniListDate.empty,
  });

  final Title title;
  final MediaListStatus status;
  final int progress;
  final double score;
  final int priority;

  /// Unix seconds, as AniList last had it.
  final int updatedAt;

  /// "2 new · EP 9 in 2d 4h", "Up next #1 · TV", or format · season.
  final String note;
  final Color noteColor;

  /// When you finished it, for the grid's Completed shelf.
  final AniListDate completedAt;

  int get id => title.id;
}

class ListTab {
  const ListTab({required this.status, required this.label, required this.count});

  final MediaListStatus status;
  final String label;
  final int count;
}

class MyListView {
  const MyListView({
    required this.tabs,
    required this.rows,
    required this.formats,
    required this.summary,
    this.genres = const [],
    this.countries = const [],
    this.years = const [],
  });

  final List<ListTab> tabs;
  final List<ListRow> rows;

  /// Formats on this tab, for the Format filter.
  final List<String> formats;
  final String summary;

  /// The genres, countries and years on this tab, for their filters (newest
  /// year first).
  final List<String> genres;
  final List<String> countries;
  final List<int> years;
}

/// "Japan", "South Korea"…, for a country of origin code; unknown ones stay
/// a code (the web's countryName).
String countryName(String code) => _countryNames[code] ?? code;

const _countryNames = {'JP': 'Japan', 'KR': 'South Korea', 'CN': 'China', 'TW': 'Taiwan'};

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Just now", "12m ago", "2h ago", "Yesterday", "3d ago", "Aug 30", "2025",
/// in the device's time zone (the web's relativeTime).
String relativeTime(int unixSeconds, int now) {
  final diff = (now - unixSeconds).clamp(0, 1 << 62);
  if (diff < 60) return 'Just now';
  if (diff < 3600) return '${diff ~/ 60}m ago';
  if (diff < 86400) return '${diff ~/ 3600}h ago';
  if (diff < 2 * 86400) return 'Yesterday';
  if (diff < 7 * 86400) return '${diff ~/ 86400}d ago';
  final then = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  final today = DateTime.fromMillisecondsSinceEpoch(now * 1000);
  return then.year == today.year ? '${_months[then.month - 1]} ${then.day}' : '${then.year}';
}

/// "just now", "yesterday"; dates keep their capital ("Aug 30").
String _lowerFirst(String s) => s == 'Just now' || s == 'Yesterday' ? s.toLowerCase() : s;

/// The row's second line: airing context while watching (for manga, when
/// you last read it, or a hiatus), the Up next position on Planning, else
/// format and season (or release status).
({String note, Color color}) _rowNote(
  Title title,
  MediaListStatus status,
  int progress,
  int now, {
  required int updatedAt,
  int? upNext,
}) {
  final isAnime = title.isAnime;
  final next = title.next;
  if (status == MediaListStatus.current && isAnime && next != null) {
    final fresh = next.ep - 1 - progress;
    final when = formatTimeUntil(next.airingAt - now);
    // the same words as Home: "new", "Caught up"
    return fresh > 0
        ? (note: '$fresh new · EP ${next.ep} in $when', color: Accent.green)
        : (note: 'Caught up · EP ${next.ep} in $when', color: Accent.soraText);
  }
  // finished airing, still watching: what's left to watch
  final left = newEpisodesFor(title, progress);
  if (status == MediaListStatus.current && isAnime && left != null && left > 0) {
    return (note: '$left left', color: Accent.green);
  }
  if (status == MediaListStatus.current && !isAnime) {
    // every ongoing series says "Releasing"; when you last read it tells rows apart
    return title.status == 'Hiatus'
        ? (note: 'On hiatus', color: Accent.gold)
        : (note: 'Updated ${_lowerFirst(relativeTime(updatedAt, now))}', color: TextTone.mid);
  }
  final about = [title.knownFormat, isAnime ? title.season : title.status].whereType<String>().join(' · ');
  if (upNext != null) return (note: 'Up next #$upNext · $about', color: TextTone.low);
  return (note: about, color: TextTone.low);
}

int _byTitle(ListRow a, ListRow b) => a.title.title.toLowerCase().compareTo(b.title.title.toLowerCase());

/// Highest priority first; ties keep AniList's most-recently-updated first.
int byUpNext(ListRow a, ListRow b) =>
    b.priority.compareTo(a.priority) != 0 ? b.priority.compareTo(a.priority) : b.updatedAt.compareTo(a.updatedAt);

final _by = <ListSort, int Function(ListRow, ListRow)>{
  ListSort.upNext: byUpNext,
  ListSort.toWatch: byToWatch,
  ListSort.updated: (a, b) => b.updatedAt.compareTo(a.updatedAt),
  ListSort.title: _byTitle,
  ListSort.score: (a, b) => b.score.compareTo(a.score) != 0 ? b.score.compareTo(a.score) : _byTitle(a, b),
  ListSort.progress: (a, b) => b.progress.compareTo(a.progress),
  // soonest next episode first; nothing scheduled goes last
  ListSort.airing: (a, b) => (a.title.next?.airingAt ?? 1 << 62).compareTo(b.title.next?.airingAt ?? 1 << 62),
};

/// My List for one tab: counts for every tab, the filtered and sorted rows,
/// and a summary. [live] is the shared list store (local edits win over
/// what AniList sent); [now] is unix seconds.
MyListView buildListView(
  List<CollectionEntry> entries, {
  required MediaListStatus tab,
  required bool isAnime,
  required int now,
  ListState live = const ListState(),
  Set<int>? only,
  Set<int> hidden = const {},
  String filter = '',
  ListSort? sort,
  String format = '',
  String genre = '',
  String country = '',
  int? year,
  TitlePreference titles = TitlePreference.userPreferred,
  ScoreFormat scoreFormat = defaultScoreFormat,
}) {
  final query = filter.trim().toLowerCase();
  final mediaOf = {for (final c in entries) c.entry.mediaId: c.media};
  final sortBy = sort ?? ListSort.defaultFor(tab);

  final all = <ListRow>[];
  for (final c in entries) {
    final mediaId = c.entry.mediaId;
    if (live.isRemoved(mediaId)) continue;
    final mine = live[mediaId];
    final status = mine?.status ?? c.entry.status;
    final progress = mine?.progress ?? c.entry.progress;
    final title = adaptMedia(c.media, entry: (status: status, progress: progress), titles: titles);
    all.add(
      ListRow(
        title: title,
        status: status,
        progress: progress,
        score: mine?.score ?? c.entry.score,
        priority: mine?.priority ?? c.entry.priority,
        updatedAt: c.updatedAt,
        note: '',
        noteColor: TextTone.low,
        completedAt: mine?.completedAt ?? c.entry.completedAt,
      ),
    );
  }

  // titles set to "hide from status lists" are on their custom lists only
  final onStatusLists = [
    for (final r in all)
      if (!hidden.contains(r.title.id)) r,
  ];
  final counts = <MediaListStatus, int>{};
  for (final r in onStatusLists) {
    counts[r.status] = (counts[r.status] ?? 0) + 1;
  }

  // a custom list holds its titles whatever their status (the tab is ignored)
  final onTab = only != null
      ? [
          for (final r in all)
            if (only.contains(r.title.id)) r,
        ]
      : [
          for (final r in onStatusLists)
            if (r.status == tab) r,
        ];
  // Up next positions count the whole tab, not just what a filter leaves
  final positions = tab == MediaListStatus.planning && only == null
      ? {
          for (final (i, r) in ([...onTab]..sort(byUpNext)).indexed) r.id: i + 1,
        }
      : const <int, int>{};

  final rows = [
    for (final r in onTab)
      if ((format.isEmpty || r.title.format == format) &&
          (genre.isEmpty || (mediaOf[r.id]?.genres.contains(genre) ?? false)) &&
          (country.isEmpty || mediaOf[r.id]?.countryOfOrigin == country) &&
          (year == null || mediaOf[r.id]?.listYear == year) &&
          (query.isEmpty ||
              r.title.title.toLowerCase().contains(query) ||
              (r.title.en ?? '').toLowerCase().contains(query)))
        r,
  ]..sort(_by[sortBy]);

  final noted = [
    for (final r in rows)
      () {
        final n = _rowNote(
          r.title,
          r.status,
          r.progress,
          now,
          updatedAt: r.updatedAt,
          upNext: sortBy == ListSort.upNext ? positions[r.id] : null,
        );
        return ListRow(
          title: r.title,
          status: r.status,
          progress: r.progress,
          score: r.score,
          priority: r.priority,
          updatedAt: r.updatedAt,
          // on a custom list each row says its status
          note: only != null ? '${statusLabel(r.status, isAnime: isAnime)} · ${n.note}' : n.note,
          noteColor: n.color,
          completedAt: r.completedAt,
        );
      }(),
  ];

  final units = all.fold(0, (sum, r) => sum + r.progress);
  final String summary;
  if (isAnime) {
    final minutes = entries
        .where((c) => !live.isRemoved(c.entry.mediaId))
        .fold(0, (sum, c) => sum + (live[c.entry.mediaId]?.progress ?? c.entry.progress) * (c.media.duration ?? 24));
    summary =
        '${_thousands(all.length)} titles · ${_thousands(units)} episodes · ${(minutes / 1440).toStringAsFixed(1)} days watched';
  } else {
    final scored = all.where((r) => r.score > 0).toList();
    final mean = scored.isEmpty ? 0.0 : scored.fold(0.0, (s, r) => s + r.score) / scored.length;
    summary =
        '${_thousands(all.length)} titles · ${_thousands(units)} chapters'
        '${mean > 0 ? ' · mean score ${formatScore((mean * 10).round() / 10, scoreFormat)}' : ''}';
  }

  return MyListView(
    tabs: [
      for (final s in listStatuses)
        ListTab(
          status: s,
          label: statusLabel(s, isAnime: isAnime),
          count: counts[s] ?? 0,
        ),
    ],
    rows: noted,
    formats: {for (final r in onTab) r.title.format}.toList()..sort(),
    genres: {for (final r in onTab) ...?mediaOf[r.id]?.genres}.toList()..sort(),
    countries: {for (final r in onTab) ?mediaOf[r.id]?.countryOfOrigin}.toList()..sort(),
    years: {for (final r in onTab) ?mediaOf[r.id]?.listYear}.toList()..sort((a, b) => b.compareTo(a)),
    summary: summary,
  );
}

String _thousands(int n) => n.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');

/// New priorities after moving a Planning row, as mediaId → priority, for
/// only the rows that need to change. [order] is the tab in its new order
/// (rows carry their current priority) and [moved] the index the row landed
/// at. The moved row goes just above the one below it, and rows above are
/// raised only as far as keeping it there needs, so moving one title to the
/// top of an unordered list saves one entry, not the whole list.
Map<int, int> upNextPriorities(List<ListRow> order, int moved) {
  final below = moved + 1 < order.length ? order[moved + 1].priority : -1;
  final above = moved > 0 ? order[moved - 1].priority : null;
  bool fits(int p) => p > below && (above == null || p < above);
  final row = order[moved];
  if (fits(row.priority)) return const {};
  if (fits(below + 1)) return {row.id: below + 1};
  // no room between the neighbours: raise the rows above as far as needed
  final changes = <int, int>{};
  var floor = below;
  for (var i = moved; i >= 0; i--) {
    final current = order[i].priority;
    if (i < moved && current > floor) break;
    final next = i == moved || current <= floor ? floor + 1 : current;
    if (next != current) changes[order[i].id] = next;
    floor = next;
  }
  return changes;
}

class ListCollection {
  const ListCollection({required this.entries, this.custom = const [], this.hidden = const {}, this.savedAt});

  final List<CollectionEntry> entries;

  /// Your own lists on AniList, in its order: tabs after the statuses.
  final List<CustomList> custom;

  /// Titles set to "hide from status lists": on their custom lists only.
  final Set<int> hidden;

  /// Set when this is the device's copy (AniList unreachable).
  final DateTime? savedAt;
}

/// The viewer's whole list for a mode. Every entry is shared with the list
/// store in full, so the editor and every card see the same values.
final listCollectionProvider = FutureProvider.autoDispose.family<ListCollection, Mode>((ref, mode) async {
  ref.cacheFor(screenCache);
  final userId = ref.watch(sessionProvider.select((s) => s.user?.id));
  if (userId == null) return const ListCollection(entries: []);
  final store = ref.read(listStoreProvider.notifier);
  final client = ref.watch(anilistClientProvider)
    // each request remembers the edits it predates (Fetched.stamp)
    ..editClock = store.stamp;
  // a copy served stale has been replaced behind the screen: build again,
  // from the cache (the screen keeps its rows meanwhile)
  final refreshed = client.refreshed.listen((r) {
    if (isListRefresh(r, listCollectionQuery, userId, mode.mediaType)) ref.invalidateSelf();
  });
  ref.onDispose(refreshed.cancel);
  // one request: both read the same cached collection
  final (fetched, custom) = await (
    client.fetchListCollection(userId, mode.mediaType),
    client.fetchCustomLists(userId, mode.mediaType),
  ).wait;
  // titles edited since the copy was requested keep their local values
  store.seed([for (final c in fetched.data) ListEntry.fromSaved(c.entry)], since: fetched.stamp);
  return ListCollection(
    entries: fetched.data,
    custom: custom.lists,
    hidden: custom.hidden,
    savedAt: fetched.fromDevice ? fetched.savedAt : null,
  );
});
