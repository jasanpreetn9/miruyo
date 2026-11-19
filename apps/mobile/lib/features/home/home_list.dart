// The viewer's own part of Home (hero + Continue), ported from
// apps/web/src/lib/page-data/home.ts (createContinueContent, heroPicks).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anilist/client.dart';
import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/progress.dart';
import '../../core/catalog/title.dart';
import '../../core/list/list_entry.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';
import '../for_you/for_you_data.dart';

/// How many recommendations the hero carousel rotates through.
const heroSlides = 5;

class HomeList {
  const HomeList({required this.titles, required this.hasAnyEntry, this.upNext = const [], this.savedAt});

  /// In progress (Watching, Rewatching, Paused), most recently updated first.
  final List<Title> titles;

  /// Planning, the first few by priority: what to start next.
  final List<Title> upNext;

  /// Anything on the list at all: tells an empty list from one with nothing
  /// in progress.
  final bool hasAnyEntry;

  /// Set when this is the device's copy (AniList unreachable).
  final DateTime? savedAt;
}

final homeListProvider = FutureProvider.autoDispose.family<HomeList, Mode>((ref, mode) async {
  ref.cacheFor(screenCache);
  final session = ref.watch(sessionProvider.select((s) => (s.user?.id, s.titles)));
  final userId = session.$1;
  if (userId == null) return const HomeList(titles: [], hasAnyEntry: false);
  final store = ref.read(listStoreProvider.notifier);
  final since = store.stamp();
  final Fetched<Json> fetched = await ref.watch(anilistClientProvider).fetchHomeList(userId, mode.mediaType);
  final seeds = <ListEntry>[];
  List<Title> read(String key) {
    final entries = (((fetched.data[key] as Json?)?['mediaList'] as List?) ?? const []).whereType<Json>();
    return [
      for (final e in entries)
        () {
          final media = AniListMedia.fromJson(e['media'] as Json);
          final status = MediaListStatus.parse(e['status']);
          final progress = (e['progress'] as num?)?.toInt() ?? 0;
          seeds.add(ListEntry(id: (e['id'] as num?)?.toInt(), mediaId: media.id, status: status, progress: progress));
          return adaptMedia(media, entry: (status: status, progress: progress), titles: session.$2);
        }(),
    ];
  }

  final titles = read('continueList');
  final upNext = read('upNext');
  store.seed(seeds, since: since);
  final any = (((fetched.data['anyEntry'] as Json?)?['mediaList'] as List?) ?? const []).isNotEmpty;
  return HomeList(
    titles: titles,
    upNext: [
      for (final t in upNext)
        if (!titles.any((c) => c.id == t.id)) t,
    ],
    hasAnyEntry: any,
    savedAt: fetched.fromDevice ? fetched.savedAt : null,
  );
});

/// "Continue watching" / "Continue reading".
String continueHeading(Mode mode) => mode.isAnime ? 'Continue watching' : 'Continue reading';

/// Continue, planned (01): what's ready first (the most new episodes
/// first), then caught-up titles by which airs soonest, Paused last, and Up
/// next beside them.
class ContinuePlan {
  const ContinuePlan({
    required this.ready,
    required this.waiting,
    required this.paused,
    required this.upNext,
    required this.newEpisodes,
    required this.airingThisWeek,
  });

  /// Something to watch now, the most new episodes first.
  final List<Title> ready;

  /// Caught up and still airing, the soonest to air first.
  final List<Title> waiting;
  final List<Title> paused;

  /// Still on Planning: a +1 starts one, and it moves into [ready].
  final List<Title> upNext;

  /// Aired episodes not watched yet, across what's in progress (not Paused).
  final int newEpisodes;

  /// Titles in progress with an episode airing in the next 7 days.
  final int airingThisWeek;

  /// Nothing ready, but something on its way.
  bool get caughtUp => ready.isEmpty && waiting.isNotEmpty;

  /// Nothing to show at all.
  bool get isEmpty => ready.isEmpty && waiting.isEmpty && paused.isEmpty && upNext.isEmpty;
}

/// How many Planning titles Up next offers.
const upNextShown = 4;

/// [titles] arrive most recently updated first, which breaks ties; [upNext]
/// by priority. Up next is for starting something now, so it only offers
/// titles that are out: one that isn't waits on Home's Upcoming row. The
/// home query asks for twelve Planning entries so it still fills four.
/// Watching and Rewatching are in progress; anything moved off
/// them this visit (completed, dropped) leaves, and Undo brings it back. An
/// Up next title started this visit joins the rest.
ContinuePlan planContinue(
  List<Title> titles, {
  required ({MediaListStatus status, int progress})? Function(Title) entry,
  required int now,
  List<Title> upNext = const [],
}) {
  final all = [
    ...titles,
    for (final t in upNext)
      if (!titles.any((c) => c.id == t.id)) t,
  ];
  int progress(Title t) => entry(t)?.progress ?? t.me?.progress ?? 0;
  MediaListStatus status(Title t) => entry(t)?.status ?? t.me?.status ?? MediaListStatus.current;
  bool active(Title t) => status(t) == MediaListStatus.current || status(t) == MediaListStatus.repeating;
  int? newCount(Title t) {
    final aired = airedCount(t);
    return aired == null ? null : (aired - progress(t)).clamp(0, 1 << 20);
  }

  bool waiting(Title t) => newCount(t) == 0 && t.next != null;

  final ready = [
    for (final t in all)
      if (active(t) && !waiting(t)) t,
  ];
  // most new first; unknown (no schedule) after any with new episodes, in update order
  final ranked = [...ready.indexed]
    ..sort((a, b) {
      final na = newCount(a.$2) ?? 0, nb = newCount(b.$2) ?? 0;
      return na != nb ? nb.compareTo(na) : a.$1.compareTo(b.$1);
    });
  final caught = [
    for (final t in all)
      if (active(t) && waiting(t)) t,
  ]..sort((a, b) => a.next!.airingAt.compareTo(b.next!.airingAt));
  final inProgress = [...ready, ...caught];
  return ContinuePlan(
    ready: [for (final e in ranked) e.$2],
    waiting: caught,
    paused: [
      for (final t in all)
        if (status(t) == MediaListStatus.paused) t,
    ],
    upNext: [
      for (final t in all)
        if (status(t) == MediaListStatus.planning && t.status != 'Not yet released') t,
    ].take(upNextShown).toList(),
    newEpisodes: inProgress.fold(0, (sum, t) => sum + (newCount(t) ?? 0)),
    airingThisWeek: inProgress.where((t) => t.next != null && t.next!.airingAt - now <= 7 * 86400).length,
  );
}

/// "3 new episodes · 2 airing this week". Caught up, the section's own card
/// says so, so the summary doesn't too.
String continueSummary(ContinuePlan plan, {required bool isAnime}) {
  final unit = isAnime ? 'episode' : 'chapter';
  return [
    if (plan.newEpisodes > 0) '${plan.newEpisodes} new ${plan.newEpisodes == 1 ? unit : '${unit}s'}',
    if (plan.airingThisWeek > 0) '${plan.airingThisWeek} airing this week',
  ].join(' · ');
}

/// One of the hero's slides: something to watch next, and why.
class HeroPick {
  const HeroPick({required this.title, required this.reason, required this.pick});

  final Title title;

  /// "Because you rated Cowboy Bebop 9.5/10", or "Popular in Fall 2026".
  final String reason;

  /// From For You, so Not this can hide it.
  final bool pick;
}

/// The hero recommends (Home is for finding what to watch and tracking it):
/// For You's picks, what airs this season first; with no picks (too few
/// ratings, or For You failed), the season's most popular you haven't
/// added. Picks are already off your list.
List<HeroPick> heroPicks(
  List<Pick> picks,
  List<Title> popular, {
  required String season,
  required String fallbackReason,
  required bool Function(Title) onList,
}) {
  if (picks.isNotEmpty) {
    bool airingNow(Pick p) => p.title.season == season && p.title.status == 'Releasing';
    return [
      for (final p in [...picks.where(airingNow), ...picks.where((p) => !airingNow(p))].take(heroSlides))
        HeroPick(title: p.title, reason: reasonFor(p), pick: true),
    ];
  }
  return [
    for (final t in popular.where((t) => !onList(t)).take(heroSlides))
      HeroPick(title: t, reason: fallbackReason, pick: false),
  ];
}

/// How long a title is: "24 eps", "1 ep", a movie's "1h 47m", "120 ch"; null when AniList doesn't say.
String? lengthOf(Title title) {
  final total = title.total;
  final minutes = title.duration;
  if (title.isAnime && total == 1 && minutes != null && minutes > 0) return hoursMinutes(minutes);
  if (total == null || total == 0) return null;
  return title.isAnime ? '$total ${total == 1 ? 'ep' : 'eps'}' : '$total ch';
}

/// "6h 24m", "45m": time left at [minutes].
String hoursMinutes(int minutes) =>
    minutes >= 60 ? '${minutes ~/ 60}h${minutes % 60 > 0 ? ' ${minutes % 60}m' : ''}' : '${minutes}m';
