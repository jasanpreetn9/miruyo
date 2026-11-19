// AniList response shapes, ported from apps/web/src/lib/anilist/types.ts.
// Only the fields the queries ask for; everything AniList may leave null is
// nullable here too.

typedef Json = Map<String, dynamic>;

/// AniList enums travel as their SCREAMING_CASE names; [api] is that name.
mixin ApiEnum on Enum {
  String get api;
}

T _parseEnum<T extends ApiEnum>(List<T> values, Object? raw, T fallback) {
  for (final v in values) {
    if (v.api == raw) return v;
  }
  return fallback;
}

T? _parseEnumOrNull<T extends ApiEnum>(List<T> values, Object? raw) {
  for (final v in values) {
    if (v.api == raw) return v;
  }
  return null;
}

enum MediaType with ApiEnum {
  anime('ANIME'),
  manga('MANGA');

  const MediaType(this.api);
  @override
  final String api;

  static MediaType parse(Object? raw) => _parseEnum(values, raw, anime);
}

enum MediaSeason with ApiEnum {
  winter('WINTER'),
  spring('SPRING'),
  summer('SUMMER'),
  fall('FALL');

  const MediaSeason(this.api);
  @override
  final String api;

  static MediaSeason? parse(Object? raw) => _parseEnumOrNull(values, raw);
}

enum MediaListStatus with ApiEnum {
  current('CURRENT'),
  planning('PLANNING'),
  completed('COMPLETED'),
  dropped('DROPPED'),
  paused('PAUSED'),
  repeating('REPEATING');

  const MediaListStatus(this.api);
  @override
  final String api;

  /// Anything unexpected falls back to CURRENT, as on the web (toListStatus).
  static MediaListStatus parse(Object? raw) => _parseEnum(values, raw, current);
}

enum ScoreFormat with ApiEnum {
  point100('POINT_100'),
  point10Decimal('POINT_10_DECIMAL'),
  point10('POINT_10'),
  point5('POINT_5'),
  point3('POINT_3');

  const ScoreFormat(this.api);
  @override
  final String api;

  static ScoreFormat parse(Object? raw) => _parseEnum(values, raw, point10Decimal);
}

/// AniList's UserTitleLanguage. The _STYLISED variants keep official casing.
enum TitleLanguage with ApiEnum {
  romaji('ROMAJI'),
  english('ENGLISH'),
  native('NATIVE'),
  romajiStylised('ROMAJI_STYLISED'),
  englishStylised('ENGLISH_STYLISED'),
  nativeStylised('NATIVE_STYLISED');

  const TitleLanguage(this.api);
  @override
  final String api;

  static TitleLanguage? parse(Object? raw) => _parseEnumOrNull(values, raw);
}

int? _int(Object? v) => v is num ? v.toInt() : null;
double? _double(Object? v) => v is num ? v.toDouble() : null;
List<Json> _list(Object? v) => v is List ? v.whereType<Json>().toList() : const [];

class AniListUser {
  const AniListUser({
    required this.id,
    required this.name,
    this.avatarLarge,
    this.avatarMedium,
    this.bannerImage,
    this.unreadNotificationCount = 0,
    this.scoreFormat,
    this.titleLanguage,
    this.displayAdultContent = false,
    this.airingNotifications,
    this.animeCustomLists = const [],
    this.mangaCustomLists = const [],
  });

  factory AniListUser.fromJson(Json j) {
    final avatar = j['avatar'] as Json?;
    final options = j['options'] as Json?;
    final listOptions = j['mediaListOptions'] as Json?;
    return AniListUser(
      id: _int(j['id'])!,
      name: j['name'] as String? ?? '',
      avatarLarge: avatar?['large'] as String?,
      avatarMedium: avatar?['medium'] as String?,
      bannerImage: j['bannerImage'] as String?,
      unreadNotificationCount: _int(j['unreadNotificationCount']) ?? 0,
      scoreFormat: listOptions == null ? null : ScoreFormat.parse(listOptions['scoreFormat']),
      titleLanguage: TitleLanguage.parse(options?['titleLanguage']),
      displayAdultContent: options?['displayAdultContent'] as bool? ?? false,
      airingNotifications: options?['airingNotifications'] as bool?,
      animeCustomLists: _names((listOptions?['animeList'] as Json?)?['customLists']),
      mangaCustomLists: _names((listOptions?['mangaList'] as Json?)?['customLists']),
    );
  }

  static List<String> _names(Object? raw) => [if (raw is List) ...raw.whereType<String>()];

  /// Every custom list's name, empty ones too, in the account's order.
  final List<String> animeCustomLists;
  final List<String> mangaCustomLists;

  List<String> customLists({required bool isAnime}) => isAnime ? animeCustomLists : mangaCustomLists;

  final int id;
  final String name;
  final String? avatarLarge;
  final String? avatarMedium;
  final String? bannerImage;
  final int unreadNotificationCount;
  final ScoreFormat? scoreFormat;
  final TitleLanguage? titleLanguage;
  final bool displayAdultContent;

  /// AniList notifies you when an episode of something you're watching airs.
  final bool? airingNotifications;

  AniListUser copyWith({
    int? unreadNotificationCount,
    ScoreFormat? scoreFormat,
    TitleLanguage? titleLanguage,
    bool? displayAdultContent,
    bool? airingNotifications,
  }) => AniListUser(
    id: id,
    name: name,
    avatarLarge: avatarLarge,
    avatarMedium: avatarMedium,
    bannerImage: bannerImage,
    unreadNotificationCount: unreadNotificationCount ?? this.unreadNotificationCount,
    scoreFormat: scoreFormat ?? this.scoreFormat,
    titleLanguage: titleLanguage ?? this.titleLanguage,
    displayAdultContent: displayAdultContent ?? this.displayAdultContent,
    airingNotifications: airingNotifications ?? this.airingNotifications,
    animeCustomLists: animeCustomLists,
    mangaCustomLists: mangaCustomLists,
  );
}

class AniListMediaTitle {
  const AniListMediaTitle({this.romaji, this.english, this.native, this.userPreferred});

  factory AniListMediaTitle.fromJson(Json? j) => AniListMediaTitle(
    romaji: j?['romaji'] as String?,
    english: j?['english'] as String?,
    native: j?['native'] as String?,
    userPreferred: j?['userPreferred'] as String?,
  );

  final String? romaji;
  final String? english;
  final String? native;
  final String? userPreferred;
}

class AniListCoverImage {
  const AniListCoverImage({this.extraLarge, this.large, this.medium, this.color});

  factory AniListCoverImage.fromJson(Json? j) => AniListCoverImage(
    extraLarge: j?['extraLarge'] as String?,
    large: j?['large'] as String?,
    medium: j?['medium'] as String?,
    color: j?['color'] as String?,
  );

  final String? extraLarge;
  final String? large;
  final String? medium;

  /// AniList's dominant cover colour, '#rrggbb'.
  final String? color;
}

class AniListNextAiringEpisode {
  const AniListNextAiringEpisode({required this.episode, required this.airingAt, required this.timeUntilAiring});

  factory AniListNextAiringEpisode.fromJson(Json j) => AniListNextAiringEpisode(
    episode: _int(j['episode']) ?? 0,
    airingAt: _int(j['airingAt']) ?? 0,
    timeUntilAiring: _int(j['timeUntilAiring']) ?? 0,
  );

  final int episode;

  /// Unix seconds.
  final int airingAt;
  final int timeUntilAiring;
}

/// The viewer's own list entry for a title, as feed queries attach it.
class AniListOwnEntry {
  const AniListOwnEntry({required this.id, required this.status, required this.progress, this.mediaId});

  factory AniListOwnEntry.fromJson(Json j) => AniListOwnEntry(
    id: _int(j['id'])!,
    mediaId: _int(j['mediaId']),
    status: MediaListStatus.parse(j['status']),
    progress: _int(j['progress']) ?? 0,
  );

  final int id;

  /// Set by queries that ask for it (listEntriesQuery); feed queries attach
  /// the entry to its media instead.
  final int? mediaId;
  final MediaListStatus status;
  final int progress;
}

class AniListMedia {
  const AniListMedia({
    required this.id,
    required this.type,
    required this.title,
    required this.coverImage,
    this.format,
    this.status,
    this.season,
    this.seasonYear,
    this.episodes,
    this.duration,
    this.chapters,
    this.volumes,
    this.averageScore,
    this.popularity,
    this.favourites,
    this.isAdult = false,
    this.description,
    this.genres = const [],
    this.countryOfOrigin,
    this.startYear,
    this.bannerImage,
    this.studios = const [],
    this.mainStudio,
    this.nextAiringEpisode,
    this.mediaListEntry,
    this.raw = const {},
  });

  factory AniListMedia.fromJson(Json j) {
    final next = j['nextAiringEpisode'] as Json?;
    final entry = j['mediaListEntry'] as Json?;
    return AniListMedia(
      id: _int(j['id'])!,
      type: MediaType.parse(j['type']),
      format: j['format'] as String?,
      status: j['status'] as String?,
      season: MediaSeason.parse(j['season']),
      seasonYear: _int(j['seasonYear']),
      episodes: _int(j['episodes']),
      duration: _int(j['duration']),
      chapters: _int(j['chapters']),
      volumes: _int(j['volumes']),
      averageScore: _int(j['averageScore']),
      popularity: _int(j['popularity']),
      favourites: _int(j['favourites']),
      isAdult: j['isAdult'] as bool? ?? false,
      title: AniListMediaTitle.fromJson(j['title'] as Json?),
      description: j['description'] as String?,
      genres: (j['genres'] as List?)?.whereType<String>().toList() ?? const [],
      countryOfOrigin: j['countryOfOrigin'] as String?,
      startYear: _int((j['startDate'] as Json?)?['year']),
      coverImage: AniListCoverImage.fromJson(j['coverImage'] as Json?),
      bannerImage: j['bannerImage'] as String?,
      studios: [for (final s in _list((j['studios'] as Json?)?['nodes'])) s['name'] as String? ?? ''],
      mainStudio: switch (_list((j['studios'] as Json?)?['nodes']).firstOrNull) {
        {'id': final num id, 'name': final String name} => (id: id.toInt(), name: name),
        _ => null,
      },
      nextAiringEpisode: next == null ? null : AniListNextAiringEpisode.fromJson(next),
      mediaListEntry: entry == null || entry['id'] == null ? null : AniListOwnEntry.fromJson(entry),
      raw: j,
    );
  }

  final int id;
  final MediaType type;
  final String? format;
  final String? status;
  final MediaSeason? season;
  final int? seasonYear;
  final int? episodes;
  final int? duration;
  final int? chapters;
  final int? volumes;

  /// 0–100.
  final int? averageScore;
  final int? popularity;
  final int? favourites;
  final bool isAdult;
  final AniListMediaTitle title;
  final String? description;
  final List<String> genres;

  /// "JP", "KR", "CN", "TW"…; on list collection results.
  final String? countryOfOrigin;

  /// The start date's year, on list collection results (manga have no
  /// seasonYear).
  final int? startYear;
  final AniListCoverImage coverImage;
  final String? bannerImage;

  /// Main studio names.
  final List<String> studios;

  /// The first main studio, with its id (for its page); null when AniList
  /// lists none, or the query didn't ask for ids.
  final ({int id, String name})? mainStudio;
  final AniListNextAiringEpisode? nextAiringEpisode;

  /// Only on queries that ask for it; null when the title isn't on the list.
  final AniListOwnEntry? mediaListEntry;

  /// The year it came out, as AniList's list filter reads it: its season's,
  /// or its start date's.
  int? get listYear => seasonYear ?? startYear;

  /// The JSON this came from, for query-specific extras (rankings, relations…)
  /// that screens read without a model of their own yet.
  final Json raw;
}

/// AniList's FuzzyDate: any part may be missing.
class AniListDate {
  const AniListDate({this.year, this.month, this.day});

  factory AniListDate.fromJson(Json? j) =>
      AniListDate(year: _int(j?['year']), month: _int(j?['month']), day: _int(j?['day']));

  factory AniListDate.fromDateTime(DateTime d) => AniListDate(year: d.year, month: d.month, day: d.day);

  /// A date with every part null: sending it clears the date on AniList.
  static const empty = AniListDate();

  final int? year;
  final int? month;
  final int? day;

  bool get isEmpty => year == null && month == null && day == null;

  Json toJson() => {'year': year, 'month': month, 'day': day};

  @override
  bool operator ==(Object other) =>
      other is AniListDate && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => Object.hash(year, month, day);
}

/// The list-entry fields SaveMediaListEntry returns (saveEntryMutation).
class AniListSavedEntry {
  const AniListSavedEntry({
    required this.id,
    required this.mediaId,
    required this.status,
    required this.progress,
    this.progressVolumes,
    this.score = 0,
    this.repeat = 0,
    this.notes,
    this.private = false,
    this.priority = 0,
    this.startedAt = AniListDate.empty,
    this.completedAt = AniListDate.empty,
    this.customLists,
  });

  factory AniListSavedEntry.fromJson(Json j) => AniListSavedEntry(
    id: _int(j['id'])!,
    mediaId: _int(j['mediaId'])!,
    status: MediaListStatus.parse(j['status']),
    progress: _int(j['progress']) ?? 0,
    progressVolumes: _int(j['progressVolumes']),
    score: _double(j['score']) ?? 0,
    repeat: _int(j['repeat']) ?? 0,
    notes: j['notes'] as String?,
    private: j['private'] as bool? ?? false,
    priority: _int(j['priority']) ?? 0,
    startedAt: AniListDate.fromJson(j['startedAt'] as Json?),
    completedAt: AniListDate.fromJson(j['completedAt'] as Json?),
    customLists: switch (j['customLists']) {
      final List lists => [
        for (final l in lists.whereType<Json>())
          if (l['name'] case final String name) (name: name, enabled: l['enabled'] == true),
      ],
      _ => null,
    },
  );

  /// Each custom list of the entry's type and whether it's on it; null with none.
  final List<({String name, bool enabled})>? customLists;

  final int id;
  final int mediaId;
  final MediaListStatus status;
  final int progress;
  final int? progressVolumes;

  /// In the viewer's own scoreFormat. 0 = not scored.
  final double score;
  final int repeat;
  final String? notes;
  final bool private;

  /// Up next order on Planning: higher comes first.
  final int priority;
  final AniListDate startedAt;
  final AniListDate completedAt;
}

/// One row of MediaListCollection: the full entry plus its media.
class CollectionEntry {
  const CollectionEntry({required this.entry, required this.updatedAt, required this.media});

  factory CollectionEntry.fromJson(Json j) => CollectionEntry(
    entry: AniListSavedEntry.fromJson(j),
    updatedAt: _int(j['updatedAt']) ?? 0,
    media: AniListMedia.fromJson(j['media'] as Json),
  );

  final AniListSavedEntry entry;

  /// Unix seconds.
  final int updatedAt;
  final AniListMedia media;
}

/// What can be a favourite on AniList, and the mutation's variable for it.
enum FavouriteKind {
  anime('animeId'),
  manga('mangaId'),
  character('characterId'),
  staff('staffId'),
  studio('studioId');

  const FavouriteKind(this.variable);

  final String variable;

  static FavouriteKind of(MediaType type) => type == MediaType.anime ? anime : manga;
}

/// How someone's roles are ordered: most popular first, or newest.
enum PersonSort {
  popularity('POPULARITY_DESC'),
  newest('START_DATE_DESC');

  const PersonSort(this.api);

  final String api;
}

/// One of your own lists on AniList ("Rewatch someday"): its name and the titles on it.
class CustomList {
  const CustomList({required this.name, required this.mediaIds});

  final String name;
  final List<int> mediaIds;
}

/// A page of airing schedule slots (airingWeekQuery).
class AiringSlot {
  const AiringSlot({required this.id, required this.episode, required this.airingAt, required this.media});

  factory AiringSlot.fromJson(Json j) => AiringSlot(
    id: _int(j['id'])!,
    episode: _int(j['episode']) ?? 0,
    airingAt: _int(j['airingAt']) ?? 0,
    media: AniListMedia.fromJson(j['media'] as Json),
  );

  final int id;
  final int episode;

  /// Unix seconds.
  final int airingAt;
  final AniListMedia media;
}

List<AniListMedia> mediaList(Object? raw) => [for (final m in _list(raw)) AniListMedia.fromJson(m)];
