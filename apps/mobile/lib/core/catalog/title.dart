// The UI's title shape, ported from apps/web/src/lib/catalog/types.ts
// (Title) and adapt.ts (adaptMedia). Screens render Titles, never raw
// AniList media.

import '../anilist/types.dart';
import 'cover_color.dart';
import 'humanize.dart';

class NextAiring {
  const NextAiring({required this.ep, required this.airingAt});

  final int ep;

  /// Unix seconds.
  final int airingAt;
}

/// The viewer's list entry as a title arrived with it.
class MyProgress {
  const MyProgress({required this.status, required this.progress, this.volumes, this.score});

  final MediaListStatus status;
  final int progress;
  final int? volumes;
  final double? score;
}

class Title {
  Title({
    required this.id,
    required this.title,
    required this.type,
    required this.format,
    required this.score,
    required this.colors,
    required this.genres,
    required this.status,
    this.en,
    this.native,
    this.eps,
    this.ch,
    this.vol,
    this.studio,
    this.season,
    this.next,
    this.me,
    this.adult = false,
    this.synopsis,
    this.coverUrl,
    this.thumbUrl,
    this.bannerUrl,
    this.duration,
  });

  final int id;

  /// In the viewer's title language (or English, signed out).
  final String title;
  final String? en;
  final String? native;
  final MediaType type;

  /// Humanized ("TV Short").
  final String format;
  final int? eps;
  final int? ch;
  final int? vol;

  /// AniList's average, 0–10 (0 = none yet).
  final double score;
  final CoverColors colors;
  final List<String> genres;
  final String? studio;

  /// "Fall 2026".
  final String? season;

  /// Humanized release status ("Releasing").
  final String status;
  final NextAiring? next;
  final MyProgress? me;
  final bool adult;
  final String? synopsis;
  final String? coverUrl;

  /// A smaller cover for list thumbnails; falls back to [coverUrl].
  final String? thumbUrl;
  final String? bannerUrl;

  /// Minutes per episode (anime only).
  final int? duration;

  bool get isAnime => type == MediaType.anime;

  /// The progress unit: EP or CH.
  String get unit => isAnime ? 'EP' : 'CH';

  /// Episodes or chapters, when known.
  int? get total => isAnime ? eps : ch;

  bool get coverMissing => coverUrl == null;

  /// "28 eps", "? eps", "120 ch", "Ongoing".
  String get countLabel =>
      isAnime ? (eps != null && eps! > 0 ? '$eps eps' : '? eps') : (ch != null && ch! > 0 ? '$ch ch' : 'Ongoing');

  /// Truncated for tight spots.
  String get short => title.length > 34 ? '${title.substring(0, 32)}…' : title;

  /// The format, unless AniList doesn't know it.
  String? get knownFormat => format == 'Unknown' ? null : format;

  /// "28 eps", "120 ch", or "Ongoing" for one still running; nothing when
  /// AniList has no count for a finished or upcoming title.
  String? get knownCount {
    final n = total;
    if (n != null && n > 0) return isAnime ? (n == 1 ? '1 ep' : '$n eps') : '$n ch';
    return !isAnime || status == 'Releasing' ? 'Ongoing' : null;
  }

  /// "TV · 28 eps · Fall 2026": the line under a card's title. Unknowns are
  /// left out rather than shown as "Unknown" or "?".
  String get meta => [knownFormat, knownCount, isAnime ? season : status].whereType<String>().join(' · ');
}

/// Which title to show. userPreferred is AniList's own pick for the signed-in
/// viewer (their account's title language), so it's only meaningful on
/// authenticated requests; signed-out visitors get English.
enum TitlePreference { userPreferred, english }

String pickTitle(AniListMediaTitle t, TitlePreference preference) {
  final order = preference == TitlePreference.english
      ? [t.english, t.romaji, t.userPreferred, t.native]
      : [t.userPreferred, t.romaji, t.english, t.native];
  return order.firstWhere((s) => s != null && s.isNotEmpty, orElse: () => 'Untitled')!;
}

/// Converts AniList media (+ the viewer's entry for it, if any: passed in,
/// or attached by the query as mediaListEntry) into a [Title].
Title adaptMedia(
  AniListMedia media, {
  ({MediaListStatus status, int progress})? entry,
  TitlePreference titles = TitlePreference.userPreferred,
}) {
  final isAnime = media.type == MediaType.anime;
  final own =
      entry ??
      (media.mediaListEntry == null
          ? null
          : (status: media.mediaListEntry!.status, progress: media.mediaListEntry!.progress));
  final next = media.nextAiringEpisode;
  final cover = media.coverImage.extraLarge ?? media.coverImage.large;

  return Title(
    id: media.id,
    title: pickTitle(media.title, titles),
    en: media.title.english,
    native: media.title.native,
    type: media.type,
    format: humanizeFormat(media.format),
    eps: isAnime ? media.episodes : null,
    ch: isAnime ? null : media.chapters,
    vol: isAnime ? null : media.volumes,
    score: media.averageScore != null ? media.averageScore! / 10 : 0,
    colors: CoverColors.fromHex(media.coverImage.color),
    genres: media.genres,
    // Media.studios is anime-centric; manga rarely has one
    studio: media.studios.isEmpty ? null : media.studios.first,
    season: media.season != null && media.seasonYear != null
        ? '${humanizeSeason(media.season!)} ${media.seasonYear}'
        : null,
    status: humanizeStatus(media.status),
    next: next == null ? null : NextAiring(ep: next.episode, airingAt: next.airingAt),
    me: own == null ? null : MyProgress(status: own.status, progress: own.progress),
    adult: media.isAdult,
    synopsis: media.description == null ? null : stripHtml(media.description!),
    coverUrl: cover,
    thumbUrl: cover == null ? null : media.coverImage.large,
    bannerUrl: media.bannerImage,
    duration: isAnime ? media.duration : null,
  );
}
