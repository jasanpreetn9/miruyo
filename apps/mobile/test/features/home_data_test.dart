// Ported from apps/web/src/lib/page-data/home.test.ts (Upcoming).

import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/features/home/home_data.dart';

Json media(int id, {String? format = 'TV', int? inDays}) => {
  'id': id,
  'type': 'ANIME',
  'format': format,
  'status': 'NOT_YET_RELEASED',
  'title': {'romaji': 'T$id'},
  'coverImage': <String, Object>{},
  'studios': {
    'nodes': [
      {'name': 'Studio One'},
    ],
  },
  if (inDays != null)
    'nextAiringEpisode': {'episode': 1, 'airingAt': 1800000000 + inDays * 86400, 'timeUntilAiring': inDays * 86400},
};

Json feed(List<Json> upcoming) => {
  'upcoming': {'media': upcoming},
};

void main() {
  test('puts dated premieres first, soonest first, and shows six', () {
    final content = createFeedContent(
      feed([media(1), media(2, inDays: 75), media(3), media(4, inDays: 66), media(5), media(6), media(7)]),
      Mode.anime,
    );
    // dated by date; the rest keep AniList's (popularity) order
    expect(content.upcoming.map((i) => i.title.id), [4, 2, 1, 3, 5, 6]);
    expect(content.upcoming, hasLength(upcomingShown));
    expect(content.upcoming[2].countdown, isNull);
  });

  test('leaves out a format AniList has not announced', () {
    final content = createFeedContent(feed([media(9, format: null)]), Mode.anime);
    expect(content.upcoming.single.by, 'Studio One');
  });

  test('shortens a long sequel in the middle, keeping which season it is', () {
    expect(
      shortTitle('Sekai Saikou no Ansatsusha, Isekai Kizoku ni Tensei suru 2nd Season'),
      'Sekai Saikou no Ansatsusha, Isekai… 2nd Season',
    );
    expect(shortTitle('One Punch Man Season 3 Part 2'), 'One Punch Man Season 3 Part 2');
    // no season to keep: left whole for the row to clamp
    const long = 'MASHLE: MAGIC AND MUSCLES The Tri-Magicathlon Divine Visionary Candidate Exam Arc';
    expect(shortTitle(long), long);
  });
}
