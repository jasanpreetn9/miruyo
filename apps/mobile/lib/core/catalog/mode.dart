import '../anilist/types.dart';

/// The Anime/Manga mode: the single most important control in the app. It
/// changes on the top-bar toggle, and follows the title you open (a manga's
/// page switches to Manga), never by swiping content.
enum Mode {
  anime,
  manga;

  MediaType get mediaType => this == anime ? MediaType.anime : MediaType.manga;

  bool get isAnime => this == anime;

  static Mode parse(String? raw) => raw == 'manga' ? manga : anime;
}
