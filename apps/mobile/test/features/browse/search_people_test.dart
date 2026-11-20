// Ported from apps/web/src/lib/page-data/search-people.test.ts.

import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/catalog/title.dart';
import 'package:miruyo/features/browse/search_people.dart';

const Json data = {
  'characters': {
    'characters': [
      {
        'id': 1,
        'name': {'userPreferred': 'Frieren'},
        'image': {'large': 'https://s4.anilist.co/c.png', 'medium': null},
        'media': {
          'nodes': [
            {
              'title': {
                'userPreferred': 'Sousou no Frieren',
                'english': "Frieren: Beyond Journey's End",
                'romaji': 'Sousou no Frieren',
              },
            },
          ],
        },
      },
    ],
  },
  'staff': {
    'staff': [
      {
        'id': 2,
        'name': {'userPreferred': 'Atsumi Tanezaki'},
        'image': null,
        'primaryOccupations': ['Voice Actor', 'Singer'],
      },
    ],
  },
  'users': {
    'users': [
      {
        'id': 3,
        'name': 'Josh',
        'avatar': {'large': null, 'medium': 'https://s4.anilist.co/a.png'},
      },
      {'id': 4, 'name': 'a/b c', 'avatar': null},
    ],
  },
  'studios': {
    'studios': [
      {'id': 11, 'name': 'MADHOUSE', 'siteUrl': 'https://anilist.co/studio/11', 'isAnimationStudio': true},
      {'id': 12, 'name': 'Aniplex', 'siteUrl': 'javascript:alert(1)', 'isAnimationStudio': false},
      {'id': 13, 'name': 'Odd Studio', 'siteUrl': 'https://evil.example/13', 'isAnimationStudio': true},
    ],
  },
};

void main() {
  test('links people to their miruyo pages, with what they are known for', () {
    final r = buildPeopleResults(data, isAnime: true, titles: TitlePreference.english);
    final c = r.characters.single;
    expect(
      (c.id, c.name, c.image, c.sub, c.href),
      (1, 'Frieren', 'https://s4.anilist.co/c.png', "Frieren: Beyond Journey's End", '/character/1'),
    );
    expect((r.staff.single.sub, r.staff.single.href), ('Voice Actor', '/staff/2'));
    // signed in, the account's own title language
    expect(
      buildPeopleResults(data, isAnime: true, titles: TitlePreference.userPreferred).characters.single.sub,
      'Sousou no Frieren',
    );
  });

  test('links users to their pages in either mode, the name encoded', () {
    for (final isAnime in [true, false]) {
      final users = buildPeopleResults(data, isAnime: isAnime, titles: TitlePreference.english).users;
      expect(users.map((u) => (u.id, u.name, u.image, u.sub, u.href)), [
        (3, 'Josh', 'https://s4.anilist.co/a.png', null, '/user/Josh'),
        (4, 'a/b c', null, null, '/user/a%2Fb%20c'),
      ]);
    }
  });

  test('keeps animation studios, linking to their miruyo pages', () {
    final studios = buildPeopleResults(data, isAnime: true, titles: TitlePreference.english).studios;
    expect(studios.map((s) => (s.id, s.name, s.href)), [
      (11, 'MADHOUSE', '/studio/11'),
      (13, 'Odd Studio', '/studio/13'),
    ]);
  });

  test('leaves studios out of manga searches', () {
    expect(buildPeopleResults(data, isAnime: false, titles: TitlePreference.english).studios, isEmpty);
  });

  test('knows when nothing matched', () {
    final none = buildPeopleResults(
      {
        'characters': {'characters': <Json>[]},
        'staff': {'staff': <Json>[]},
        'users': {'users': <Json>[]},
        'studios': {'studios': <Json>[]},
      },
      isAnime: true,
      titles: TitlePreference.english,
    );
    expect(none.isNotEmpty, isFalse);
    expect(buildPeopleResults(data, isAnime: false, titles: TitlePreference.english).isNotEmpty, isTrue);
  });
}
