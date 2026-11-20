// Ported from the web's lib/browse/params.test.ts.

import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/features/browse/browse_params.dart';

Map<String, List<String>> query(String q) => Uri(query: q).queryParametersAll;

void main() {
  group('BrowseState.fromQuery', () {
    test('reads defaults from an empty query', () {
      expect(BrowseState.fromQuery(const {}, isAnime: true), const BrowseState());
    });

    test('round-trips through the query', () {
      const anime = BrowseState(
        q: 'frieren',
        genres: ['Fantasy', 'Drama'],
        tags: ['Elf'],
        formats: ['TV', 'MOVIE'],
        status: 'RELEASING',
        season: MediaSeason.fall,
        year: 2026,
        scoreMin: 7,
        scoreMax: 9.5,
        hideOnList: true,
        sort: BrowseSort.score,
      );
      expect(BrowseState.fromQuery(anime.toQuery(), isAnime: true), anime);

      const manga = BrowseState(country: 'KR', formats: ['MANGA'], status: 'FINISHED');
      expect(BrowseState.fromQuery(manga.toQuery(), isAnime: false), manga);
    });

    test('leaves defaults out of the query', () {
      expect(const BrowseState().toQuery(), isEmpty);
      expect(const BrowseState(q: '  spaced  ').toQuery(), {
        'q': ['spaced'],
      });
    });

    test('drops values that are unknown or belong to the other mode', () {
      final q = query('format=MANGA&format=TV&status=BOGUS&season=FALL&country=KR&sort=nope');
      final anime = BrowseState.fromQuery(q, isAnime: true);
      expect(anime.formats, ['TV']);
      expect(anime.status, '');
      expect(anime.season, MediaSeason.fall);
      expect(anime.country, '');
      expect(anime.sort, BrowseSort.popularity);

      final manga = BrowseState.fromQuery(q, isAnime: false);
      expect(manga.formats, ['MANGA']);
      expect(manga.season, isNull);
      expect(manga.country, 'KR');
    });

    test('clamps and orders the score range', () {
      final s = BrowseState.fromQuery(query('min=9.3&max=4'), isAnime: true);
      expect((s.scoreMin, s.scoreMax), (4, 9.5));
      final t = BrowseState.fromQuery(query('min=-3&max=42'), isAnime: true);
      expect((t.scoreMin, t.scoreMax), (0, 10));
    });

    test('reads the web\'s See all links', () {
      expect(BrowseState.fromQuery(query('sort=trending'), isAnime: true).sort, BrowseSort.trending);
      expect(BrowseState.fromQuery(query('status=RELEASING'), isAnime: false).status, 'RELEASING');
      expect(BrowseState.fromQuery(query('genre=Slice%20of%20Life'), isAnime: true).genres, ['Slice of Life']);
    });
  });

  group('toVariables', () {
    Json vars(BrowseState s, {MediaType type = MediaType.anime, bool signedIn = true, bool showAdult = false}) =>
        s.toVariables(type: type, signedIn: signedIn, showAdult: showAdult);

    test('leaves unset filters out (AniList rejects some of them as null)', () {
      expect(vars(const BrowseState()), {
        'page': 1,
        'perPage': 30,
        'type': 'ANIME',
        'isAdult': false,
        'sort': ['POPULARITY_DESC'],
      });
    });

    test("maps the score range to AniList's exclusive 100-point bounds", () {
      final v = vars(const BrowseState(scoreMin: 7, scoreMax: 9));
      expect((v['scoreAbove'], v['scoreBelow']), (69, 91));
    });

    test('only filters by list when signed in', () {
      expect(vars(const BrowseState(hideOnList: true))['onList'], false);
      expect(vars(const BrowseState(hideOnList: true), signedIn: false).containsKey('onList'), isFalse);
    });

    test('only sends mode-specific filters for their mode', () {
      const s = BrowseState(season: MediaSeason.fall, year: 2026, country: 'JP');
      final anime = vars(s);
      expect((anime['season'], anime['seasonYear']), ('FALL', 2026));
      expect(anime.containsKey('country'), isFalse);
      final manga = vars(s, type: MediaType.manga);
      expect(manga['country'], 'JP');
      expect(manga.containsKey('season'), isFalse);
      expect(manga.containsKey('seasonYear'), isFalse);
    });

    test('includes 18+ titles only when the account allows them', () {
      expect(vars(const BrowseState(), showAdult: true).containsKey('isAdult'), isFalse);
    });
  });

  group('activeFilters', () {
    test('makes a removable chip for every active filter', () {
      const s = BrowseState(
        genres: ['Fantasy'],
        tags: ['Elf'],
        season: MediaSeason.fall,
        year: 2026,
        formats: ['TV'],
        status: 'RELEASING',
        scoreMin: 7,
        hideOnList: true,
      );
      final chips = activeFilters(s, isAnime: true);
      expect(chips.map((c) => c.label), [
        'Fantasy',
        'Elf',
        'Fall 2026',
        'TV',
        'Releasing',
        'Score ≥ 7.0',
        'Not on my list',
      ]);
      expect(chips[0].without.genres, isEmpty);
      expect((chips[2].without.season, chips[2].without.year), (null, null));
    });

    test('labels a closed score range and the manga country', () {
      final chips = activeFilters(const BrowseState(scoreMin: 6, scoreMax: 8.5, country: 'CN'), isAnime: false);
      expect(chips.map((c) => c.label), ['China (manhua)', 'Score 6.0–8.5']);
    });
  });

  test('browseTitle names the list a See all opened', () {
    expect(browseTitle(const BrowseState(sort: BrowseSort.trending), isAnime: true), 'Trending anime');
    expect(browseTitle(const BrowseState(status: 'RELEASING'), isAnime: false), 'Popular releasing manga');
    expect(browseTitle(const BrowseState(q: 'x', sort: BrowseSort.trending), isAnime: true), isNull);
    expect(browseTitle(const BrowseState(), isAnime: true), isNull);
  });

  test('forMode keeps what applies and drops the rest', () {
    const s = BrowseState(season: MediaSeason.fall, formats: ['TV'], genres: ['Drama']);
    final manga = s.forMode(isAnime: false);
    expect(manga.season, isNull);
    expect(manga.formats, isEmpty);
    expect(manga.genres, ['Drama']);
  });

  group('excluded genres and tags', () {
    const s = BrowseState(genres: ['Action'], notGenres: ['Romance'], notTags: ['Isekai']);

    test('round-trip through the query and reach AniList as *_not_in', () {
      expect(s.toQuery(), {
        'genre': ['Action'],
        'not_genre': ['Romance'],
        'not_tag': ['Isekai'],
      });
      expect(BrowseState.fromQuery(s.toQuery(), isAnime: true), s);
      expect(
        s.toVariables(type: MediaType.anime, signedIn: false, showAdult: false),
        allOf(
          containsPair('genres', ['Action']),
          containsPair('notGenres', ['Romance']),
          containsPair('notTags', ['Isekai']),
        ),
      );
    });

    test('a genre both in and out of the query counts as in', () {
      final parsed = BrowseState.fromQuery({
        'genre': ['Drama'],
        'not_genre': ['Drama'],
      }, isAnime: true);
      expect(parsed.genres, ['Drama']);
      expect(parsed.notGenres, isEmpty);
    });

    test('show as "Not …" chips that remove just themselves', () {
      final chips = activeFilters(const BrowseState(notGenres: ['Romance', 'Ecchi']), isAnime: true);
      expect(chips.map((c) => c.label), ['Not Romance', 'Not Ecchi']);
      expect(chips[0].without, const BrowseState(notGenres: ['Ecchi']));
    });

    test('are cleared with the other filters', () {
      expect(const BrowseState(notGenres: ['Romance'], notTags: ['Isekai']).withoutFilters(), const BrowseState());
    });
  });

  group('presets and ranks', () {
    test('names the preset a state is exactly', () {
      expect(activePreset(const BrowseState(), isAnime: true), 'popular');
      expect(activePreset(const BrowseState(sort: BrowseSort.score), isAnime: true), 'top');
      expect(activePreset(const BrowseState(status: 'NOT_YET_RELEASED'), isAnime: false), 'upcoming');
      // a filter on top makes it no preset
      expect(activePreset(const BrowseState(sort: BrowseSort.score, genres: ['Drama']), isAnime: true), isNull);
    });

    test('calls the upcoming list by its name', () {
      expect(browseTitle(const BrowseState(status: 'NOT_YET_RELEASED'), isAnime: true), 'Upcoming anime');
    });

    test('ranks ordered lists, not searches or the newest', () {
      expect(isRanked(const BrowseState(sort: BrowseSort.score)), isTrue);
      expect(isRanked(const BrowseState(genres: ['Drama'])), isTrue);
      expect(isRanked(const BrowseState(sort: BrowseSort.score, q: 'frieren')), isFalse);
      expect(isRanked(const BrowseState(sort: BrowseSort.newest)), isFalse);
    });
  });
}
