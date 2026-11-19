// A studio's page (/studio/:id), ported from
// apps/web/src/lib/page-data/studio.ts: what it is, then the titles it made,
// most popular or newest first. Titles it only helped on (as a producer, say)
// are marked, since AniList lists those with its own productions. Titles
// follow the viewer's AniList preference when signed in, English otherwise;
// 18+ titles only show when the account allows them.

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/title.dart';
import '../../core/providers.dart';
import '../detail/detail_data.dart' show formatCompact;
import '../person/person_data.dart';
import '../profile/profile_data.dart' show anilistLink;

/// Where a studio opens in miruyo.
String studioHref(int id) => '/studio/$id';

class StudioTitle {
  const StudioTitle({required this.key, required this.media, this.caption});

  final String key;
  final MediaCard media;

  /// "Producer" when it isn't the studio's own production.
  final String? caption;
}

class StudioContent {
  const StudioContent({
    required this.id,
    required this.header,
    required this.kind,
    required this.titles,
    required this.hasMore,
  });

  final int id;

  /// The name, favourites and AniList link, for the person pages' layout
  /// (a studio has no picture, other names or bio).
  final PersonHeader header;

  /// "Animation studio" or "Studio" (a producer or publisher).
  final String kind;
  final List<StudioTitle> titles;
  final bool hasMore;
}

List<Json> _list(Object? raw) => (raw as List? ?? const []).whereType<Json>().toList();

StudioContent createStudioContent(
  Json studio, {
  TitlePreference titles = TitlePreference.userPreferred,
  bool adult = false,
}) {
  final id = (studio['id'] as num).toInt();
  final kind = studio['isAnimationStudio'] == true ? 'Animation studio' : 'Studio';
  final media = studio['media'] as Json?;
  final seen = <int>{};
  return StudioContent(
    id: id,
    kind: kind,
    header: PersonHeader(
      name: studio['name'] as String? ?? '',
      native: null,
      altNames: const [],
      spoilerNames: const [],
      image: null,
      facts: [(label: 'Type', value: kind)],
      bio: const [],
      favourites: formatCompact((studio['favourites'] as num?)?.toInt()),
      isFavourite: studio['isFavourite'] == true,
      anilist: anilistLink(studio['siteUrl'] as String?, 'https://anilist.co/studio/$id')!,
    ),
    titles: [
      for (final edge in _list(media?['edges']))
        if (edge['node'] case final Json node
            when (adult || node['isAdult'] != true) && seen.add((node['id'] as num).toInt()))
          StudioTitle(
            key: '${node['id']}',
            media: mediaCardOf(node, titles),
            caption: edge['isMainStudio'] == true ? null : 'Producer',
          ),
    ],
    hasMore: (media?['pageInfo'] as Json?)?['hasNextPage'] == true,
  );
}

/// A studio as AniList sends it, with the first page of titles in [sort].
final studioProvider = FutureProvider.autoDispose.family<Json, ({int id, PersonSort sort})>((ref, key) {
  ref.cacheFor(screenCache);
  final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
  return orNotFound(() async {
    final raw = await ref.watch(anilistClientProvider).fetchStudio(key.id, signedIn: signedIn, sort: key.sort);
    loadListState(ref.read, mediaIdsOf(raw['media'] as Json?)).ignore();
    return raw;
  });
});
