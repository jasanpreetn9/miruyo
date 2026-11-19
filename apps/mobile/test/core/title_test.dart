import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/catalog/title.dart';

Json media([Json overrides = const {}]) => {
  'id': 1,
  'type': 'ANIME',
  'format': 'TV',
  'status': 'RELEASING',
  'season': 'FALL',
  'seasonYear': 2026,
  'episodes': 28,
  'averageScore': 91,
  'isAdult': false,
  'title': {
    'romaji': 'Sousou no Frieren',
    'english': "Frieren: Beyond Journey's End",
    'native': '葬送のフリーレン',
    'userPreferred': 'Sousou no Frieren',
  },
  'description': 'Decades after<br>the party &amp; all.',
  'genres': ['Adventure', 'Drama'],
  'coverImage': {'extraLarge': 'https://x/xl.jpg', 'large': 'https://x/l.jpg', 'color': '#d9a75e'},
  'bannerImage': null,
  'studios': {
    'nodes': [
      {'id': 1, 'name': 'Madhouse'},
    ],
  },
  'nextAiringEpisode': {'episode': 9, 'airingAt': 1800000000, 'timeUntilAiring': 3600},
  ...overrides,
};

void main() {
  group('adaptMedia', () {
    test('turns AniList media into a title', () {
      final t = adaptMedia(AniListMedia.fromJson(media()));
      expect(t.title, 'Sousou no Frieren');
      expect(t.format, 'TV');
      expect(t.score, 9.1);
      expect(t.season, 'Fall 2026');
      expect(t.status, 'Releasing');
      expect(t.studio, 'Madhouse');
      expect(t.synopsis, 'Decades after\nthe party & all.');
      expect(t.next?.ep, 9);
      expect(t.coverUrl, 'https://x/xl.jpg');
      expect(t.thumbUrl, 'https://x/l.jpg');
      expect(t.meta, 'TV · 28 eps · Fall 2026');
    });

    test('signed out, prefers English titles', () {
      final t = adaptMedia(AniListMedia.fromJson(media()), titles: TitlePreference.english);
      expect(t.title, "Frieren: Beyond Journey's End");
    });

    test('falls back through the title languages', () {
      final t = adaptMedia(
        AniListMedia.fromJson(
          media({
            'title': {'romaji': null, 'english': null, 'native': 'X', 'userPreferred': null},
          }),
        ),
      );
      expect(t.title, 'X');
    });

    test('carries the list entry a feed query attached', () {
      final t = adaptMedia(
        AniListMedia.fromJson(
          media({
            'mediaListEntry': {'id': 5, 'status': 'CURRENT', 'progress': 7},
          }),
        ),
      );
      expect(t.me?.status, MediaListStatus.current);
      expect(t.me?.progress, 7);
    });

    test('marks a missing cover', () {
      final t = adaptMedia(
        AniListMedia.fromJson(
          media({
            'coverImage': {'color': null},
          }),
        ),
      );
      expect(t.coverMissing, isTrue);
    });
  });

  group('Title', () {
    Title make(Json overrides) => adaptMedia(AniListMedia.fromJson(media(overrides)));

    test('derives anime units and labels', () {
      final t = make({});
      expect((t.isAnime, t.unit, t.total, t.countLabel), (true, 'EP', 28, '28 eps'));
    });

    test('derives manga units and labels, including ongoing series', () {
      final t = make({'type': 'MANGA', 'chapters': null});
      expect((t.isAnime, t.unit, t.total, t.countLabel), (false, 'CH', null, 'Ongoing'));
    });

    test('shows an unknown episode count as ?', () => expect(make({'episodes': null}).countLabel, '? eps'));

    test('meta leaves out what AniList does not know', () {
      final t = make({'format': null, 'episodes': null, 'status': 'RELEASING'});
      expect((t.knownFormat, t.knownCount), (null, 'Ongoing'));
      expect(make({'episodes': null, 'status': 'NOT_YET_RELEASED'}).knownCount, isNull);
    });

    test('truncates long titles for short', () {
      final long = 'x' * 40;
      expect(
        make({
          'title': {'userPreferred': long},
        }).short,
        '${'x' * 32}…',
      );
      expect(make({}).short, 'Sousou no Frieren');
    });
  });
}
