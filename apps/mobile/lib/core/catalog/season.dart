import '../anilist/types.dart';

typedef SeasonYear = ({MediaSeason season, int year});

/// The anime season AniList expects for "popular this season", as of [date].
/// December counts as next year's winter, as on the web.
SeasonYear currentSeason([DateTime? date]) {
  final d = date ?? DateTime.now();
  final month = d.month; // 1–12
  if (month == 12) return (season: MediaSeason.winter, year: d.year + 1);
  if (month <= 2) return (season: MediaSeason.winter, year: d.year);
  if (month <= 5) return (season: MediaSeason.spring, year: d.year);
  if (month <= 8) return (season: MediaSeason.summer, year: d.year);
  return (season: MediaSeason.fall, year: d.year);
}

SeasonYear nextSeason(SeasonYear s) {
  final i = MediaSeason.values.indexOf(s.season);
  return i == MediaSeason.values.length - 1
      ? (season: MediaSeason.values.first, year: s.year + 1)
      : (season: MediaSeason.values[i + 1], year: s.year);
}

SeasonYear previousSeason(SeasonYear s) {
  final i = MediaSeason.values.indexOf(s.season);
  return i == 0
      ? (season: MediaSeason.values.last, year: s.year - 1)
      : (season: MediaSeason.values[i - 1], year: s.year);
}

/// The first month (1–12) of each season.
const seasonStartMonth = {MediaSeason.winter: 1, MediaSeason.spring: 4, MediaSeason.summer: 7, MediaSeason.fall: 10};
