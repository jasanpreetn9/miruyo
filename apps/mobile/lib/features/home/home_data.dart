// Home's discovery rows, ported from apps/web/src/lib/page-data/home.ts
// (createFeedContent).

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anilist/client.dart';
import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/title.dart';
import '../../core/list/list_entry.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';

class UpcomingItem {
  const UpcomingItem({
    required this.title,
    required this.name,
    required this.when,
    required this.by,
    required this.countdown,
  });

  final Title title;

  /// The title, a long sequel's shortened in the middle (shortTitle).
  final String name;

  /// The season it's slated for, or "Date TBA".
  final String when;

  /// "TV · Madhouse"; a format AniList hasn't announced is left out.
  final String by;

  /// "Premieres in 3d 4h", only once AniList has a date (the season says when until then).
  final String? countdown;
}

/// Upcoming on Home: six; See all has the rest.
const upcomingShown = 6;

/// A sequel's mark at the end of its title: "2nd Season", "Season 3 Part 2", "II".
final _sequelMark = RegExp(
  r'\s((?:\d+(?:st|nd|rd|th)\s+Season|Season\s+\d+)(?:\s+Part\s+\d+)?|Part\s+\d+|II|III|IV|\d+)$',
  caseSensitive: false,
);

/// A long sequel's title shortened in the middle, so the part that says which
/// season it is survives: "Sekai Saikou no Ansatsusha, Isekai… 2nd Season".
/// Anything else is left for the row to clamp.
String shortTitle(String title, {int max = 52}) {
  if (title.length <= max) return title;
  final mark = _sequelMark.firstMatch(title)?[1];
  if (mark == null) return title;
  final head = title
      .substring(0, max - mark.length - 2)
      .replaceFirst(RegExp(r'\s+\S*$'), '')
      .replaceFirst(RegExp(r'[\s,:;\-–]+$'), '');
  return '$head… $mark';
}

class FeedContent {
  const FeedContent({
    required this.trending,
    required this.popularHeading,
    required this.popularSubtitle,
    required this.popular,
    required this.upcomingHeading,
    required this.upcoming,
    this.savedAt,
  });

  final List<Title> trending;
  final String popularHeading;
  final String popularSubtitle;
  final List<Title> popular;
  final String upcomingHeading;
  final List<UpcomingItem> upcoming;

  /// Set when AniList couldn't be reached and this is the device's copy.
  final DateTime? savedAt;
}

FeedContent createFeedContent(Json feed, Mode mode, {TitlePreference titles = TitlePreference.userPreferred}) {
  final isAnime = mode.isAnime;
  List<Title> adapt(String key) => [
    for (final m in mediaList((feed[key] as Json?)?['media'])) adaptMedia(m, titles: titles),
  ];
  final popular = adapt('popularThisSeason');
  return FeedContent(
    trending: adapt('trending'),
    popularHeading: isAnime ? 'Popular this season' : 'Popular releasing',
    popularSubtitle: isAnime ? (popular.firstOrNull?.season ?? 'This season') : 'Updated weekly',
    popular: popular,
    upcomingHeading: isAnime ? 'Upcoming' : 'Newly serialized',
    upcoming: [
      for (final t in _upcoming(adapt('upcoming')))
        UpcomingItem(
          title: t,
          name: shortTitle(t.title),
          when: t.season ?? 'Date TBA',
          // a format AniList hasn't announced isn't worth saying
          by: isAnime ? [t.knownFormat, t.studio].whereType<String>().join(' · ') : '',
          countdown: t.next != null ? 'Premieres in ${_in(t.next!.airingAt)}' : null,
        ),
    ],
  );
}

/// The ones with a premiere date first, soonest first; the rest in
/// AniList's popularity order. Six of them.
List<Title> _upcoming(List<Title> titles) => [
  ...titles.where((t) => t.next != null).toList()..sort((a, b) => a.next!.airingAt.compareTo(b.next!.airingAt)),
  ...titles.where((t) => t.next == null),
].take(upcomingShown).toList();

String _in(int airingAt) {
  final s = airingAt - DateTime.now().millisecondsSinceEpoch ~/ 1000;
  final d = s ~/ 86400, h = (s % 86400) ~/ 3600, m = (s % 3600) ~/ 60;
  if (s <= 0) return 'now';
  if (d > 0) return h > 0 ? '${d}d ${h}h' : '${d}d';
  return h > 0 ? '${h}h ${m.toString().padLeft(2, '0')}m' : '${m}m';
}

/// The rows for a mode. Waits until the session knows whether someone is
/// signed in, since that decides the token, title language and list state.
final homeFeedProvider = FutureProvider.autoDispose.family<FeedContent, Mode>((ref, mode) async {
  ref.cacheFor(screenCache);
  final session = ref.watch(sessionProvider.select((s) => (s.authState, s.titles)));
  final client = ref.watch(anilistClientProvider);
  final store = ref.read(listStoreProvider.notifier);
  final since = store.stamp();
  final Fetched<Json> fetched = await client.fetchHomeFeed(mode.mediaType);
  final content = createFeedContent(fetched.data, mode, titles: session.$2);
  // share the list entries the feed carries with every card
  if (session.$1 == AuthState.signedIn) {
    store.seed([
      for (final t in [...content.trending, ...content.popular, ...content.upcoming.map((u) => u.title)])
        ?ListEntry.fromTitle(t),
    ], since: since);
  }
  return fetched.fromDevice
      ? FeedContent(
          trending: content.trending,
          popularHeading: content.popularHeading,
          popularSubtitle: content.popularSubtitle,
          popular: content.popular,
          upcomingHeading: content.upcomingHeading,
          upcoming: content.upcoming,
          savedAt: fetched.savedAt,
        )
      : content;
});

/// The poster wall behind the signed-out pitch: public trending, in English.
final publicTrendingProvider = FutureProvider.autoDispose.family<List<Title>, Mode>((ref, mode) async {
  ref.cacheFor(screenCache);
  final media = await ref.watch(anilistClientProvider).fetchPublicTrending(mode.mediaType);
  return [for (final m in media) adaptMedia(m, titles: TitlePreference.english)];
});
