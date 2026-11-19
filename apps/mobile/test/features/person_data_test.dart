// Ported from apps/web/src/lib/page-data/person.test.ts, with its fixtures
// (makePersonMedia, makeStaff, makeCharacter) from anilist/fixtures.ts.

import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/catalog/title.dart';
import 'package:miruyo/features/person/markdown.dart';
import 'package:miruyo/features/person/person_data.dart';

Json personMedia([Json overrides = const {}]) => {
  'id': 1,
  'type': 'ANIME',
  'format': 'TV',
  'seasonYear': 2023,
  'startDate': {'year': 2023},
  'title': {'romaji': 'Romaji Title', 'english': 'English Title', 'native': null, 'userPreferred': null},
  'coverImage': {'large': 'https://s4.anilist.co/cover.jpg', 'color': '#d9a75e'},
  'isAdult': false,
  ...overrides,
};

const _empty = {'year': null, 'month': null, 'day': null};

Json staff([Json overrides = const {}]) => {
  'id': 112215,
  'name': {'full': 'Atsumi Tanezaki', 'native': '種﨑敦美', 'userPreferred': null, 'alternative': <String>[]},
  'image': {'large': 'https://s4.anilist.co/staff.jpg'},
  'description': null,
  'primaryOccupations': ['Voice Actor'],
  'gender': 'Female',
  'languageV2': 'Japanese',
  'dateOfBirth': {'year': 1990, 'month': 9, 'day': 27},
  'dateOfDeath': _empty,
  'age': 36,
  'yearsActive': [2008],
  'homeTown': null,
  'bloodType': null,
  'favourites': 3922,
  'isFavourite': false,
  'siteUrl': 'https://anilist.co/staff/112215',
  'characterMedia': {
    'pageInfo': {'total': 0, 'hasNextPage': false},
    'edges': <Json>[],
  },
  'staffMedia': {
    'pageInfo': {'total': 0, 'hasNextPage': false},
    'edges': <Json>[],
  },
  ...overrides,
};

Json character([Json overrides = const {}]) => {
  'id': 176754,
  'name': {
    'full': 'Frieren',
    'native': 'フリーレン',
    'userPreferred': null,
    'alternative': <String>[],
    'alternativeSpoiler': <String>[],
  },
  'image': {'large': 'https://s4.anilist.co/character.jpg'},
  'description': null,
  'gender': 'Female',
  'age': '1000+',
  'bloodType': null,
  'dateOfBirth': _empty,
  'favourites': 22589,
  'isFavourite': false,
  'siteUrl': 'https://anilist.co/character/176754',
  'media': {
    'pageInfo': {'total': 0, 'hasNextPage': false},
    'edges': <Json>[],
  },
  ...overrides,
};

Json role(int id, String full) => {
  'id': id,
  'name': {'full': full, 'userPreferred': null},
  'image': {'medium': null},
};

Json voice(int id, String full, String language, [String? roleNotes]) => {
  'roleNotes': roleNotes,
  'voiceActor': {
    'id': id,
    'name': {'full': full, 'userPreferred': null},
    'image': {'medium': null},
    'languageV2': language,
  },
};

void main() {
  test('formatDate reads whatever parts AniList has', () {
    expect(formatDate(const AniListDate(year: 1990, month: 9, day: 27)), 'Sep 27, 1990');
    expect(formatDate(const AniListDate(month: 12, day: 25)), 'Dec 25');
    expect(formatDate(const AniListDate(year: 1990)), '1990');
    expect(formatDate(const AniListDate()), '');
  });

  group('createStaffContent', () {
    test('builds the header: names, facts from the API and the description, and the bio', () {
      final content = createStaffContent(
        staff({
          'name': {
            'full': 'Atsumi Tanezaki',
            'native': '種﨑敦美',
            'userPreferred': 'Atsumi Tanezaki',
            'alternative': ['種崎敦美', 'atsumi tanezaki', 'Hana Kiritani'],
          },
          'homeTown': 'Oita Prefecture, Japan',
          'description': '__Height:__ 157 cm\n\nA Japanese voice actress.',
        }),
      ).header;
      expect(content.name, 'Atsumi Tanezaki');
      expect(content.native, '種﨑敦美');
      expect(content.altNames, ['種崎敦美', 'Hana Kiritani']);
      expect(content.favourites, '4k');
      expect(content.anilist.toString(), 'https://anilist.co/staff/112215');
      expect(content.facts, [
        (label: 'Occupation', value: 'Voice Actor'),
        (label: 'Birthday', value: 'Sep 27, 1990'),
        (label: 'Age', value: '36'),
        (label: 'Gender', value: 'Female'),
        (label: 'Years active', value: '2008 – present'),
        (label: 'Hometown', value: 'Oita Prefecture, Japan'),
        (label: 'Language', value: 'Japanese'),
        (label: 'Height', value: '157 cm'),
      ]);
      expect(content.bio, [
        [const Segment('A Japanese voice actress.')],
      ]);
    });

    test('says when someone died instead of their age', () {
      final facts = createStaffContent(
        staff({
          'dateOfDeath': {'year': 2020, 'month': 1, 'day': 2},
          'yearsActive': [1980],
        }),
      ).header.facts;
      expect(facts, contains((label: 'Died', value: 'Jan 2, 2020')));
      expect(facts, contains((label: 'Years active', value: '1980 – ?')));
      expect(facts.where((f) => f.label == 'Age'), isEmpty);
    });

    test('makes a card per character voiced, leaving out 18+ titles unless allowed', () {
      final raw = staff({
        'characterMedia': {
          'pageInfo': {'total': 3, 'hasNextPage': true},
          'edges': [
            {
              'characterRole': 'MAIN',
              'characters': [role(10, 'Frieren')],
              'node': personMedia({'id': 1}),
            },
            {
              'characterRole': 'SUPPORTING',
              'characters': [role(11, 'Twin A'), role(12, 'Twin B'), null],
              'node': personMedia({
                'id': 2,
                'format': 'MOVIE',
                'startDate': {'year': 2026},
              }),
            },
            {
              'characterRole': 'MAIN',
              'characters': [role(13, 'Hidden')],
              'node': personMedia({'id': 3, 'isAdult': true}),
            },
          ],
        },
      });
      final content = createStaffContent(raw, titles: TitlePreference.english);
      expect(content.voiceRoles.map((r) => (r.character.name, r.role, r.media.title, r.media.meta)), [
        ('Frieren', 'Main', 'English Title', '2023 · TV'),
        ('Twin A', 'Supporting', 'English Title', '2026 · Movie'),
        ('Twin B', 'Supporting', 'English Title', '2026 · Movie'),
      ]);
      expect(content.voiceHasMore, isTrue);
      expect(content.voiceFirst, isTrue);
      expect(createStaffContent(raw, adult: true).voiceRoles, hasLength(4));
    });

    test('folds several roles on one title into one credit, and leads with credits for authors', () {
      final content = createStaffContent(
        staff({
          'primaryOccupations': ['Mangaka'],
          'staffMedia': {
            'pageInfo': {'total': 3, 'hasNextPage': false},
            'edges': [
              {
                'staffRole': 'Original Creator',
                'node': personMedia({'id': 1}),
              },
              {
                'staffRole': 'Story & Art',
                'node': personMedia({'id': 1}),
              },
              {
                'staffRole': 'Original Creator',
                'node': personMedia({'id': 2, 'type': 'MANGA'}),
              },
            ],
          },
        }),
      );
      expect(content.credits.map((c) => (c.media.id, c.roles)), [
        (1, 'Original Creator · Story & Art'),
        (2, 'Original Creator'),
      ]);
      expect(content.voiceFirst, isFalse);
    });
  });

  test('createCharacterContent keeps spoiler names apart and lists appearances with every voice', () {
    final content = createCharacterContent(
      character({
        'name': {
          'full': 'Frieren',
          'native': 'フリーレン',
          'userPreferred': 'Frieren',
          'alternative': ['The Slayer'],
          'alternativeSpoiler': ['Great Mage'],
        },
        'media': {
          'pageInfo': {'total': 3, 'hasNextPage': false},
          'edges': [
            {
              'characterRole': 'MAIN',
              'voiceActorRoles': [
                voice(1, 'Atsumi Tanezaki', 'Japanese'),
                voice(2, 'Mallorie Rodak', 'English'),
                voice(3, 'Marie Nonnenmacher', 'French'),
                voice(1, 'Atsumi Tanezaki', 'Japanese'),
              ],
              'node': personMedia({'id': 1}),
            },
            {
              'characterRole': 'MAIN',
              'voiceActorRoles': [
                voice(4, 'Ji-Hyun Lee', 'Korean'),
                voice(5, 'Mallorie Rodak (young)', 'English', '(young)'),
              ],
              'node': personMedia({'id': 2}),
            },
            {
              'characterRole': 'MAIN',
              'voiceActorRoles': <Json>[],
              'node': personMedia({'id': 3, 'type': 'MANGA', 'format': 'MANGA'}),
            },
          ],
        },
      }),
    );
    expect(content.header.altNames, ['The Slayer']);
    expect(content.header.spoilerNames, ['Great Mage']);
    expect(content.header.facts, [(label: 'Gender', value: 'Female'), (label: 'Age', value: '1000+')]);
    expect(content.appearances.map((a) => (a.media.id, a.role, a.voices.map((v) => v.name).join(', '))), [
      (1, 'Main', 'Atsumi Tanezaki, Mallorie Rodak, Marie Nonnenmacher'),
      (2, 'Main', 'Ji-Hyun Lee, Mallorie Rodak (young)'),
      (3, 'Main', ''),
    ]);
    expect(content.appearances[1].voices[1].note, '(young)');
    // Japanese, then English, then the rest by how many titles
    expect(content.languages, ['Japanese', 'English', 'French', 'Korean']);
  });
}
