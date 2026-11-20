import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/catalog/title.dart';
import 'package:miruyo/features/for_you/for_you_data.dart';

// Ported from apps/web/src/lib/page-data/for-you.test.ts. Scores are on the
// 10-point decimal scale unless a test says otherwise.

Json media(int id, String name, {String type = 'ANIME', List<String> genres = const [], Json extra = const {}}) => {
  'id': id,
  'type': type,
  'format': type == 'ANIME' ? 'TV' : 'MANGA',
  'title': {'romaji': name, 'english': name, 'userPreferred': name},
  'coverImage': <String, Object>{},
  'genres': genres,
  ...extra,
};

CollectionEntry entry(Json m, {String status = 'COMPLETED', double score = 0, int updatedAt = 0}) =>
    CollectionEntry.fromJson({
      'id': (m['id'] as int) * 10,
      'mediaId': m['id'],
      'status': status,
      'progress': 0,
      'score': score,
      'updatedAt': updatedAt,
      'media': m,
    });

({int rating, AniListMedia media}) rec(Json m, int rating) => (rating: rating, media: AniListMedia.fromJson(m));

void main() {
  final frieren = entry(media(1, 'Frieren', genres: ['Fantasy']), score: 9.5);
  final apothecary = entry(media(2, 'Apothecary', genres: ['Mystery']), score: 9);
  final meh = entry(media(3, 'Meh'), score: 5);
  final planned = entry(media(4, 'Planned'), status: 'PLANNING');
  final entries = [frieren, apothecary, meh, planned];
  final seeds = pickSeeds(entries, scoreFormat: ScoreFormat.point10Decimal);

  List<int> ids(List<Pick> picks) => [for (final p in picks) p.title.id];
  List<Pick> build(Map<int, List<({int rating, AniListMedia media})>> recs, {Set<int> dismissed = const {}}) =>
      buildPicks(
        seeds,
        recs,
        entries: entries,
        type: MediaType.anime,
        showAdult: false,
        dismissed: dismissed,
        scoreFormat: ScoreFormat.point10Decimal,
      );

  group('pickSeeds', () {
    test('takes the highest rated titles, best first', () {
      expect(seeds.map((s) => (s.title.title, s.score)), [('Frieren', 9.5), ('Apothecary', 9.0)]);
    });

    test('reads any score format', () {
      final onHundred = entry(media(9, 'Hundred'), score: 90);
      expect(pickSeeds([onHundred], scoreFormat: ScoreFormat.point100).single.score, 9);
    });

    test('counts scored titles', () => expect(scoredCount(entries), 3));

    test('ranks by the exact score, rounding only what it shows', () {
      final bebop = entry(media(20, 'Bebop'), score: 9.7);
      final fate = entry(media(21, 'Fate'), score: 9.5, updatedAt: 100);
      expect(pickSeeds([fate, bebop], scoreFormat: ScoreFormat.point10Decimal).map((s) => (s.title.title, s.score)), [
        ('Bebop', 9.5),
        ('Fate', 9.5),
      ]);
    });

    test('leaves out seeds you stopped using', () {
      expect(pickSeeds(entries, scoreFormat: ScoreFormat.point10Decimal, leaveOut: {1}).map((s) => s.title.title), [
        'Apothecary',
      ]);
    });
  });

  group('rotating by day', () {
    // 30 titles rated 7.5 to 10
    final many = [for (var i = 0; i < 30; i++) entry(media(100 + i, 'T$i'), score: 7.5 + (i % 6) * 0.5)];
    List<int> ids(String day) => [
      for (final s in pickSeeds(many, scoreFormat: ScoreFormat.point10Decimal, day: day)) s.title.id,
    ];

    test('draws maxSeeds, the same all day, best first', () {
      final seeds = pickSeeds(many, scoreFormat: ScoreFormat.point10Decimal, day: '2026-11-02');
      expect(seeds, hasLength(maxSeeds));
      expect(ids('2026-11-02'), [for (final s in seeds) s.title.id]);
      final scores = [for (final s in seeds) s.score];
      expect(scores, [...scores]..sort((a, b) => b.compareTo(a)));
    });

    test('draws a different set on other days', () {
      final week = {for (var d = 1; d <= 7; d++) ids('2026-11-0$d').join(',')};
      expect(week.length, greaterThan(5));
    });

    test('brings the higher rated round more often', () {
      final seen = <int, int>{};
      for (var d = 1; d <= 200; d++) {
        for (final id in ids('day-$d')) {
          seen[id] = (seen[id] ?? 0) + 1;
        }
      }
      int at(double score) => [
        for (final e in many)
          if (e.entry.score == score) seen[e.media.id] ?? 0,
      ].fold(0, (a, b) => a + b);
      expect(at(10), greaterThan(at(7.5) * 2));
    });

    test('keeps every title when there are no more than maxSeeds', () {
      expect(pickSeeds(entries, scoreFormat: ScoreFormat.point10Decimal, day: '2026-11-02').map((s) => s.title.title), [
        'Frieren',
        'Apothecary',
      ]);
    });
  });

  test('hashes as the web does, so both draw the same seeds on the same day', () {
    // the web's unitHash (for-you.ts) gives these, in Node
    expect(debugUnitHash('2026-11-02:100'), 0.7746934367402705);
    expect(debugUnitHash('day-7:123'), 0.7725768886104746);
    expect(debugUnitHash('x'), 0.1850122317706672);
  });

  test('names the day in local time', () {
    expect(localDay(DateTime(2026, 1, 5, 23, 59)), '2026-01-05');
  });

  group('buildPicks', () {
    test('ranks titles recommended by more and better-rated seeds first, with a reason', () {
      final both = media(10, 'Both'), one = media(11, 'One');
      final picks = build({
        1: [rec(both, 50), rec(one, 50)],
        2: [rec(both, 10)],
      });
      expect(ids(picks), [10, 11]);
      expect(picks.first.seedIds, [1, 2]);
      expect(reasonFor(picks.first), 'Because you rated Frieren 9.5/10');
      expect(picks.first.votes, 50);
    });

    test('leaves out titles on the list, dismissed, adult, or of the other type', () {
      final picks = build(
        {
          1: [
            rec(media(2, 'Apothecary'), 99), // already on the list
            rec(media(20, 'Dismissed'), 99),
            rec(media(21, 'Adult', extra: {'isAdult': true}), 99),
            rec(media(22, 'Manga', type: 'MANGA'), 99),
            rec(
              media(
                23,
                'Listed elsewhere',
                extra: {
                  'mediaListEntry': {'id': 1, 'status': 'PLANNING', 'progress': 0},
                },
              ),
              99,
            ),
            rec(media(24, 'Fresh'), 1),
          ],
        },
        dismissed: {20},
      );
      expect(ids(picks), [24]);
    });

    test('nudges up titles in genres you rate highly', () {
      final picks = build({
        2: [
          rec(media(31, 'Other pick', genres: ['Sports']), 5),
          rec(media(30, 'Fantasy pick', genres: ['Fantasy']), 5),
        ],
      });
      expect(ids(picks), [30, 31]);
      expect(picks.first.sharedGenres, ['Fantasy']);
    });

    test('moves titles up for genres you rate above your usual, and down for those below', () {
      final list = [
        entry(media(1, 'G1', genres: ['Fantasy']), score: 9.5),
        entry(media(2, 'G2', genres: ['Fantasy']), score: 9),
        entry(media(3, 'G3', genres: ['Sports']), score: 5),
        entry(media(4, 'G4', genres: ['Sports']), score: 5.5),
      ];
      final picks = buildPicks(
        pickSeeds(list, scoreFormat: ScoreFormat.point10Decimal),
        {
          1: [
            rec(media(30, 'Sports pick', genres: ['Sports']), 5),
            rec(media(31, 'Other pick', genres: ['Drama']), 5),
            rec(media(32, 'Fantasy pick', genres: ['Fantasy']), 5),
          ],
        },
        entries: list,
        type: MediaType.anime,
        showAdult: false,
        scoreFormat: ScoreFormat.point10Decimal,
      );
      expect(ids(picks), [32, 31, 30]);
      expect(picks.last.sharedGenres, isEmpty);
    });

    test('leaves out recommendations voted down to nothing', () {
      final picks = build({
        1: [rec(media(40, 'Zero'), 0), rec(media(41, 'Negative'), -3), rec(media(42, 'Kept'), 1)],
      });
      expect(ids(picks), [42]);
    });
  });

  group('lovedFrom', () {
    List<CollectionEntry> list(List<double> scores) => [
      for (final (i, score) in scores.indexed) entry(media(500 + i, 'L$i'), score: score),
    ];
    const format = ScoreFormat.point10Decimal;

    test('is 7.5 on a short list', () {
      expect(lovedFrom(list([6, 6, 6, 8]), format), 7.5);
    });

    test("follows a longer list's own scores, within 7 and 9", () {
      // a harsh rater: a 7 is a high mark
      final harsh = list([4, 5, 5, 5, 6, 6, 6, 6, 7, 7]);
      expect(lovedFrom(harsh, format), 7);
      expect(pickSeeds(harsh, scoreFormat: format).map((s) => s.score), [7, 7]);
      // a generous one: 8.5 is ordinary
      final generous = list([8, 8.5, 9, 9, 9, 9, 9.5, 9.5, 10, 10]);
      expect(lovedFrom(generous, format), 9);
      expect(pickSeeds(generous, scoreFormat: format).map((s) => s.score), [10, 10, 9.5, 9.5, 9, 9, 9, 9]);
      // in between: half a deviation above the mean
      expect(lovedFrom(list([5, 6, 6, 7, 7, 7, 8, 8, 9, 10]), format), closeTo(7.3 + 0.7088723, 1e-6));
    });
  });

  test("genreLift measures a genre against the list's mean, not by how often it comes up", () {
    CollectionEntry e(int id, List<String> genres, double score) =>
        entry(media(id, 'E$id', genres: genres), score: score);
    final lift = genreLift([
      e(1, ['Action'], 7),
      e(2, ['Action'], 7),
      e(3, ['Action'], 7),
      e(4, ['Action', 'Mystery'], 9),
      e(5, ['Action', 'Mystery'], 9),
      e(6, ['Action', 'Mystery'], 9),
      e(7, ['Romance'], 5),
      e(8, ['Romance'], 5),
      e(9, ['Romance'], 5),
      e(10, [], 0), // unscored: left out
    ], ScoreFormat.point10Decimal);
    // mean 7: Mystery +2 each, three of them, shrunk by three: +1
    expect(lift['Mystery'], closeTo(1, 1e-9));
    expect(lift['Romance'], closeTo(-1, 1e-9));
    // on most of the list, so about the mean
    expect(lift['Action'], closeTo(6 / 9, 1e-9));
  });

  test('visiblePicks drops hidden picks and those only a muted seed recommends', () {
    final picks = build({
      1: [rec(media(40, 'Only Frieren'), 9), rec(media(41, 'Both'), 9)],
      2: [rec(media(41, 'Both'), 9), rec(media(42, 'Only Apothecary'), 9)],
    });
    final data = ForYou(coldStart: false, scored: 3, seeds: seeds, picks: picks);
    expect(ids(visiblePicks(data, {42}, {1})).toSet(), {41});
    expect(scoreLabel(9), '9/10');
    expect(scoreLabel(9.5), '9.5/10');
  });

  // ── Ported with the web's studios, cross-mode and Tune tests ──

  Json studio(int id, String name) => {
    'nodes': [
      {'id': id, 'name': name},
    ],
  };
  Seed seedOf(Json m, double score) => Seed(title: adaptMedia(AniListMedia.fromJson(m)), score: score);
  ({String relationType, AniListMedia media}) rel(String type, Json m) =>
      (relationType: type, media: AniListMedia.fromJson(m));

  group('studios', () {
    final madhouse = studio(11, 'MADHOUSE');
    CollectionEntry loved(int id, {double score = 9}) =>
        entry(media(id, 'Loved $id', extra: {'studios': madhouse}), score: score);

    test('counts a studio once two titles it made are rated 7.5 or more', () {
      expect(favouriteStudios([loved(1), loved(2)], ScoreFormat.point10Decimal), {11: 'MADHOUSE'});
      expect(favouriteStudios([loved(1), loved(2, score: 6)], ScoreFormat.point10Decimal), isEmpty);
    });

    test("lifts a favourite studio's pick and says which studio", () {
      final list = [loved(1), loved(2)];
      final picks = buildPicks(
        pickSeeds(list, scoreFormat: ScoreFormat.point10Decimal),
        {
          1: [
            rec(media(10, 'Other', extra: {'studios': studio(12, 'Other')}), 40),
            rec(media(11, 'Mad', extra: {'studios': madhouse}), 40),
          ],
        },
        entries: list,
        type: MediaType.anime,
        showAdult: false,
        scoreFormat: ScoreFormat.point10Decimal,
      );
      expect([for (final p in picks) (p.title.id, p.studio?.name)], [(11, 'MADHOUSE'), (10, null)]);
      expect(picks.first.score, closeTo(picks.last.score * 1.15, 1e-9));
    });
  });

  group('across modes', () {
    final frierenAnime = seedOf(media(1, 'Frieren'), 9);
    List<Pick> mangaPicks(List<Seed> cross, Relations relations, {List<CollectionEntry> list = const []}) => buildPicks(
      const [],
      const {},
      entries: list,
      type: MediaType.manga,
      showAdult: false,
      crossSeeds: cross,
      relations: relations,
    );

    test("suggests an anime's source manga, saying why", () {
      final picks = mangaPicks(
        [frierenAnime],
        {
          1: [
            rel('SOURCE', media(100, 'Frieren (manga)', type: 'MANGA')),
            rel('SEQUEL', media(101, 'Not this one', type: 'MANGA')),
          ],
        },
      );
      expect(ids(picks), [100]);
      expect(picks.single.kind, PickKind.adaptation);
      expect(reasonFor(picks.single), 'The manga of Frieren, which you rated 9/10');
    });

    test("takes a manga's two most popular anime, and calls a novel a novel", () {
      final berserk = seedOf(media(2, 'Berserk', type: 'MANGA'), 10);
      Json show(int id, int popularity) => media(id, 'Berserk $id', extra: {'popularity': popularity});
      final picks = buildPicks(
        const [],
        const {},
        entries: const [],
        type: MediaType.anime,
        showAdult: false,
        crossSeeds: [berserk],
        relations: {
          2: [rel('ADAPTATION', show(200, 10)), rel('ADAPTATION', show(201, 300)), rel('ADAPTATION', show(202, 200))],
        },
      );
      expect(ids(picks)..sort(), [201, 202]);
      expect(reasonFor(picks.first), 'The anime of Berserk, which you rated 10/10');

      final novel = mangaPicks(
        [seedOf(media(3, 'Spice and Wolf'), 9)],
        {
          3: [
            rel('SOURCE', media(300, 'Spice and Wolf', type: 'MANGA', extra: {'format': 'NOVEL'})),
          ],
        },
      );
      expect(reasonFor(novel.single), 'The novel of Spice and Wolf, which you rated 9/10');
    });

    test('leaves out what is already on the list', () {
      final onList = entry(media(100, 'On my list', type: 'MANGA'), status: 'CURRENT');
      expect(
        mangaPicks(
          [frierenAnime],
          {
            1: [rel('SOURCE', media(100, 'On my list', type: 'MANGA'))],
          },
          list: [onList],
        ),
        isEmpty,
      );
    });
  });

  group('Tune', () {
    final picks = buildPicks(
      [seedOf(media(1, 'Seed'), 9)],
      {
        1: [
          rec(media(10, 'Out', genres: ['Action'], extra: {'status': 'FINISHED'}), 9),
          rec(media(11, 'Soon', genres: ['Drama'], extra: {'status': 'NOT_YET_RELEASED'}), 9),
        ],
      },
      entries: const [],
      type: MediaType.anime,
      showAdult: false,
      crossSeeds: [seedOf(media(2, 'Manga', type: 'MANGA'), 9)],
      relations: {
        2: [
          rel('ADAPTATION', media(12, 'Its anime', genres: ['Drama'])),
        ],
      },
    );
    List<int> sorted(List<Pick> p) => ids(p)..sort();

    test('keeps everything by default', () {
      expect(sorted(tunePicks(picks, const Tune())), [10, 11, 12]);
    });

    test('leaves out what is not out yet, the other mode, or a genre', () {
      expect(sorted(tunePicks(picks, const Tune(outOnly: true))), [10, 12]);
      expect(sorted(tunePicks(picks, const Tune(crossMode: false))), [10, 11]);
      expect(sorted(tunePicks(picks, const Tune(hiddenGenres: ['Drama']))), [10]);
    });

    test('offers the genres among the picks, most common first', () {
      expect(pickGenres(picks), ['Drama', 'Action']);
    });

    test('reads what was saved, falling back to the default', () {
      final saved = Tune.fromJson(const Tune(outOnly: true, crossMode: false, hiddenGenres: ['Drama']).toJson());
      expect((saved.outOnly, saved.crossMode), (true, false));
      expect(saved.hiddenGenres, ['Drama']);
      expect(Tune.fromJson('nonsense').changed, isFalse);
      expect(Tune.fromJson({'hiddenGenres': 'Drama'}).hiddenGenres, isEmpty);
    });
  });
}
