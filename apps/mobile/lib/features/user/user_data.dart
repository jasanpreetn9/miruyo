// Someone's page (/user/:name), yours included (it's your profile), ported
// from apps/web/src/lib/page-data/user.ts and state/user-page.svelte.ts:
// their profile, and their lists read-only. The list is My List's view
// (buildListView) without the editing: their scores arrive out of 10 with
// decimals (fetchUserList), whatever their own score format, so they read
// the same for everyone.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anilist/client.dart' show isListRefresh;
import '../../core/anilist/queries.dart' show userListQuery;
import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/title.dart';
import '../../core/providers.dart';
import '../list/list_data.dart';
import '../person/markdown.dart';
import '../person/person_data.dart' show PersonHeader;
import '../profile/profile_data.dart';

/// The sorts on someone else's list: My List's, less "Most to watch", which
/// is about your next episode.
List<ListSort> userSortsFor(MediaListStatus status, {required bool isAnime}) => [
  for (final s in ListSort.on(status, isAnime: isAnime))
    if (s != ListSort.toWatch) s,
];

/// Completed opens best first (what people look at someone's list for); the rest, latest first.
ListSort defaultUserSort(MediaListStatus status) =>
    status == MediaListStatus.completed ? ListSort.score : ListSort.updated;

/// Someone's list as this viewer is shown it: without 18+ titles unless
/// [adult] (the viewer's own setting, or the list is the viewer's). The list
/// tabs, Stats and the facts card all count this, so their totals match.
List<CollectionEntry> forViewer(List<CollectionEntry> entries, {required bool adult}) => adult
    ? entries
    : [
        for (final e in entries)
          if (!e.media.isAdult) e,
      ];

/// Their list on one status, with every status's count (empty ones left out).
MyListView buildUserList(
  List<CollectionEntry> entries, {
  required MediaListStatus status,
  required bool isAnime,
  required bool adult,
  required int now,
  ListSort? sort,
  String filter = '',
  String genre = '',
  String country = '',
  int? year,
  TitlePreference titles = TitlePreference.userPreferred,
  ScoreFormat scoreFormat = ScoreFormat.point10Decimal,
}) {
  final view = buildListView(
    forViewer(entries, adult: adult),
    tab: status,
    sort: sort ?? defaultUserSort(status),
    filter: filter,
    genre: genre,
    country: country,
    year: year,
    isAnime: isAnime,
    titles: titles,
    scoreFormat: scoreFormat,
    now: now,
  );
  return MyListView(
    tabs: [
      for (final t in view.tabs)
        if (t.count > 0 || t.status == status) t,
    ],
    rows: view.rows,
    formats: view.formats,
    summary: view.summary,
    genres: view.genres,
    countries: view.countries,
    years: view.years,
  );
}

/// "matchai's" / "Ines'".
String possessive(String name) => name.endsWith('s') ? '$name’' : '$name’s';

/// Whether a profile is the viewer's own (names match whatever the case).
bool isOwnProfile(String name, String? viewerName) =>
    viewerName != null && viewerName.toLowerCase() == name.toLowerCase();

/// A user page's header, in a staff page's shape: the avatar, "Follows you"
/// under the name, the bio, and a facts card. [numbers] are the Stats cards
/// for the mode (Total anime, Episodes watched…), so the card and Stats never
/// disagree; AniList's own totals leave out Planning and lag.
PersonHeader userHeader(Json account, {required bool own, required String? memberSince, required List<Fact> numbers}) {
  final name = account['name'] as String? ?? '';
  final since = memberSince?.replaceFirst(RegExp('^Member since '), '');
  return PersonHeader(
    name: name,
    native: !own && account['isFollower'] == true ? 'Follows you' : null,
    altNames: const [],
    spoilerNames: const [],
    image: (account['avatar'] as Json?)?['large'] as String?,
    facts: [
      if (since != null) (label: 'Member since', value: since),
      for (final f in numbers)
        if (f.value.isNotEmpty && f.value != '—') f,
    ],
    bio: parseDescription(account['about'] as String?).paragraphs,
    favourites: '',
    isFavourite: false,
    anilist: anilistLink(account['siteUrl'] as String?, 'https://anilist.co/user/${Uri.encodeComponent(name)}')!,
  );
}

/// Someone's profile by name, with their favourite titles.
final userProfileProvider = FutureProvider.autoDispose.family<ProfileData, String>((ref, name) {
  ref.cacheFor(screenCache);
  final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
  return ref.watch(anilistClientProvider).fetchUserProfile(name, signedIn: signedIn);
});

/// Someone else's list, as anyone sees it. (Your own is My List's,
/// listCollectionProvider.)
final userListProvider = FutureProvider.autoDispose.family<List<CollectionEntry>, ({int id, MediaType type})>((
  ref,
  key,
) {
  ref.cacheFor(screenCache);
  final client = ref.watch(anilistClientProvider);
  // a copy served stale has been replaced behind the screen: build again
  final refreshed = client.refreshed.listen((r) {
    if (isListRefresh(r, userListQuery, key.id, key.type)) ref.invalidateSelf();
  });
  ref.onDispose(refreshed.cancel);
  return client.fetchUserList(key.id, key.type);
});
