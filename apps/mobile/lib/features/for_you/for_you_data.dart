// For You (08, Gestures · For You 17), ported from apps/web/src/lib/
// page-data/for-you.ts and state/for-you.svelte.ts: picks scored from
// AniList's recommendations for the titles you rated highest, plus a nudge
// toward the genres and studios you favour, and the other mode's take on
// titles you loved (the manga of an anime, the anime of a manga). Every
// pick carries the reason it was picked. "Tune picks" filters the result.

import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:clock/clock.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/title.dart';
import '../../core/providers.dart';
import '../../core/storage/prefs.dart';
import '../list/list_data.dart';
import '../profile/profile_data.dart' show toTenPoint;

/// Below this many scored titles, picks aren't worth showing (8c).
const minRatings = 5;

/// How many top-rated titles seed the picks.
const maxSeeds = 8;

/// A seed must be rated at least this (out of 10).
const _seedMinScore = 7.5;

/// How many titles from the other list look for their manga or anime.
const maxCrossSeeds = 4;

/// A cross seed suggests at most this many of its adaptations (Berserk has seven).
const _adaptationsPerSeed = 2;

/// How much the other mode's version of a title you loved weighs, in AniList
/// votes: about as much as a well-backed recommendation.
const _adaptationVotes = 30;

/// A pick from one of your favourite studios weighs this much more.
const _studioBoost = 0.15;

/// Recommended by AniList's users, or the other mode's version of a seed.
enum PickKind { recommended, adaptation }

/// A seed's related titles (relations: SOURCE, ADAPTATION, …), by seed id.
typedef Relations = Map<int, List<({String relationType, AniListMedia media})>>;

/// No cross seeds: the other list has too few ratings, or couldn't be read.
const ({List<Seed> seeds, Relations relations}) _noCross = (seeds: [], relations: {});

class Seed {
  const Seed({required this.title, required this.score});

  final Title title;

  /// Out of 10, e.g. 9 or 9.5.
  final double score;

  int get id => title.id;
}

class Pick {
  const Pick({
    required this.title,
    required this.because,
    required this.seedIds,
    required this.score,
    required this.votes,
    required this.sharedGenres,
    this.kind = PickKind.recommended,
    this.studio,
  });

  final Title title;

  /// The seed that contributed most, for "Because you rated X 9/10".
  final Seed because;

  /// Every seed that recommended it (the seed rail filters on these).
  final List<int> seedIds;
  final double score;

  /// AniList users recommending it to fans of [because].
  final int votes;

  /// Its genres that are among the ones you rate highest.
  final List<String> sharedGenres;
  final PickKind kind;

  /// One of your favourite studios made it.
  final ({int id, String name})? studio;
}

/// "9/10", "9.5/10".
String scoreLabel(double score) => '${score == score.roundToDouble() ? score.toInt() : score.toStringAsFixed(1)}/10';

String reasonFor(Pick pick) {
  if (pick.kind == PickKind.adaptation) {
    final what = pick.title.isAnime
        ? 'anime'
        : RegExp('novel', caseSensitive: false).hasMatch(pick.title.format)
        ? 'novel'
        : 'manga';
    return 'The $what of ${pick.because.title.title}, which you rated ${scoreLabel(pick.because.score)}';
  }
  return 'Because you rated ${pick.because.title.title} ${scoreLabel(pick.because.score)}';
}

const _ratedStatuses = {
  MediaListStatus.completed,
  MediaListStatus.current,
  MediaListStatus.repeating,
  MediaListStatus.paused,
};

/// How many titles on the list carry a score.
int scoredCount(List<CollectionEntry> entries) => entries.where((c) => c.entry.score > 0).length;

/// Today in the device's timezone ("2026-11-02"): the seeds change with it.
String localDay(DateTime now) =>
    '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

/// A number in (0, 1) from [text], the same every time (FNV-1a, then mixed):
/// the web's, bit for bit, so both draw the same seeds on the same day.
@visibleForTesting
double debugUnitHash(String text) => _unitHash(text);

double _unitHash(String text) {
  // Math.imul: the low 32 bits of the product (Dart's ints wrap at 64)
  int imul(int a, int b) => (a * b) & 0xFFFFFFFF;
  var h = 0x811c9dc5;
  for (final c in text.codeUnits) {
    h = imul(h ^ c, 0x01000193);
  }
  h = imul(h ^ (h >> 16), 0x85ebca6b);
  h = imul(h ^ (h >> 13), 0xc2b2ae35);
  h ^= h >> 16;
  return (h + 1) / 4294967297;
}

/// The titles driving the picks: up to [maxSeeds] you rated 7.5 or more,
/// best first (by your exact score, then most recently updated). With more
/// than that to choose from, [day] draws a different set each day: the same
/// all day, and weighted so the higher you rated a title, the more often it
/// comes round (a 10 about six times as often as a 7.5). Without [day], the
/// top ones. [leaveOut]: seeds you've stopped using, so they don't take a slot.
List<Seed> pickSeeds(
  List<CollectionEntry> entries, {
  ScoreFormat? scoreFormat,
  TitlePreference titles = TitlePreference.userPreferred,
  String? day,
  Set<int> leaveOut = const {},
}) {
  final pool = [
    for (final c in entries)
      if (c.entry.score > 0 && _ratedStatuses.contains(c.entry.status) && !leaveOut.contains(c.media.id))
        (entry: c, exact: toTenPoint(c.entry.score, scoreFormat)),
  ].where((s) => s.exact >= _seedMinScore).toList();
  // a weighted draw without replacement (Efraimidis–Spirakis), keyed on the day
  final drawn = day != null && pool.length > maxSeeds
      ? ([
          for (final s in pool)
            (s: s, key: math.pow(_unitHash('$day:${s.entry.media.id}'), 1 / (s.exact - 7)).toDouble()),
        ]..sort((a, b) => b.key.compareTo(a.key))).take(maxSeeds).map((d) => d.s).toList()
      : pool;
  drawn.sort(
    (a, b) => b.exact != a.exact ? b.exact.compareTo(a.exact) : b.entry.updatedAt.compareTo(a.entry.updatedAt),
  );
  return [
    for (final s in drawn.take(maxSeeds))
      // shown as "9.5/10": half points
      Seed(
        title: adaptMedia(s.entry.media, titles: titles),
        score: (s.exact * 2).round() / 2,
      ),
  ];
}

/// The genres you rate highest, most frequent first.
Set<String> _favouriteGenres(List<CollectionEntry> entries, ScoreFormat? scoreFormat) {
  final counts = <String, int>{};
  for (final c in entries) {
    if (toTenPoint(c.entry.score, scoreFormat) < _seedMinScore) continue;
    for (final g in c.media.genres) {
      counts[g] = (counts[g] ?? 0) + 1;
    }
  }
  final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  return {for (final e in sorted.take(5)) e.key};
}

/// The studios behind the titles you rate highest: a studio counts once two
/// of its titles are rated 7.5 or more. The top five, most titles first.
Map<int, String> favouriteStudios(List<CollectionEntry> entries, ScoreFormat? scoreFormat) {
  final counts = <int, ({String name, int n})>{};
  for (final c in entries) {
    if (toTenPoint(c.entry.score, scoreFormat) < _seedMinScore) continue;
    final studio = c.media.mainStudio;
    if (studio == null) continue;
    counts[studio.id] = (name: studio.name, n: (counts[studio.id]?.n ?? 0) + 1);
  }
  final sorted = counts.entries.where((e) => e.value.n >= 2).toList()..sort((a, b) => b.value.n.compareTo(a.value.n));
  return {for (final e in sorted.take(5)) e.key: e.value.name};
}

/// The other mode's version of a seed: an anime's source manga (or novel),
/// a manga's anime adaptations, its two most popular.
List<AniListMedia> _adaptationsOf(List<({String relationType, AniListMedia media})> relations, Seed seed) {
  final seedType = seed.title.isAnime ? MediaType.anime : MediaType.manga;
  final wanted = seed.title.isAnime ? 'SOURCE' : 'ADAPTATION';
  final found = [
    for (final r in relations)
      if (r.relationType == wanted && r.media.type != seedType) r.media,
  ]..sort((a, b) => (b.popularity ?? 0).compareTo(a.popularity ?? 0));
  return found.take(_adaptationsPerSeed).toList();
}

/// Ranks every recommended title not already on the list. A title earns
/// weight from each seed that recommends it (the seed's score × AniList's
/// vote count, dampened), plus a little for each favourite genre it shares
/// and more if a favourite studio made it. [crossSeeds] are titles you loved
/// on your other list; their manga or anime ([relations]) join the picks.
List<Pick> buildPicks(
  List<Seed> seeds,
  Map<int, List<({int rating, AniListMedia media})>> recommendations, {
  required List<CollectionEntry> entries,
  required MediaType type,
  required bool showAdult,
  Set<int> dismissed = const {},
  ScoreFormat? scoreFormat,
  TitlePreference titles = TitlePreference.userPreferred,
  List<Seed> crossSeeds = const [],
  Relations relations = const {},
}) {
  final onList = {for (final c in entries) c.media.id};
  final genres = _favouriteGenres(entries, scoreFormat);
  final studios = favouriteStudios(entries, scoreFormat);
  final byId =
      <
        int,
        ({AniListMedia media, double score, double best, Seed because, List<int> seedIds, int votes, PickKind kind})
      >{};

  void add(AniListMedia media, Seed seed, int votes, PickKind kind) {
    if (media.type != type || onList.contains(media.id) || dismissed.contains(media.id)) return;
    if (media.mediaListEntry != null || (media.isAdult && !showAdult)) return;
    final weight = seed.score / 10 * math.log(2 + math.max(0, votes)) / math.ln2;
    final pick = byId[media.id];
    if (pick == null) {
      byId[media.id] = (
        media: media,
        score: weight,
        best: weight,
        because: seed,
        seedIds: [seed.id],
        votes: votes,
        kind: kind,
      );
      return;
    }
    final better = weight > pick.best;
    byId[media.id] = (
      media: media,
      score: pick.score + weight,
      best: better ? weight : pick.best,
      because: better ? seed : pick.because,
      seedIds: pick.seedIds.contains(seed.id) ? pick.seedIds : [...pick.seedIds, seed.id],
      votes: better ? votes : pick.votes,
      kind: better ? kind : pick.kind,
    );
  }

  for (final seed in seeds) {
    for (final (:rating, :media) in recommendations[seed.id] ?? const <({int rating, AniListMedia media})>[]) {
      add(media, seed, rating, PickKind.recommended);
    }
  }
  for (final seed in crossSeeds) {
    for (final media in _adaptationsOf(relations[seed.id] ?? const [], seed)) {
      add(media, seed, _adaptationVotes, PickKind.adaptation);
    }
  }

  final picks = [
    for (final p in byId.values)
      () {
        final shared = [
          for (final g in p.media.genres)
            if (genres.contains(g)) g,
        ];
        final main = p.media.mainStudio;
        final studio = main != null && studios.containsKey(main.id) ? main : null;
        return Pick(
          title: adaptMedia(p.media, titles: titles),
          because: p.because,
          seedIds: p.seedIds,
          score: p.score * (1 + 0.1 * shared.length) * (studio != null ? 1 + _studioBoost : 1),
          votes: p.votes,
          sharedGenres: shared,
          kind: p.kind,
          studio: studio,
        );
      }(),
  ]..sort((a, b) => b.score != a.score ? b.score.compareTo(a.score) : a.title.id.compareTo(b.title.id));
  return picks;
}

/// "Tune picks": what to leave out. Kept on the device.
class Tune {
  const Tune({this.outOnly = false, this.crossMode = true, this.hiddenGenres = const []});

  /// From what was saved; anything missing or broken is the default.
  factory Tune.fromJson(Object? raw) {
    if (raw is! Map) return const Tune();
    return Tune(
      outOnly: raw['outOnly'] == true,
      crossMode: raw['crossMode'] != false,
      hiddenGenres: [if (raw['hiddenGenres'] case final List genres) ...genres.whereType<String>()],
    );
  }

  /// Only titles that are out (or airing).
  final bool outOnly;

  /// Include the other mode's version of titles you loved.
  final bool crossMode;

  /// Genres to leave out.
  final List<String> hiddenGenres;

  /// Whether anything is tuned away from the default.
  bool get changed => outOnly || !crossMode || hiddenGenres.isNotEmpty;

  Tune copyWith({bool? outOnly, bool? crossMode, List<String>? hiddenGenres}) => Tune(
    outOnly: outOnly ?? this.outOnly,
    crossMode: crossMode ?? this.crossMode,
    hiddenGenres: hiddenGenres ?? this.hiddenGenres,
  );

  Map<String, Object> toJson() => {'outOnly': outOnly, 'crossMode': crossMode, 'hiddenGenres': hiddenGenres};
}

/// The picks [tune] keeps.
List<Pick> tunePicks(List<Pick> picks, Tune tune) {
  final hidden = tune.hiddenGenres.toSet();
  return [
    for (final p in picks)
      if (!(tune.outOnly && p.title.status == 'Not yet released') &&
          !(!tune.crossMode && p.kind == PickKind.adaptation) &&
          !p.title.genres.any(hidden.contains))
        p,
  ];
}

/// Every genre among the picks, most common first: what Tune can leave out.
List<String> pickGenres(List<Pick> picks) {
  final counts = <String, int>{};
  for (final p in picks) {
    for (final g in p.title.genres) {
      counts[g] = (counts[g] ?? 0) + 1;
    }
  }
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value != a.value ? b.value.compareTo(a.value) : a.key.compareTo(b.key));
  return [for (final e in sorted) e.key];
}

class ForYou {
  const ForYou({
    required this.coldStart,
    required this.scored,
    required this.seeds,
    required this.picks,
    this.crossSeeds = const [],
  });

  /// Fewer than [minRatings] scored titles: picks wouldn't be worth much yet.
  final bool coldStart;

  /// How many titles on the list carry a score.
  final int scored;
  final List<Seed> seeds;

  /// Titles you loved on your other list, whose manga or anime joined the picks.
  final List<Seed> crossSeeds;
  final List<Pick> picks;
}

/// For You for a mode: the list (the same request as My List and Stats),
/// then AniList's recommendations for the day's highly rated titles. Hidden
/// picks and muted seeds are filtered by the screens, so neither needs a
/// new request.
final forYouProvider = FutureProvider.autoDispose.family<ForYou, Mode>((ref, mode) async {
  ref.cacheFor(screenCache);
  final session = ref.watch(sessionProvider.select((s) => (s.scoreFormat, s.showAdultContent, s.titles)));
  final collecting = ref.watch(listCollectionProvider(mode).future);
  final other = mode.isAnime ? Mode.manga : Mode.anime;
  // the other list loads alongside this one, not after it; it's extra, so a
  // failure there only means no cross picks
  final otherList = ref
      .read(listCollectionProvider(other).future)
      .then<List<CollectionEntry>?>((c) => c.entries, onError: (Object _) => null);
  final collection = await collecting;
  final entries = collection.entries;
  final scored = scoredCount(entries);
  // the seeds rotate each day: today's, then tomorrow's from midnight
  final now = clock.now();
  final midnight = Timer(DateTime(now.year, now.month, now.day + 1).difference(now), ref.invalidateSelf);
  ref.onDispose(midnight.cancel);

  /// The cross seeds (the day's top titles on your other list) and their
  /// relations. It's extra: if either request fails, For You goes on without it.
  Future<({List<Seed> seeds, Relations relations})> cross() async {
    try {
      final list = await otherList;
      if (list == null) return _noCross;
      // the other list needs enough ratings to say what you loved
      if (scoredCount(list) < minRatings) return _noCross;
      final seeds = pickSeeds(
        list,
        scoreFormat: session.$1,
        titles: session.$3,
        day: localDay(now),
      ).take(maxCrossSeeds).toList();
      return (
        seeds: seeds,
        relations: await ref.read(anilistClientProvider).fetchRelations([for (final s in seeds) s.id]),
      );
    } on Exception {
      return _noCross;
    }
  }

  if (scored < minRatings) {
    // too few ratings here for picks of its own, but titles loved on the
    // other list can still suggest their manga (or anime)
    final c = await cross();
    final picks = buildPicks(
      const [],
      const {},
      entries: entries,
      type: mode.mediaType,
      showAdult: session.$2,
      scoreFormat: session.$1,
      titles: session.$3,
      crossSeeds: c.seeds,
      relations: c.relations,
    );
    return picks.isEmpty
        ? ForYou(coldStart: true, scored: scored, seeds: const [], picks: const [])
        : ForYou(coldStart: false, scored: scored, seeds: const [], crossSeeds: c.seeds, picks: picks);
  }
  final seeds = pickSeeds(
    entries,
    scoreFormat: session.$1,
    titles: session.$3,
    day: localDay(now),
    // read, not watched: stopping a seed hides its picks at once, and the
    // next draw (tomorrow, or a refresh) gives its slot to another title
    leaveOut: ref.read(mutedSeedsProvider),
  );
  final (recommendations, c) = await (
    ref.read(anilistClientProvider).fetchRecommendations([for (final s in seeds) s.id]),
    cross(),
  ).wait;
  final picks = buildPicks(
    seeds,
    recommendations,
    entries: entries,
    type: mode.mediaType,
    showAdult: session.$2,
    scoreFormat: session.$1,
    titles: session.$3,
    crossSeeds: c.seeds,
    relations: c.relations,
  );
  return ForYou(coldStart: false, scored: scored, seeds: seeds, crossSeeds: c.seeds, picks: picks);
});

/// Ids kept on the device: picks hidden with Not this, and muted seeds.
class IdSet extends Notifier<Set<int>> {
  IdSet(this.key);

  final String key;

  @override
  Set<int> build() => {for (final s in ref.read(prefsProvider).readSet(key)) ?int.tryParse(s)};

  void add(int id) {
    state = {...state, id};
    unawaited(ref.read(prefsProvider).addToSet(key, '$id'));
  }

  void remove(int id) {
    state = {...state}..remove(id);
    unawaited(ref.read(prefsProvider).removeFromSet(key, '$id'));
  }
}

/// Picks hidden with Not this; they don't come back.
final dismissedPicksProvider = NotifierProvider<IdSet, Set<int>>(() => IdSet(PrefKeys.forYouDismissed));

/// Seeds swiped away: their picks leave with them.
final mutedSeedsProvider = NotifierProvider<IdSet, Set<int>>(() => IdSet(PrefKeys.forYouMuted));

/// "Tune picks", kept on the device.
class TuneNotifier extends Notifier<Tune> {
  @override
  Tune build() {
    try {
      return Tune.fromJson(jsonDecode(ref.read(prefsProvider).getString(PrefKeys.forYouTune) ?? 'null'));
    } on FormatException {
      return const Tune();
    }
  }

  void set(Tune next) {
    state = next;
    unawaited(ref.read(prefsProvider).setString(PrefKeys.forYouTune, jsonEncode(next.toJson())));
  }

  void toggleGenre(String genre) {
    final hidden = state.hiddenGenres;
    set(
      state.copyWith(
        hiddenGenres: hidden.contains(genre)
            ? [
                for (final g in hidden)
                  if (g != genre) g,
              ]
            : [...hidden, genre],
      ),
    );
  }

  void reset() => set(const Tune());
}

final tuneProvider = NotifierProvider<TuneNotifier, Tune>(TuneNotifier.new);

/// The picks to show: kept by [tune], not hidden, and recommended by at least
/// one seed that isn't muted.
List<Pick> visiblePicks(ForYou data, Set<int> dismissed, Set<int> muted, [Tune tune = const Tune()]) => [
  for (final p in tunePicks(data.picks, tune))
    if (!dismissed.contains(p.title.id) && p.seedIds.any((id) => !muted.contains(id))) p,
];
