// The title page's content, ported from apps/web/src/lib/page-data/detail.ts.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anilist/errors.dart';
import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/cover_color.dart';
import '../../core/catalog/humanize.dart';
import '../../core/catalog/links.dart';
import '../../core/catalog/title.dart';
import '../../core/list/list_entry.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';

class InfoRow {
  const InfoRow(this.label, this.value, {this.href});
  final String label;
  final String value;

  /// Where the value leads in miruyo (the studio's page).
  final String? href;
}

class Person {
  const Person({required this.id, required this.name, required this.role, this.image});
  final int id;
  final String name;

  /// Character role (Main / Supporting) or staff role (Story & Art).
  final String role;
  final String? image;
}

class CharacterCard extends Person {
  const CharacterCard({required super.id, required super.name, required super.role, super.image, this.voice});

  /// The Japanese voice actor, for anime.
  final Person? voice;
}

class RelationCard {
  const RelationCard({
    required this.id,
    required this.relation,
    required this.kind,
    required this.title,
    required this.meta,
    required this.colors,
    this.cover,
  });

  final int id;

  /// "Side story".
  final String relation;

  /// The raw relationType, for its label colour.
  final String kind;
  final String title;
  final String meta;
  final CoverColors colors;
  final String? cover;
}

class TagChip {
  const TagChip({required this.name, required this.rank, required this.spoiler, this.description});

  final String name;

  /// How well it fits, 0–100.
  final int rank;

  /// Gives away the story: hidden until asked for.
  final bool spoiler;
  final String? description;
}

class LinkChip {
  const LinkChip({
    required this.id,
    required this.site,
    required this.url,
    required this.detail,
    this.icon,
    this.color,
  });

  final int id;
  final String site;
  final Uri url;

  /// "Thai", "Muse Asia": what tells two links to one site apart.
  final String detail;

  /// The site's logo (https), or null for the generic icon.
  final Uri? icon;

  /// The logo's backdrop: the site's colour as plain hex, or null.
  final String? color;
}

class DetailContent {
  const DetailContent({
    required this.title,
    required this.overline,
    required this.altTitles,
    this.synonyms = const [],
    this.tags = const [],
    this.watch = const [],
    this.links = const [],
    required this.rank,
    required this.members,
    required this.info,
    required this.characters,
    required this.authors,
    required this.relations,
    required this.recommendations,
    required this.trailer,
    required this.entry,
    required this.isFavourite,
  });

  final Title title;

  /// "TV · Fall 2026 · Madhouse" / "Manga · 2023 – present".
  final String overline;

  /// Other names for the title, not repeating the main one.
  final String altTitles;

  /// Further names (translations, abbreviations), not repeating any of the above.
  final List<String> synonyms;

  /// Best fit first; 18+ tags only when the account shows adult content.
  final List<TagChip> tags;

  /// Where to watch (anime) or read (manga) it.
  final List<LinkChip> watch;

  /// Official site and socials.
  final List<LinkChip> links;
  final ({String value, String label})? rank;
  final String members;
  final List<InfoRow> info;
  final List<CharacterCard> characters;

  /// Manga: the people credited with story and art.
  final List<Person> authors;
  final List<RelationCard> relations;
  final List<Title> recommendations;
  final Uri? trailer;
  final AniListSavedEntry? entry;
  final bool isFavourite;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// 912345 → "912k", 1234567 → "1.2M".
String formatCompact(int? n) {
  if (n == null) return '—';
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1).replaceFirst(RegExp(r'\.0$'), '')}M';
  if (n >= 1000) return '${(n / 1000).round()}k';
  return '$n';
}

/// SIDE_STORY → "Side story", LIGHT_NOVEL → "Light novel".
String humanizeEnum(String? value) {
  if (value == null || value.isEmpty) return '';
  final s = value.toLowerCase().replaceAll('_', ' ');
  return s[0].toUpperCase() + s.substring(1);
}

String _monthYear(AniListDate d) {
  if (d.year == null) return '';
  return d.month != null ? '${_months[d.month! - 1]} ${d.year}' : '${d.year}';
}

String _two(int n) => n.toString().padLeft(2, '0');

/// "Fri 23:00" in the device's timezone.
String formatAiring(int unixSeconds) {
  final d = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  return '${_days[d.weekday - 1]} ${_two(d.hour)}:${_two(d.minute)}';
}

/// "Fri, Oct 9 · 23:00": the countdown's full local date and time.
String formatAiringLong(int unixSeconds) {
  final d = DateTime.fromMillisecondsSinceEpoch(unixSeconds * 1000);
  return '${_days[d.weekday - 1]}, ${_months[d.month - 1]} ${d.day} · ${_two(d.hour)}:${_two(d.minute)}';
}

const _relationOrder = [
  'SOURCE',
  'PREQUEL',
  'SEQUEL',
  'PARENT',
  'SIDE_STORY',
  'ADAPTATION',
  'ALTERNATIVE',
  'SPIN_OFF',
  'SUMMARY',
  'COMPILATION',
  'CONTAINS',
  'OTHER',
  'CHARACTER',
];

int _relationRank(String type) {
  final i = _relationOrder.indexOf(type);
  return i < 0 ? 99 : i;
}

/// What a relation is, for ordering and its label. AniList often files an
/// anime's original novel or manga as ADAPTATION rather than SOURCE; from an
/// anime, an adaptation that isn't itself anime is the source.
String relationKind(String relationType, MediaType mediaType, MediaType nodeType) =>
    relationType == 'ADAPTATION' && mediaType == MediaType.anime && nodeType != MediaType.anime
    ? 'SOURCE'
    : relationType;

/// Sortable start date; undated relations go last within their kind.
int _startKey(Object? date) {
  final d = date is Json ? date : null;
  final year = (d?['year'] as num?)?.toInt();
  if (year == null) return 99999999;
  return year * 10000 + ((d?['month'] as num?)?.toInt() ?? 12) * 100 + ((d?['day'] as num?)?.toInt() ?? 31);
}

Uri? _trailerUrl(Json? trailer) {
  final id = trailer?['id'] as String?;
  if (id == null || id.isEmpty) return null;
  return switch (trailer?['site']) {
    'youtube' => Uri.https('www.youtube.com', '/watch', {'v': id}),
    'dailymotion' => Uri.https('www.dailymotion.com', '/video/$id'),
    _ => null,
  };
}

List<Json> _edges(Json media, String key) =>
    (((media[key] as Json?)?['edges'] as List?) ?? const []).whereType<Json>().toList();

/// Story / art credits: who a manga reader means by "author".
List<Person> _authorsOf(Json media) => [
  for (final e in _edges(media, 'staff'))
    if (RegExp('story|art|original creator', caseSensitive: false).hasMatch('${e['role']}') &&
        !RegExp('assistant', caseSensitive: false).hasMatch('${e['role']}'))
      Person(
        id: (e['node'] as Json)['id'] as int,
        name: ((e['node'] as Json)['name'] as Json?)?['full'] as String? ?? '',
        role: e['role'] as String? ?? '',
        image: ((e['node'] as Json)['image'] as Json?)?['medium'] as String?,
      ),
];

final _hexColor = RegExp(r'^#[0-9a-f]{6}$', caseSensitive: false);

/// A title's links, the viewer's likeliest language first (none given, then English).
List<LinkChip> _linkChips(List<Json> links) {
  int order(Object? language) => language == null || language == '' ? 0 : (language == 'English' ? 1 : 2);
  // a stable sort: AniList's order within each language
  final sorted = [
    for (final group in [0, 1, 2])
      for (final l in links)
        if (l['isDisabled'] != true && order(l['language']) == group) l,
  ];
  return [
    for (final l in sorted)
      if (externalUrl(l['url'] as String?) case final url?)
        LinkChip(
          id: (l['id'] as num).toInt(),
          site: l['site'] as String? ?? '',
          url: url,
          detail: [
            if (l['language'] case final String language when language.isNotEmpty && language != 'English') language,
            if (l['notes'] case final String notes when notes.isNotEmpty) notes,
          ].join(' · '),
          icon: switch (externalUrl(l['icon'] as String?)) {
            final icon? when icon.scheme == 'https' => icon,
            _ => null,
          },
          color: switch (l['color']) {
            final String color when _hexColor.hasMatch(color) => color,
            _ => null,
          },
        ),
  ];
}

/// Builds the title page from detailQuery. 18+ tags show only when [adult]
/// (the account's adult-content setting) is on.
DetailContent createDetailContent(
  Json raw, {
  TitlePreference titles = TitlePreference.userPreferred,
  bool adult = false,
}) {
  final media = AniListMedia.fromJson(raw);
  final isAnime = media.type == MediaType.anime;
  final savedJson = raw['mediaListEntry'] as Json?;
  final saved = savedJson == null || savedJson['id'] == null ? null : AniListSavedEntry.fromJson(savedJson);
  final title = adaptMedia(
    media,
    entry: saved == null ? null : (status: saved.status, progress: saved.progress),
    titles: titles,
  );
  final authors = _authorsOf(raw);
  final studio = media.studios.firstOrNull;
  final start = AniListDate.fromJson(raw['startDate'] as Json?);
  final end = AniListDate.fromJson(raw['endDate'] as Json?);

  // names that differ only in case ("ONE PIECE" / "One Piece") count as one
  final known = {title.title.toLowerCase()};
  final names = <String>[];
  for (final n in [media.title.english, media.title.romaji, media.title.native]) {
    if (n == null || n.isEmpty || !known.add(n.toLowerCase())) continue;
    names.add(n);
  }
  final synonyms = [
    for (final n in {for (final s in (raw['synonyms'] as List? ?? const []).whereType<String>()) s.trim()})
      if (n.isNotEmpty && !known.contains(n.toLowerCase())) n,
  ];
  final rawLinks = (raw['externalLinks'] as List? ?? const []).whereType<Json>().toList();
  final links = _linkChips(rawLinks);
  final linkType = {for (final l in rawLinks) (l['id'] as num).toInt(): l['type']};
  final tags = [
    for (final t in (raw['tags'] as List? ?? const []).whereType<Json>())
      if (adult || t['isAdult'] != true)
        TagChip(
          name: t['name'] as String? ?? '',
          rank: (t['rank'] as num?)?.toInt() ?? 0,
          spoiler: t['isMediaSpoiler'] == true || t['isGeneralSpoiler'] == true,
          description: t['description'] as String?,
        ),
  ];
  // best fit first; ties keep AniList's order
  final byRank = [for (final (i, t) in tags.indexed) (i, t)]
    ..sort((a, b) => b.$2.rank != a.$2.rank ? b.$2.rank.compareTo(a.$2.rank) : a.$1.compareTo(b.$1));

  final started = _monthYear(start);
  final ended = _monthYear(end);
  final span = media.status == 'RELEASING' && start.year != null
      ? '${start.year} – present'
      : start.year != null && end.year != null && end.year != start.year
      ? '${start.year} – ${end.year}'
      : start.year != null
      ? '${start.year}'
      : '';

  final overline = (isAnime ? [title.format, title.season ?? span, studio] : [title.format, span])
      .whereType<String>()
      .where((s) => s.isNotEmpty)
      .join(' · ');

  final rankings = ((raw['rankings'] as List?) ?? const []).whereType<Json>();
  final rated = rankings.where((r) => r['type'] == 'RATED' && r['allTime'] == true).firstOrNull;
  final popular = rankings.where((r) => r['type'] == 'POPULAR' && r['allTime'] == true).firstOrNull;
  final best = rated ?? popular;

  final next = media.nextAiringEpisode;
  final source = raw['source'] as String?;
  final info = isAnime
      ? [
          InfoRow('Format', [title.format, if (media.duration != null) '${media.duration} min'].join(' · ')),
          InfoRow('Episodes', media.episodes != null ? '${media.episodes}' : 'Unknown'),
          InfoRow('Status', humanizeStatus(media.status)),
          if (media.season != null && media.seasonYear != null)
            InfoRow('Season', '${humanizeSeason(media.season!)} ${media.seasonYear}'),
          if (studio != null) InfoRow('Studio', studio, href: _studioHrefOf(raw)),
          if (source != null) InfoRow('Source', humanizeEnum(source)),
          if (next != null) InfoRow('Next episode', 'EP ${next.episode} · ${formatAiring(next.airingAt)}'),
        ]
      : [
          InfoRow('Format', humanizeFormat(media.format)),
          InfoRow(
            'Chapters',
            media.chapters != null
                ? '${media.chapters}'
                : media.status == 'RELEASING'
                ? 'Ongoing'
                : 'Unknown',
          ),
          if (media.volumes != null) InfoRow('Volumes', '${media.volumes}'),
          InfoRow('Status', humanizeStatus(media.status)),
          if (authors.isNotEmpty) InfoRow('Story & Art', {for (final a in authors) a.name}.join(', ')),
          if (started.isNotEmpty) InfoRow('Started', started),
          if (ended.isNotEmpty && media.status == 'FINISHED') InfoRow('Finished', ended),
        ];

  // source first, then prequels, sequels and the rest; oldest first within each
  String kindOf(Json edge) =>
      relationKind('${edge['relationType']}', media.type, MediaType.parse((edge['node'] as Json)['type']));
  final relationEdges = _edges(raw, 'relations')
    ..sort((a, b) {
      final byKind = _relationRank(kindOf(a)).compareTo(_relationRank(kindOf(b)));
      return byKind != 0
          ? byKind
          : _startKey((a['node'] as Json)['startDate']).compareTo(_startKey((b['node'] as Json)['startDate']));
    });
  final relations = [
    for (final edge in relationEdges)
      () {
        final n = edge['node'] as Json;
        final t = n['title'] as Json? ?? const {};
        final name =
            (titles == TitlePreference.english ? (t['english'] ?? t['romaji']) : (t['userPreferred'] ?? t['romaji']))
                as String? ??
            'Untitled';
        final type = MediaType.parse(n['type']);
        final length = type == MediaType.anime
            ? (n['episodes'] != null ? '${n['episodes']} eps' : '')
            : (n['chapters'] != null ? '${n['chapters']} ch' : '');
        final cover = n['coverImage'] as Json?;
        return RelationCard(
          id: n['id'] as int,
          relation: humanizeEnum(kindOf(edge)),
          kind: kindOf(edge),
          title: name,
          meta: [
            humanizeFormat(n['format'] as String?),
            length,
            if (n['seasonYear'] != null) '${n['seasonYear']}',
          ].where((x) => x.isNotEmpty && x != 'Unknown').join(' · '),
          colors: CoverColors.fromHex(cover?['color'] as String?),
          cover: cover?['large'] as String?,
        );
      }(),
  ];

  return DetailContent(
    title: title,
    overline: overline,
    altTitles: names.join(' · '),
    synonyms: synonyms,
    tags: [for (final (_, t) in byRank) t],
    watch: [
      for (final l in links)
        if (linkType[l.id] == 'STREAMING') l,
    ],
    links: [
      for (final l in links)
        if (linkType[l.id] != 'STREAMING') l,
    ],
    rank: best == null
        ? null
        : (
            value: '#${best['rank']}',
            label: best['type'] == 'RATED' ? 'Highest rated all time' : 'Most popular all time',
          ),
    members: formatCompact(media.popularity),
    info: info,
    characters: [
      for (final e in _edges(raw, 'characters'))
        CharacterCard(
          id: (e['node'] as Json)['id'] as int,
          name: ((e['node'] as Json)['name'] as Json?)?['full'] as String? ?? '',
          role: humanizeEnum(e['role'] as String?),
          image: ((e['node'] as Json)['image'] as Json?)?['medium'] as String?,
          voice: switch ((e['voiceActors'] as List?)?.whereType<Json>().firstOrNull) {
            final va? => Person(
              id: va['id'] as int,
              name: (va['name'] as Json?)?['full'] as String? ?? '',
              role: 'Japanese',
              image: (va['image'] as Json?)?['medium'] as String?,
            ),
            _ => null,
          },
        ),
    ],
    authors: authors,
    relations: relations,
    recommendations: [
      for (final n in (((raw['recommendations'] as Json?)?['nodes'] as List?) ?? const []).whereType<Json>())
        if (n['mediaRecommendation'] is Json)
          adaptMedia(AniListMedia.fromJson(n['mediaRecommendation'] as Json), titles: titles),
    ],
    trailer: _trailerUrl(raw['trailer'] as Json?),
    entry: saved,
    isFavourite: raw['isFavourite'] == true,
  );
}

/// Thrown when AniList has no title with that id.
class TitleNotFound implements Exception {
  const TitleNotFound();
}

final detailProvider = FutureProvider.autoDispose.family<DetailContent, int>((ref, id) async {
  ref.cacheFor(screenCache);
  final session = ref.watch(sessionProvider.select((s) => (s.signedIn, s.titles, s.authState, s.showAdultContent)));
  final store = ref.read(listStoreProvider.notifier);
  final since = store.stamp();
  try {
    final raw = await ref.watch(anilistClientProvider).fetchDetail(id, signedIn: session.$1);
    final content = createDetailContent(raw, titles: session.$2, adult: session.$4);
    if (session.$1 && content.entry != null) store.seed([ListEntry.fromSaved(content.entry!)], since: since);
    return content;
  } on AniListError catch (e) {
    if (e.kind == AniListErrorKind.api && e.status == 404) throw const TitleNotFound();
    rethrow;
  }
});

/// Favourites changed on this device, by kind and id, so a page served from
/// the screen cache shows the change.
class Favourites extends Notifier<Map<(FavouriteKind, int), bool>> {
  @override
  Map<(FavouriteKind, int), bool> build() => const {};

  /// Flips a favourite on AniList, optimistically. Resolves to whether
  /// AniList took it (and puts it back if not).
  Future<bool> toggle(FavouriteKind kind, int id, {required bool was}) async {
    state = {...state, (kind, id): !was};
    try {
      await ref.read(anilistClientProvider).toggleFavourite(kind, id);
      return true;
    } on Exception {
      state = {...state, (kind, id): was};
      return false;
    }
  }
}

final favouritesProvider = NotifierProvider<Favourites, Map<(FavouriteKind, int), bool>>(Favourites.new);

/// The main studio's page, from the title's studios (null without an id).
String? _studioHrefOf(Json raw) {
  final nodes = (raw['studios'] as Json?)?['nodes'] as List?;
  final id = (nodes?.firstOrNull as Json?)?['id'];
  return id is num ? '/studio/${id.toInt()}' : null;
}
