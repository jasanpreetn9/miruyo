import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/session.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/title.dart';
import '../../core/list/list_entry.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';
import '../../core/storage/prefs.dart';
import 'browse_params.dart';

class BrowseView {
  const BrowseView({
    this.state = const BrowseState(),
    this.results = const [],
    this.total = 0,
    this.page = 0,
    this.hasMore = false,
    this.loading = false,
    this.error,
    this.density = BrowseDensity.three,
  });

  final BrowseState state;
  final List<Title> results;

  /// How many titles match, as AniList counts them.
  final int total;
  final int page;
  final bool hasMore;

  /// A first page or the next page is on its way.
  final bool loading;
  final Object? error;
  final BrowseDensity density;

  /// Nothing to show yet: the first page is loading.
  bool get firstLoad => loading && results.isEmpty;

  BrowseView copyWith({
    BrowseState? state,
    List<Title>? results,
    int? total,
    int? page,
    bool? hasMore,
    bool? loading,
    Object? error,
    bool clearError = false,
    BrowseDensity? density,
  }) => BrowseView(
    state: state ?? this.state,
    results: results ?? this.results,
    total: total ?? this.total,
    page: page ?? this.page,
    hasMore: hasMore ?? this.hasMore,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    density: density ?? this.density,
  );
}

/// Search & browse: the filters, and the pages of results they match.
/// Search text is debounced (300ms); filter changes apply at once.
class BrowseController extends Notifier<BrowseView> {
  Timer? _debounce;

  /// Bumped on every new query, so a slow page for an old one is dropped.
  var _generation = 0;

  @override
  BrowseView build() {
    ref.onDispose(() => _debounce?.cancel());
    // a new mode or account changes what matches; start over
    ref.listen(modeProvider, (_, mode) {
      // always reload: the filters can read the same in both modes, but the
      // results never are
      state = state.copyWith(state: state.state.forMode(isAnime: mode.isAnime));
      _reload();
    });
    ref.listen(sessionProvider.select((s) => s.authState), (_, _) => _reload());
    final saved = ref.read(prefsProvider).getInt(PrefKeys.browseDensity);
    // 0 = the list; anything else (including the old 2-across) is the grid
    final density = saved == 0 ? BrowseDensity.list : BrowseDensity.three;
    Future.microtask(_reload);
    return BrowseView(loading: true, density: density);
  }

  /// Opens Browse with [next] (a link's filters, or an edit).
  void apply(BrowseState next) {
    if (next == state.state && state.results.isNotEmpty) return;
    state = state.copyWith(state: next);
    _reload();
  }

  void search(String q) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => apply(state.state.copyWith(q: q)));
  }

  void setDensity(BrowseDensity density) {
    state = state.copyWith(density: density);
    unawaited(ref.read(prefsProvider).setInt(PrefKeys.browseDensity, density == BrowseDensity.list ? 0 : 3));
  }

  Future<void> retry() => _reload();

  Future<void> _reload() async {
    final generation = ++_generation;
    state = state.copyWith(results: const [], page: 0, total: 0, hasMore: false, loading: true, clearError: true);
    await _load(1, generation);
  }

  Future<void> loadMore() async {
    if (state.loading || !state.hasMore || state.error != null) return;
    state = state.copyWith(loading: true);
    await _load(state.page + 1, _generation);
  }

  Future<void> _load(int page, int generation) async {
    final session = ref.read(sessionProvider);
    if (session.authState == AuthState.loading) return; // the session listener reloads
    final mode = ref.read(modeProvider);
    final store = ref.read(listStoreProvider.notifier);
    final since = store.stamp();
    try {
      final result = await ref
          .read(anilistClientProvider)
          .fetchBrowse(
            state.state.toVariables(
              type: mode.mediaType,
              signedIn: session.signedIn,
              showAdult: session.showAdultContent,
              page: page,
            ),
            signedIn: session.signedIn,
          );
      if (generation != _generation) return;
      final titles = [for (final m in result.media) adaptMedia(m, titles: session.titles)];
      if (session.signedIn) store.seed([for (final t in titles) ?ListEntry.fromTitle(t)], since: since);
      // pages can overlap when AniList's order shifts between requests
      final seen = {for (final t in state.results) t.id};
      state = state.copyWith(
        results: [...state.results, ...titles.where((t) => seen.add(t.id))],
        total: result.total,
        page: page,
        hasMore: result.hasNextPage,
        loading: false,
      );
    } catch (e) {
      // anything, not just AniListError: a response in a shape we didn't
      // expect should show the section's error, not break the screen
      if (generation != _generation) return;
      state = state.copyWith(loading: false, error: e);
    }
  }
}

final browseProvider = NotifierProvider<BrowseController, BrowseView>(BrowseController.new);

/// AniList's only adult genre: like 18+ tags, left out unless the account
/// allows adult content (as on the web).
const adultGenre = 'Hentai';

/// Genres for the filter sheet. Public, and cached for a day.
final genresProvider = FutureProvider<List<String>>((ref) async {
  final showAdult = ref.watch(sessionProvider.select((s) => s.showAdultContent));
  final data = await ref.watch(anilistClientProvider).fetchBrowseCollections();
  return [
    for (final g in (data['GenreCollection'] as List? ?? const []))
      if (showAdult || g != adultGenre) '$g',
  ];
});

/// AniList's tags for the filter sheet's tag search; 18+ ones only when the
/// account allows adult content, as on the web.
final tagsProvider = FutureProvider<List<String>>((ref) async {
  final showAdult = ref.watch(sessionProvider.select((s) => s.showAdultContent));
  final data = await ref.watch(anilistClientProvider).fetchBrowseCollections();
  return [
    for (final t in (data['MediaTagCollection'] as List? ?? const []).cast<Map<String, Object?>>())
      if (showAdult || t['isAdult'] != true) '${t['name']}',
  ];
});

/// Up to 8 tags containing [query], those starting with it first, leaving
/// out ones already [chosen].
List<String> matchTags(List<String> tags, String query, List<String> chosen) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return const [];
  final hits = tags.where((t) => !chosen.contains(t) && t.toLowerCase().contains(q)).toList();
  // a stable sort: AniList's order within each group
  final starts = hits.where((t) => t.toLowerCase().startsWith(q));
  final rest = hits.where((t) => !t.toLowerCase().startsWith(q));
  return [...starts, ...rest].take(8).toList();
}

/// Edit distance with adjacent swaps counted once ("frerien" → "frieren" is
/// 2: two letters moved; "teh" → "the" is 1).
int typoDistance(String a, String b) {
  final d = List.generate(a.length + 1, (i) => List<int>.filled(b.length + 1, 0));
  for (var i = 0; i <= a.length; i++) {
    d[i][0] = i;
  }
  for (var j = 0; j <= b.length; j++) {
    d[0][j] = j;
  }
  for (var i = 1; i <= a.length; i++) {
    for (var j = 1; j <= b.length; j++) {
      final cost = a[i - 1] == b[j - 1] ? 0 : 1;
      var best = math.min(math.min(d[i - 1][j] + 1, d[i][j - 1] + 1), d[i - 1][j - 1] + cost);
      if (i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]) best = math.min(best, d[i - 2][j - 2] + 1);
      d[i][j] = best;
    }
  }
  return d[a.length][b.length];
}

/// The run of words in [names] closest to [query] (as many words as the
/// query has), if it's close enough to be a misspelling of it: at most one
/// typo per three letters. Null when [query] is already one of them.
String? closestSpelling(String query, Iterable<String> names) {
  final q = query.trim().toLowerCase();
  if (q.length < 3) return null;
  final words = q.split(RegExp(r'\s+')).length;
  String? best;
  var bestDistance = 1 << 30;
  for (final name in names) {
    final parts = name.split(RegExp(r'[\s:,!?.]+')).where((w) => w.isNotEmpty).toList();
    for (var i = 0; i + words <= parts.length; i++) {
      final candidate = parts.sublist(i, i + words).join(' ');
      final distance = typoDistance(q, candidate.toLowerCase());
      if (distance == 0) return null;
      if (distance < bestDistance) {
        best = candidate;
        bestDistance = distance;
      }
    }
  }
  return bestDistance <= math.max(1, q.length ~/ 3) ? best : null;
}

/// The names of the most popular titles in a mode (three pages of 50,
/// fetched once a session), for "Did you mean". AniList's own search only
/// matches whole words, so it can't suggest a spelling itself.
final popularNamesProvider = FutureProvider.family<List<String>, Mode>((ref, mode) async {
  final session = ref.read(sessionProvider);
  final client = ref.read(anilistClientProvider);
  final names = <String>[];
  for (var page = 1; page <= 3; page++) {
    final result = await client.fetchBrowse({
      'page': page,
      'perPage': 50,
      'type': mode.mediaType.api,
      'isAdult': false,
      'sort': [BrowseSort.popularity.anilist],
    }, signedIn: session.signedIn);
    for (final m in result.media) {
      names.addAll([?m.title.romaji, ?m.title.english, ?m.title.userPreferred]);
    }
    if (!result.hasNextPage) break;
  }
  return names;
});

/// "Did you mean": for a search that found nothing, the closest spelling
/// among popular titles' names.
final didYouMeanProvider = FutureProvider.autoDispose.family<String?, String>((ref, q) async {
  final query = q.trim();
  if (query.length < 4) return null;
  final names = await ref.watch(popularNamesProvider(ref.watch(modeProvider)).future);
  return closestSpelling(query, names);
});

/// How many titles a draft of the filters would match, for the sheet's
/// Apply button. One-result queries, debounced by the caller.
final matchCountProvider = FutureProvider.autoDispose.family<int, BrowseState>((ref, draft) async {
  final session = ref.watch(sessionProvider);
  final mode = ref.watch(modeProvider);
  final result = await ref
      .watch(anilistClientProvider)
      .fetchBrowse(
        draft.toVariables(
          type: mode.mediaType,
          signedIn: session.signedIn,
          showAdult: session.showAdultContent,
          perPage: 1,
        ),
        signedIn: session.signedIn,
      );
  return result.total;
});

/// Shorthand for the active mode's title noun.
String nounFor(Mode mode) => mode.isAnime ? 'anime' : 'manga';
