import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/catalog/title.dart';
import 'package:miruyo/features/detail/detail_data.dart';

void main() {
  Json edge(String relationType, int id, String type, String format, int year) => {
    'relationType': relationType,
    'node': {
      'id': id,
      'type': type,
      'format': format,
      'status': 'FINISHED',
      'startDate': {'year': year, 'month': 1, 'day': 1},
      'title': {'romaji': 'R$id', 'userPreferred': 'P$id'},
      'coverImage': {'large': null, 'color': null},
    },
  };

  test("an anime's novel or manga comes first even when AniList files it as an adaptation", () {
    // Kusuriya no Hitorigoto's edges, as AniList sends them
    final content = createDetailContent({
      'id': 161645,
      'type': 'ANIME',
      'format': 'TV',
      'title': {'romaji': 'Kusuriya no Hitorigoto'},
      'coverImage': <String, Object>{},
      'relations': {
        'edges': [
          edge('ALTERNATIVE', 4, 'MANGA', 'MANGA', 2017),
          edge('SEQUEL', 3, 'ANIME', 'TV', 2026),
          edge('SIDE_STORY', 5, 'ANIME', 'ONA', 2023),
          edge('SEQUEL', 2, 'ANIME', 'TV', 2025),
          edge('ADAPTATION', 1, 'MANGA', 'NOVEL', 2014),
          edge('PREQUEL', 6, 'ANIME', 'TV', 2020),
        ],
      },
    });
    expect(content.relations.map((r) => (r.relation, r.title)), [
      ('Source', 'P1'),
      ('Prequel', 'P6'),
      ('Sequel', 'P2'),
      ('Sequel', 'P3'),
      ('Side story', 'P5'),
      ('Alternative', 'P4'),
    ]);
  });

  test('from a manga, an anime adaptation stays an adaptation', () {
    expect(relationKind('ADAPTATION', MediaType.manga, MediaType.anime), 'ADAPTATION');
    expect(relationKind('ADAPTATION', MediaType.anime, MediaType.manga), 'SOURCE');
  });

  Json detail([Json extra = const {}]) => {
    'id': 1,
    'type': 'ANIME',
    'format': 'TV',
    'title': {'romaji': 'Sousou no Frieren', 'userPreferred': 'Sousou no Frieren'},
    'coverImage': <String, Object>{},
    ...extra,
  };

  test('ranks tags, flags spoilers and keeps 18+ tags for accounts that show them', () {
    Json tag(String name, int rank, [Json extra = const {}]) => {
      'id': rank,
      'name': name,
      'rank': rank,
      'description': null,
      'isMediaSpoiler': false,
      'isGeneralSpoiler': false,
      'isAdult': false,
      ...extra,
    };
    final media = detail({
      'tags': [
        tag('Magic', 80),
        tag('Travel', 96),
        tag('Time Skip', 82, {'isMediaSpoiler': true}),
        tag('Tragedy', 70, {'isGeneralSpoiler': true}),
        tag('Nudity', 40, {'isAdult': true}),
      ],
    });
    expect(createDetailContent(media).tags.map((t) => (t.name, t.rank, t.spoiler)), [
      ('Travel', 96, false),
      ('Time Skip', 82, true),
      ('Magic', 80, false),
      ('Tragedy', 70, true),
    ]);
    expect(createDetailContent(media, adult: true).tags.map((t) => t.name), contains('Nudity'));
  });

  test('splits links into where to watch and the rest, safe ones only', () {
    Json link(int id, String site, [Json extra = const {}]) => {
      'id': id,
      'url': 'https://example.com/$id',
      'site': site,
      'type': 'STREAMING',
      'language': null,
      'color': null,
      'icon': null,
      'notes': null,
      'isDisabled': false,
      ...extra,
    };
    final content = createDetailContent(
      detail({
        'externalLinks': [
          link(1, 'MANGA Plus', {'language': 'Thai'}),
          link(2, 'VIZ', {'language': 'English', 'color': '#FF0000'}),
          link(3, 'YouTube', {'notes': 'Muse Asia', 'icon': 'https://s4.anilist.co/icon.png', 'color': 'red;}'}),
          link(4, 'Gone', {'isDisabled': true}),
          link(5, 'Sneaky', {'url': 'javascript:alert(1)'}),
          link(6, 'Official Site', {'type': 'INFO', 'language': 'Japanese'}),
          link(7, 'Twitter', {'type': 'SOCIAL', 'icon': 'http://insecure.example/icon.png'}),
        ],
      }),
    );
    // no language given first, then English, then the rest
    expect(content.watch.map((l) => (l.site, l.detail)), [
      ('YouTube', 'Muse Asia'),
      ('VIZ', ''),
      ('MANGA Plus', 'Thai'),
    ]);
    expect((content.watch[0].icon.toString(), content.watch[0].color), ('https://s4.anilist.co/icon.png', null));
    expect(content.watch[1].color, '#FF0000');
    expect(content.links.map((l) => (l.site, l.detail, l.icon)), [
      ('Twitter', '', null),
      ('Official Site', 'Japanese', null),
    ]);
  });

  test("the Studio row opens the studio's page", () {
    final content = createDetailContent({
      'id': 1,
      'type': 'ANIME',
      'format': 'TV',
      'title': {'romaji': 'Frieren'},
      'coverImage': <String, Object>{},
      'studios': {
        'nodes': [
          {'id': 11, 'name': 'MADHOUSE'},
        ],
      },
    });
    final row = content.info.firstWhere((r) => r.label == 'Studio');
    expect((row.value, row.href), ('MADHOUSE', '/studio/11'));
    expect(content.info.where((r) => r.label != 'Studio').every((r) => r.href == null), isTrue);
  });

  test('lists other names once, leaving out the ones the headline shows', () {
    final content = createDetailContent(
      detail({
        'title': {
          'romaji': 'Sousou no Frieren',
          'english': 'Frieren',
          'native': '葬送のフリーレン',
          'userPreferred': 'Sousou no Frieren',
        },
        'synonyms': ['Frieren at the Funeral', ' frieren ', 'Frieren at the Funeral', '葬送的芙莉蓮'],
      }),
    );
    expect(content.synonyms, ['Frieren at the Funeral', '葬送的芙莉蓮']);
  });

  test('counts names that differ only in case as one', () {
    final content = createDetailContent(
      detail({
        'title': {'romaji': 'ONE PIECE', 'english': 'One Piece', 'native': 'ONE PIECE', 'userPreferred': null},
      }),
      titles: TitlePreference.english,
    );
    expect(content.title.title, 'One Piece');
    expect(content.altTitles, '');
  });
}
