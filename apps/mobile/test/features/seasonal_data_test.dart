import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/features/seasonal/seasonal_data.dart';

AniListMedia media(int id, {String format = 'TV', Json extra = const {}}) => AniListMedia.fromJson({
  'id': id,
  'type': 'ANIME',
  'format': format,
  'title': {'romaji': 'T$id'},
  'coverImage': <String, Object>{},
  'genres': ['Action', 'Drama', 'Fantasy', 'Mystery'],
  ...extra,
});

void main() {
  test('longDuration reads like AniChart', () {
    expect(longDuration(86400 + 6 * 3600), '1 day, 6 hours');
    expect(longDuration(2 * 86400), '2 days');
    expect(longDuration(18 * 3600 + 31 * 60), '18 hours, 31 mins');
    expect(longDuration(35 * 60), '35 mins');
    expect(longDuration(60), '1 min');
  });

  test('shiftSeason wraps years both ways', () {
    final s = shiftSeason((season: MediaSeason.fall, year: 2026), 1);
    expect((s.season, s.year), (MediaSeason.winter, 2027));
    final t = shiftSeason((season: MediaSeason.winter, year: 2026), -1);
    expect((t.season, t.year), (MediaSeason.fall, 2025));
    expect(seasonWindow((season: MediaSeason.fall, year: 2026)).map(seasonName), [
      'Summer 2026',
      'Fall 2026',
      'Winter 2027',
      'Spring 2027',
    ]);
  });

  test('parseSeasonQuery only opens seasons with a chart', () {
    final now = DateTime(2026, 11, 4);
    (MediaSeason, int)? parse(Map<String, String> q) {
      final s = parseSeasonQuery(q, now);
      return s == null ? null : (s.season, s.year);
    }

    expect(parse({'season': 'winter', 'year': '2027'}), (MediaSeason.winter, 2027));
    expect(parse({'season': 'nope', 'year': '2027'}), isNull);
    expect(parse({'season': 'FALL'}), isNull);
    // no chart that far out: its airing week would overflow AniList's 32-bit timestamps
    expect(parse({'season': 'winter', 'year': '2367'}), isNull);
    expect(parse({'season': 'fall', 'year': '2028'}), (MediaSeason.fall, 2028));
    expect(parse({'season': 'winter', 'year': '2029'}), isNull);
    expect(parse({'season': 'winter', 'year': '1939'}), isNull);
    expect(parse({'season': 'winter', 'year': '1940'}), (MediaSeason.winter, 1940));
  });

  test('scoreFace', () {
    expect(scoreFace(80), ScoreFace.good);
    expect(scoreFace(65), ScoreFace.ok);
    expect(scoreFace(40), ScoreFace.bad);
    expect(scoreFace(null), isNull);
  });

  group('buildSeasonChart', () {
    const season = (season: MediaSeason.fall, year: 2026);
    const now = 1800000000;

    test('sections in AniChart order, empty ones dropped', () {
      final sections = buildSeasonChart(
        [media(1), media(2, format: 'MOVIE'), media(3, format: 'ONA')],
        [media(4)],
        season: season,
        nowSeconds: now,
      );
      expect(sections.map((s) => s.label), ['TV', 'Leftovers', 'Movie', 'OVA / ONA / Special']);
    });

    test('a card says when, where it comes from, and its rank this season', () {
      final card = buildCard(
        media(
          1,
          extra: {
            'episodes': 12,
            'source': 'LIGHT_NOVEL',
            'nextAiringEpisode': {'episode': 2, 'airingAt': now + 18 * 3600 + 31 * 60, 'timeUntilAiring': 0},
            'rankings': [
              {'rank': 7, 'type': 'POPULAR', 'allTime': false, 'season': 'FALL', 'year': 2026},
            ],
          },
        ),
        season: season,
        nowSeconds: now,
      );
      expect(card.whenLabel, 'Ep 2 of 12 airing in');
      expect(card.when, '18 hours, 31 mins');
      expect(card.origin, 'Source • Light Novel');
      expect(card.popularRank, 7);
      expect(card.genres, hasLength(3));
    });

    test('a sequel names its prequel', () {
      final card = buildCard(
        media(
          1,
          extra: {
            'relations': {
              'edges': [
                {
                  'relationType': 'PREQUEL',
                  'node': {
                    'id': 9,
                    'type': 'ANIME',
                    'title': {'userPreferred': 'Season 1', 'english': 'S1'},
                  },
                },
              ],
            },
          },
        ),
        season: season,
        nowSeconds: now,
      );
      expect(card.origin, 'Sequel to Season 1');
    });

    test('sorts by score and by airing soonest', () {
      final chart = buildSeasonChart(
        [
          media(1, extra: {'averageScore': 60}),
          media(
            2,
            extra: {
              'averageScore': 90,
              'nextAiringEpisode': {'episode': 1, 'airingAt': now + 10, 'timeUntilAiring': 10},
            },
          ),
        ],
        [],
        season: season,
        nowSeconds: now,
        sort: ChartSort.score,
      );
      expect(chart.single.cards.map((c) => c.title.id), [2, 1]);
    });
  });

  group('buildCalendar', () {
    // Wednesday, Oct 7 2026, 12:00 local
    final now = DateTime(2026, 10, 7, 12);
    final monday = mondayOf(now);

    AiringSlot slot(int id, DateTime at, {int episode = 1}) =>
        AiringSlot(id: id, episode: episode, airingAt: at.millisecondsSinceEpoch ~/ 1000, media: media(id));

    test('puts today first and the days already past at the end', () {
      final days = buildCalendar([], monday, now: now);
      expect(days.map((d) => d.name), ['Today', 'Thu', 'Fri', 'Sat', 'Sun', 'Mon', 'Tue']);
      expect(days.last.past, isTrue);
    });

    test('other weeks run Monday to Sunday', () {
      final days = buildCalendar([], addDays(monday, 7), now: now);
      expect(days.first.name, 'Mon');
      expect(days.any((d) => d.past), isFalse);
    });

    test('places slots on their local day, in time order, and marks yours', () {
      final days = buildCalendar(
        [slot(1, DateTime(2026, 10, 7, 23)), slot(2, DateTime(2026, 10, 7, 9), episode: 4)],
        monday,
        now: now,
        entry: (id) => id == 2 ? (status: MediaListStatus.current, progress: 3) : null,
      );
      final today = days.first;
      expect(today.slots.map((s) => s.time), ['09:00', '23:00']);
      final mine = today.slots.first;
      expect((mine.mine, mine.aired, mine.canAddOne), (true, true, true));
      expect(today.slots.last.soon, isTrue);
    });

    test('My list only keeps just your shows', () {
      final days = buildCalendar(
        [slot(1, DateTime(2026, 10, 7, 23)), slot(2, DateTime(2026, 10, 8, 9))],
        monday,
        now: now,
        mineOnly: true,
        entry: (id) => id == 2 ? (status: MediaListStatus.current, progress: 0) : null,
      );
      expect(days.expand((d) => d.slots).map((s) => s.id), [2]);
    });
  });

  test('weekLabel spans Monday to Sunday', () {
    expect(weekLabel(DateTime(2026, 10, 5)), 'Oct 5 – 11');
    expect(weekLabel(DateTime(2026, 9, 28)), 'Sep 28 – Oct 4');
  });
}
