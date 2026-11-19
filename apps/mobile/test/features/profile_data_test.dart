import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/features/profile/profile_data.dart';

// Ported from apps/web/src/lib/page-data/stats.test.ts.

// Wed 7 Oct 2026, local time
final now = DateTime(2026, 10, 7, 12);
Json date(int year, int month, [int day = 1]) => {'year': year, 'month': month, 'day': day};

CollectionEntry entry(
  int id, {
  String type = 'ANIME',
  String format = 'TV',
  int? episodes = 12,
  int? chapters,
  int? volumes,
  int? duration = 24,
  List<String> genres = const [],
  int? averageScore = 85,
  String status = 'CURRENT',
  int progress = 0,
  int? progressVolumes,
  int repeat = 0,
  double score = 0,
  Json? startedAt,
  Json? completedAt,
  int? updatedAt,
}) => CollectionEntry.fromJson({
  'id': id * 10,
  'mediaId': id,
  'status': status,
  'progress': progress,
  'progressVolumes': progressVolumes,
  'repeat': repeat,
  'score': score,
  'startedAt': startedAt,
  'completedAt': completedAt,
  'updatedAt': updatedAt ?? now.millisecondsSinceEpoch ~/ 1000,
  'media': {
    'id': id,
    'type': type,
    'format': format,
    'episodes': episodes,
    'chapters': chapters,
    'volumes': volumes,
    'duration': duration,
    'genres': genres,
    'averageScore': averageScore,
    'title': {'romaji': 'T$id'},
    'coverImage': <String, Object>{},
  },
});

void main() {
  test('toTenPoint puts every score format on the 10-point axis', () {
    expect(toTenPoint(85, ScoreFormat.point100), 8.5);
    expect(toTenPoint(8.5, ScoreFormat.point10Decimal), 8.5);
    expect(toTenPoint(4, ScoreFormat.point5), 8);
    expect(toTenPoint(0, ScoreFormat.point100), 0);
    expect(StatsRange.year.label(now), '2026');
  });

  group('buildStats', () {
    final frieren = entry(
      1,
      episodes: 28,
      genres: ['Adventure', 'Drama'],
      status: 'COMPLETED',
      progress: 28,
      repeat: 1,
      score: 9.5,
      startedAt: date(2026, 1),
      completedAt: date(2026, 9, 20),
    );
    final movie = entry(
      2,
      format: 'MOVIE',
      episodes: 1,
      duration: 120,
      genres: ['Drama'],
      status: 'COMPLETED',
      progress: 1,
      score: 6,
      startedAt: date(2020, 5),
      completedAt: date(2020, 5),
    );
    final watching = entry(3, genres: ['Action'], progress: 5);
    final entries = [frieren, movie, watching];
    Stats stats([StatsRange range = StatsRange.all]) =>
        buildStats(entries, isAnime: true, range: range, now: now, scoreFormat: ScoreFormat.point10Decimal);

    test('counts episodes with rewatches in full, and days watched', () {
      final [total, episodes, days, mean] = stats().cards;
      expect(
        (total.label, total.value, total.detail, total.positive),
        ('Total anime', '3', '+1 finished this season', true),
      );
      // 28 + 28 (rewatch) + 1 + 5
      expect(episodes.value, '62');
      // (56×24 + 120 + 5×24) / 1440
      expect(days.value, '1.1');
      expect((mean.value, mean.detail), ('7.8', 'AniList mean 8.5'));
    });

    test('buckets scores on the 10-point axis and accents 7 and up', () {
      final s = stats();
      expect(s.scores.map((b) => b.count), [0, 0, 0, 0, 0, 1, 0, 0, 0, 1]);
      expect((s.scores[5].tone, s.scores[9].tone), (Tone.mute, Tone.accent));
      expect(s.scored, 2);
      expect(s.deviation, closeTo(1.75, 0.001));
    });

    test('groups formats, statuses and genres', () {
      final s = stats();
      expect(s.formats.map((f) => (f.label, f.count)), [('TV', 2), ('Movie', 1)]);
      expect(s.statuses.map((x) => (x.label, x.count)), [('Completed', 2), ('Watching', 1)]);
      final drama = s.genres.first;
      expect((drama.genre, drama.count, drama.mean, drama.width), ('Drama', 2, 7.75, 1.0));
      expect(s.genres.firstWhere((g) => g.genre == 'Action').mean, isNull);
    });

    test('folds formats past the fourth into Other', () {
      final many = [
        for (final (i, f) in ['TV', 'MOVIE', 'OVA', 'ONA', 'SPECIAL'].indexed) entry(10 + i, format: f),
      ];
      final s = buildStats(many, isAnime: true, range: StatsRange.all, now: now);
      expect(s.formats.map((f) => f.label), ['TV', 'Movie', 'OVA', 'Other']);
      expect(s.formats[3].count, 2);
    });

    test('limits a range to titles started or finished in it', () {
      final year = stats(StatsRange.year);
      // the 2020 movie drops out; the undated entry counts by its last update
      expect(year.total, 2);
      expect(year.formats.map((f) => f.label), ['TV']);
    });

    test('counts titles finished per month for the last 12 months', () {
      final months = stats().months;
      expect(months, hasLength(12));
      expect(months.first.name, 'November 2025');
      // months with something finished are in the accent, empty ones quiet
      expect((months[11].label, months[11].tone, months[11].count), ('O', Tone.mute, 0));
      expect((months[10].name, months[10].count, months[10].tone), ('September 2026', 1, Tone.accent));
    });

    test('swaps units for manga', () {
      final manga = entry(
        20,
        type: 'MANGA',
        format: 'MANGA',
        episodes: null,
        chapters: 100,
        volumes: 10,
        status: 'COMPLETED',
        progress: 100,
        progressVolumes: 10,
        repeat: 1,
      );
      final s = buildStats([manga], isAnime: false, range: StatsRange.all, now: now);
      expect(s.cards.map((c) => (c.label, c.value)), [
        ('Total manga', '1'),
        ('Chapters read', '200'),
        ('Volumes read', '20'),
        ('Mean score', '—'),
      ]);
    });
  });

  group('buildHeatmap', () {
    int day(int y, int m, int d) => DateTime(y, m, d).millisecondsSinceEpoch ~/ 1000;

    test('lays out 26 weeks of Monday → Sunday, ending this week', () {
      final grid = buildHeatmap(const [], now);
      expect(grid, hasLength(26));
      expect(grid.every((w) => w.length == 7), isTrue);
      // Wed 7 Oct: Thu–Sun of this week haven't happened yet
      expect(grid[25].map((c) => c == null), [false, false, false, true, true, true, true]);
      expect(grid[25][2]?.date, 'Oct 7');
      expect(grid[0][0]?.date, 'Apr 13');
    });

    test('levels active days by quartile, so one big day does not flatten the rest', () {
      final history = [
        for (final (i, amount) in [1, 2, 3, 4, 500].indexed) (date: day(2026, 10, 1 + i), amount: amount, level: 1),
      ];
      final levels = [
        for (final c in buildHeatmap(history, now).expand((w) => w))
          if ((c?.amount ?? 0) > 0) c!.level,
      ];
      expect(levels, [1, 1, 2, 3, 4]);
    });
  });

  group('anilistLink', () {
    test('keeps https anilist.co links and falls back for anything else', () {
      expect(anilistLink('https://anilist.co/user/a', 'https://anilist.co/f'), Uri.parse('https://anilist.co/user/a'));
      expect(anilistLink('intent://evil#Intent;end', 'https://anilist.co/f'), Uri.parse('https://anilist.co/f'));
      expect(anilistLink('https://anilist.co.evil.example/x'), isNull);
      expect(anilistLink('http://[bad'), isNull);
      expect(anilistLink(null), isNull);
    });
  });

  group('buildProfile', () {
    AniListMedia media(int id) => AniListMedia.fromJson({
      'id': id,
      'type': 'ANIME',
      'title': {'romaji': 'T$id'},
      'coverImage': <String, Object>{},
    });
    ProfileData profile({List<AniListMedia> anime = const []}) => (
      account: {
        'id': 1,
        'name': 'haruka_k',
        'siteUrl': 'https://anilist.co/user/haruka_k',
        'favourites': {
          'characters': {
            'nodes': [
              {
                'id': 40,
                'name': {'userPreferred': 'Frieren'},
                'image': {'large': 'frieren.png'},
              },
              {
                'id': 40,
                'name': {'userPreferred': 'Frieren'},
                'image': {'large': 'frieren.png'},
              },
            ],
          },
          'studios': {
            'nodes': [
              {'id': 7, 'name': 'Madhouse', 'siteUrl': 'javascript:alert(1)'},
            ],
          },
        },
      },
      anime: anime,
      manga: const <AniListMedia>[],
      titlesError: null,
    );

    test('lists a favourite once, even when AniList lists it twice', () {
      final view = buildProfile(profile(anime: [media(1), media(79), media(79)]), showAdult: false);
      expect(view.anime.map((t) => t.id), [1, 79]);
      expect(view.characters.map((c) => c.id), [40]);
    });

    test('links people and studios to their miruyo pages', () {
      final view = buildProfile(profile(), showAdult: false);
      expect(view.characters.single.href, '/character/40');
      expect(view.studios.single.href, '/studio/7');
      expect(view.anilist.toString(), 'https://anilist.co/user/haruka_k');
    });
  });
}
