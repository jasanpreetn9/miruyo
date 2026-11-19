// Browse's state, ported from apps/web/src/lib/browse/params.ts. The state
// round-trips through a query string, so "See all" links (and deep links)
// open Browse with its filters set.

import '../../core/anilist/types.dart';

enum BrowseSort {
  popularity('Popularity', 'POPULARITY_DESC'),
  score('Score', 'SCORE_DESC'),
  trending('Trending', 'TRENDING_DESC'),
  newest('Newest', 'START_DATE_DESC');

  const BrowseSort(this.label, this.anilist);
  final String label;
  final String anilist;
}

/// 3 across, or the compact list (pinch to switch).
enum BrowseDensity { three, list }

typedef Option = ({String key, String label});

const animeFormats = <Option>[
  (key: 'TV', label: 'TV'),
  (key: 'MOVIE', label: 'Movie'),
  (key: 'OVA', label: 'OVA'),
  (key: 'ONA', label: 'ONA'),
  (key: 'TV_SHORT', label: 'TV Short'),
  (key: 'SPECIAL', label: 'Special'),
];

/// Manhwa and manhua aren't AniList formats; they're manga from Korea and
/// China, so they live under Country of origin instead.
const mangaFormats = <Option>[
  (key: 'MANGA', label: 'Manga'),
  (key: 'NOVEL', label: 'Light novel'),
  (key: 'ONE_SHOT', label: 'One-shot'),
];

const statuses = <Option>[
  (key: 'RELEASING', label: 'Releasing'),
  (key: 'FINISHED', label: 'Finished'),
  (key: 'NOT_YET_RELEASED', label: 'Not yet released'),
  (key: 'HIATUS', label: 'Hiatus'),
  (key: 'CANCELLED', label: 'Cancelled'),
];

const countries = <({String key, String label, String long})>[
  (key: 'JP', label: 'JP', long: 'Japan'),
  (key: 'KR', label: 'KR', long: 'Korea (manhwa)'),
  (key: 'CN', label: 'CN', long: 'China (manhua)'),
];

const maxScore = 10.0;

List<Option> formatsFor({required bool isAnime}) => isAnime ? animeFormats : mangaFormats;

double _clampScore(double v) => !v.isFinite ? 0 : ((v * 2).round() / 2).clamp(0, maxScore).toDouble();

class BrowseState {
  const BrowseState({
    this.q = '',
    this.genres = const [],
    this.tags = const [],
    this.notGenres = const [],
    this.notTags = const [],
    this.formats = const [],
    this.status = '',
    this.season,
    this.year,
    this.country = '',
    this.scoreMin = 0,
    this.scoreMax = maxScore,
    this.hideOnList = false,
    this.sort = BrowseSort.popularity,
  });

  final String q;
  final List<String> genres;
  final List<String> tags;

  /// Genres and tags a title mustn't have (?not_genre=Romance).
  final List<String> notGenres;
  final List<String> notTags;

  /// AniList MediaFormat values.
  final List<String> formats;

  /// AniList MediaStatus; '' = any.
  final String status;

  /// Anime only.
  final MediaSeason? season;
  final int? year;

  /// Manga only.
  final String country;

  /// 0–10 in half steps; 0 and 10 mean "no bound".
  final double scoreMin;
  final double scoreMax;
  final bool hideOnList;
  final BrowseSort sort;

  /// Reads state from query parameters. Unknown or mode-inappropriate values
  /// are dropped, so a stale link can't make an impossible query.
  factory BrowseState.fromQuery(Map<String, List<String>> params, {required bool isAnime}) {
    String? one(String k) => params[k]?.firstOrNull;
    List<String> all(String k) => params[k] ?? const [];
    final formatKeys = {for (final f in formatsFor(isAnime: isAnime)) f.key};
    final statusKeys = {for (final s in statuses) s.key};
    final countryKeys = {for (final c in countries) c.key};
    final min = _clampScore(double.tryParse(one('min') ?? '') ?? 0);
    final max = _clampScore(double.tryParse(one('max') ?? '') ?? maxScore);
    final year = int.tryParse(one('year') ?? '');
    final season = MediaSeason.parse(one('season'));
    final genres = all('genre');
    final tags = all('tag');
    return BrowseState(
      q: one('q') ?? '',
      genres: genres,
      tags: tags,
      // in and out at once can't both hold: in wins
      notGenres: all('not_genre').where((g) => !genres.contains(g)).toList(),
      notTags: all('not_tag').where((t) => !tags.contains(t)).toList(),
      formats: all('format').where(formatKeys.contains).toList(),
      status: statusKeys.contains(one('status')) ? one('status')! : '',
      season: isAnime ? season : null,
      year: isAnime && year != null && year > 1900 ? year : null,
      country: !isAnime && countryKeys.contains(one('country')) ? one('country')! : '',
      scoreMin: min < max ? min : max,
      scoreMax: min < max ? max : min,
      hideOnList: one('hide') == '1',
      sort: BrowseSort.values.where((s) => s.name == one('sort')).firstOrNull ?? BrowseSort.popularity,
    );
  }

  /// The query for this state, leaving defaults out so links stay short.
  Map<String, List<String>> toQuery() => {
    if (q.trim().isNotEmpty) 'q': [q.trim()],
    if (genres.isNotEmpty) 'genre': genres,
    if (tags.isNotEmpty) 'tag': tags,
    if (notGenres.isNotEmpty) 'not_genre': notGenres,
    if (notTags.isNotEmpty) 'not_tag': notTags,
    if (formats.isNotEmpty) 'format': formats,
    if (status.isNotEmpty) 'status': [status],
    if (season != null) 'season': [season!.api],
    if (year != null) 'year': ['$year'],
    if (country.isNotEmpty) 'country': [country],
    if (scoreMin > 0) 'min': ['$scoreMin'],
    if (scoreMax < 10) 'max': ['$scoreMax'],
    if (hideOnList) 'hide': ['1'],
    if (sort != BrowseSort.popularity) 'sort': [sort.name],
  };

  /// This state as it would read in the other mode (season/year vs. country,
  /// formats).
  BrowseState forMode({required bool isAnime}) => BrowseState.fromQuery(toQuery(), isAnime: isAnime);

  /// Filters only, not the search text or sort.
  BrowseState withoutFilters() => BrowseState(q: q, sort: sort);

  bool get hasFilters => withoutFilters().toQuery().length != toQuery().length;

  BrowseState copyWith({
    String? q,
    List<String>? genres,
    List<String>? tags,
    List<String>? notGenres,
    List<String>? notTags,
    List<String>? formats,
    String? status,
    MediaSeason? season,
    bool clearSeason = false,
    int? year,
    bool clearYear = false,
    String? country,
    double? scoreMin,
    double? scoreMax,
    bool? hideOnList,
    BrowseSort? sort,
  }) => BrowseState(
    q: q ?? this.q,
    genres: genres ?? this.genres,
    tags: tags ?? this.tags,
    notGenres: notGenres ?? this.notGenres,
    notTags: notTags ?? this.notTags,
    formats: formats ?? this.formats,
    status: status ?? this.status,
    season: clearSeason ? null : (season ?? this.season),
    year: clearYear ? null : (year ?? this.year),
    country: country ?? this.country,
    scoreMin: scoreMin ?? this.scoreMin,
    scoreMax: scoreMax ?? this.scoreMax,
    hideOnList: hideOnList ?? this.hideOnList,
    sort: sort ?? this.sort,
  );

  /// AniList variables for browseQuery. Unset filters are left out entirely:
  /// AniList answers `format_in: null` with a 500 and a null score bound
  /// with a 400.
  Json toVariables({
    required MediaType type,
    required bool signedIn,
    required bool showAdult,
    int page = 1,
    int perPage = 30,
  }) {
    final isAnime = type == MediaType.anime;
    return {
      'page': page,
      'perPage': perPage,
      'type': type.api,
      if (q.trim().isNotEmpty) 'search': q.trim(),
      if (genres.isNotEmpty) 'genres': genres,
      if (tags.isNotEmpty) 'tags': tags,
      if (notGenres.isNotEmpty) 'notGenres': notGenres,
      if (notTags.isNotEmpty) 'notTags': notTags,
      if (formats.isNotEmpty) 'formats': formats,
      if (status.isNotEmpty) 'status': status,
      if (isAnime && season != null) 'season': season!.api,
      if (isAnime && year != null) 'seasonYear': year,
      if (!isAnime && country.isNotEmpty) 'country': country,
      // AniList's bounds are exclusive and on a 100-point scale
      if (scoreMin > 0) 'scoreAbove': (scoreMin * 10).round() - 1,
      if (scoreMax < 10) 'scoreBelow': (scoreMax * 10).round() + 1,
      if (signedIn && hideOnList) 'onList': false,
      if (!showAdult) 'isAdult': false,
      'sort': [sort.anilist],
    };
  }

  @override
  bool operator ==(Object other) => other is BrowseState && _key == other._key;

  @override
  int get hashCode => _key.hashCode;

  String get _key => toQuery().toString();
}

/// A removable chip for one active filter ("chips mirror state").
class FilterChipSpec {
  const FilterChipSpec(this.key, this.label, this.without);
  final String key;
  final String label;

  /// The state with just this filter removed.
  final BrowseState without;
}

String _score(double n) => n.toStringAsFixed(1);

List<FilterChipSpec> activeFilters(BrowseState s, {required bool isAnime}) => [
  for (final g in s.genres) FilterChipSpec('genre:$g', g, s.copyWith(genres: [...s.genres]..remove(g))),
  for (final t in s.tags) FilterChipSpec('tag:$t', t, s.copyWith(tags: [...s.tags]..remove(t))),
  for (final g in s.notGenres)
    FilterChipSpec('not_genre:$g', 'Not $g', s.copyWith(notGenres: [...s.notGenres]..remove(g))),
  for (final t in s.notTags) FilterChipSpec('not_tag:$t', 'Not $t', s.copyWith(notTags: [...s.notTags]..remove(t))),
  if (s.season != null || s.year != null)
    FilterChipSpec(
      'season',
      [
        if (s.season != null) s.season!.api[0] + s.season!.api.substring(1).toLowerCase(),
        if (s.year != null) '${s.year}',
      ].join(' '),
      s.copyWith(clearSeason: true, clearYear: true),
    ),
  if (s.country.isNotEmpty)
    FilterChipSpec('country', countries.firstWhere((c) => c.key == s.country).long, s.copyWith(country: '')),
  for (final f in s.formats)
    FilterChipSpec(
      'format:$f',
      formatsFor(isAnime: isAnime).where((x) => x.key == f).firstOrNull?.label ?? f,
      s.copyWith(formats: [...s.formats]..remove(f)),
    ),
  if (s.status.isNotEmpty)
    FilterChipSpec(
      'status',
      statuses.where((x) => x.key == s.status).firstOrNull?.label ?? s.status,
      s.copyWith(status: ''),
    ),
  if (s.scoreMin > 0 || s.scoreMax < maxScore)
    FilterChipSpec(
      'score',
      s.scoreMax < maxScore ? 'Score ${_score(s.scoreMin)}–${_score(s.scoreMax)}' : 'Score ≥ ${_score(s.scoreMin)}',
      s.copyWith(scoreMin: 0, scoreMax: maxScore),
    ),
  if (s.hideOnList) FilterChipSpec('hide', 'Not on my list', s.copyWith(hideOnList: false)),
];

/// What Browse calls itself when a "See all" opened it ("Trending anime"),
/// or null for plain browsing and searches.
String? browseTitle(BrowseState s, {required bool isAnime}) {
  if (s.q.isNotEmpty) return null;
  final noun = isAnime ? 'anime' : 'manga';
  if (s.status == 'NOT_YET_RELEASED') return 'Upcoming $noun';
  return switch (s.sort) {
    BrowseSort.trending => 'Trending $noun',
    BrowseSort.score => 'Top-rated $noun',
    BrowseSort.newest => 'Newest $noun',
    _ when s.status == 'RELEASING' => 'Popular ${isAnime ? 'airing' : 'releasing'} $noun',
    _ => null,
  };
}

/// A ready-made list above the results, like AniList's search page.
typedef BrowsePreset = ({String key, String label, BrowseState state});

/// The all-time popular (plain Browse), trending, top rated, what's out now
/// and what's coming.
List<BrowsePreset> browsePresets({required bool isAnime}) => [
  (key: 'popular', label: 'All-time popular', state: const BrowseState()),
  (key: 'trending', label: 'Trending', state: const BrowseState(sort: BrowseSort.trending)),
  (key: 'top', label: 'Top rated', state: const BrowseState(sort: BrowseSort.score)),
  (key: 'airing', label: isAnime ? 'Airing now' : 'Releasing', state: const BrowseState(status: 'RELEASING')),
  (key: 'upcoming', label: 'Upcoming', state: const BrowseState(status: 'NOT_YET_RELEASED')),
];

/// The preset [s] is exactly, or null.
String? activePreset(BrowseState s, {required bool isAnime}) =>
    browsePresets(isAnime: isAnime).where((p) => p.state == s).firstOrNull?.key;

/// Results in a ranked order (by score, popularity or trending, with no
/// search text deciding it) carry their place: #1, #2…
bool isRanked(BrowseState s) => s.q.trim().isEmpty && s.sort != BrowseSort.newest;

/// AniList stops counting at 5000, so that reads as "5,000+".
String formatMatchCount(int n) {
  final digits = (n >= 5000 ? 5000 : n).toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+$)'), (_) => ',');
  return n >= 5000 ? '$digits+' : digits;
}
