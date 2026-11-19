// The staff and character pages (/staff/:id, /character/:id), ported from
// apps/web/src/lib/page-data/person.ts: who someone is, then the titles
// they're in. Titles follow the viewer's AniList preference when signed in,
// English otherwise; 18+ titles only show when the account allows them.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderListenable;

import '../../core/anilist/errors.dart';
import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/cover_color.dart';
import '../../core/catalog/humanize.dart';
import '../../core/catalog/title.dart';
import '../../core/list/list_entry.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';
import '../detail/detail_data.dart' show formatCompact, humanizeEnum;
import '../profile/profile_data.dart' show anilistLink;
import 'markdown.dart';

/// A title in someone's roles.
class MediaCard {
  const MediaCard({
    required this.id,
    required this.title,
    required this.meta,
    required this.colors,
    required this.isAnime,
    this.cover,
  });

  final int id;
  final String title;

  /// "2023 · TV".
  final String meta;
  final String? cover;

  /// The frame's colour while the cover loads.
  final CoverColors colors;
  final bool isAnime;
}

class PersonLink {
  const PersonLink({required this.id, required this.name, this.image});

  final int id;
  final String name;
  final String? image;
}

class VoiceRoleCard {
  const VoiceRoleCard({required this.key, required this.media, required this.character, required this.role});

  final String key;
  final MediaCard media;
  final PersonLink character;

  /// "Main" / "Supporting" / "Background".
  final String role;
}

class CreditCard {
  const CreditCard({required this.key, required this.media, required this.roles});

  final String key;
  final MediaCard media;

  /// Every role they had on it: "Original Creator · Story & Art".
  final String roles;
}

class VoiceActor extends PersonLink {
  const VoiceActor({required super.id, required super.name, super.image, required this.language, this.note});

  final String language;

  /// "(young)", "(adult)".
  final String? note;
}

class AppearanceCard {
  const AppearanceCard({required this.key, required this.media, required this.role, required this.voices});

  final String key;
  final MediaCard media;
  final String role;

  /// Every language's voice actors; the page shows one language at a time.
  final List<VoiceActor> voices;
}

class PersonHeader {
  const PersonHeader({
    required this.name,
    required this.native,
    required this.altNames,
    required this.spoilerNames,
    required this.image,
    required this.facts,
    required this.bio,
    required this.favourites,
    required this.isFavourite,
    required this.anilist,
  });

  final String name;
  final String? native;
  final List<String> altNames;

  /// Names that give away the story: hidden until asked for.
  final List<String> spoilerNames;
  final String? image;
  final List<Fact> facts;
  final List<Paragraph> bio;

  /// "3.9k".
  final String favourites;
  final bool isFavourite;
  final Uri anilist;
}

class StaffContent {
  const StaffContent({
    required this.id,
    required this.header,
    required this.voiceRoles,
    required this.voiceHasMore,
    required this.credits,
    required this.creditsHasMore,
    required this.voiceFirst,
  });

  final int id;
  final PersonHeader header;
  final List<VoiceRoleCard> voiceRoles;
  final bool voiceHasMore;
  final List<CreditCard> credits;
  final bool creditsHasMore;

  /// Voice actors lead with their roles; authors and directors with their credits.
  final bool voiceFirst;
}

class CharacterContent {
  const CharacterContent({
    required this.id,
    required this.header,
    required this.appearances,
    required this.hasMore,
    required this.languages,
  });

  final int id;
  final PersonHeader header;
  final List<AppearanceCard> appearances;
  final bool hasMore;

  /// The languages voicing them, Japanese first, then English, then by how many.
  final List<String> languages;
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Sep 27, 1990", "Sep 27" (no year) or "1990" (no day).
String formatDate(AniListDate date) {
  final month = date.month != null ? _months[date.month! - 1] : '';
  final day = month.isNotEmpty && date.day != null ? '$month ${date.day}' : month;
  if (day.isNotEmpty && date.year != null) return '$day, ${date.year}';
  return day.isNotEmpty ? day : (date.year != null ? '${date.year}' : '');
}

List<Fact> _fact(String label, Object? value) =>
    value == null || value == '' ? const [] : [(label: label, value: '$value')];

String? _name(Json? name) => name?['userPreferred'] as String? ?? name?['full'] as String?;

List<Json> _list(Object? raw) => (raw as List? ?? const []).whereType<Json>().toList();

/// A title as a role card shows it (also a studio's titles).
MediaCard mediaCardOf(Json m, TitlePreference titles) {
  final year = (m['startDate'] as Json?)?['year'] ?? m['seasonYear'];
  final format = humanizeFormat(m['format'] as String?);
  final cover = m['coverImage'] as Json?;
  return MediaCard(
    id: (m['id'] as num).toInt(),
    title: pickTitle(AniListMediaTitle.fromJson(m['title'] as Json?), titles),
    meta: [if (year != null) '$year', if (format.isNotEmpty && format != 'Unknown') format].join(' · '),
    cover: cover?['large'] as String?,
    colors: CoverColors.fromHex(cover?['color'] as String?),
    isAnime: m['type'] == 'ANIME',
  );
}

PersonHeader _header(Json person, String kind, List<Fact> facts) {
  final names = person['name'] as Json? ?? const {};
  final name = _name(names) ?? '';
  final nativeName = names['native'] as String?;
  final native = nativeName != null && nativeName.isNotEmpty && nativeName != name ? nativeName : null;
  final seen = {name.toLowerCase(), ?native?.toLowerCase()};
  List<String> unique(Iterable<Object?> list) => [
    for (final n in list.whereType<String>())
      if (n.trim().toLowerCase() case final key when key.isNotEmpty && seen.add(key)) n,
  ];
  final altNames = unique([names['full'], ...?(names['alternative'] as List?)]);
  final description = parseDescription(person['description'] as String?);
  final id = (person['id'] as num).toInt();
  return PersonHeader(
    name: name,
    native: native,
    altNames: altNames,
    spoilerNames: unique([...?(names['alternativeSpoiler'] as List?)]),
    image: (person['image'] as Json?)?['large'] as String?,
    facts: [...facts, ...description.facts],
    bio: description.paragraphs,
    favourites: formatCompact((person['favourites'] as num?)?.toInt()),
    isFavourite: person['isFavourite'] == true,
    anilist: anilistLink(person['siteUrl'] as String?, 'https://anilist.co/$kind/$id')!,
  );
}

/// Voice roles from a page of characterMedia: a card per character voiced,
/// 18+ titles left out unless [adult]. [seen] carries across pages.
List<VoiceRoleCard> voiceRolesOf(Json page, {required TitlePreference titles, required bool adult, Set<String>? seen}) {
  final keys = seen ?? <String>{};
  return [
    for (final edge in _list(page['edges']))
      if (edge['node'] case final Json node when adult || node['isAdult'] != true)
        for (final c in _list(edge['characters']))
          if (keys.add('${node['id']}-${c['id']}'))
            VoiceRoleCard(
              key: '${node['id']}-${c['id']}',
              media: mediaCardOf(node, titles),
              character: PersonLink(
                id: (c['id'] as num).toInt(),
                name: _name(c['name'] as Json?) ?? '',
                image: (c['image'] as Json?)?['medium'] as String?,
              ),
              role: humanizeEnum(edge['characterRole'] as String?),
            ),
  ];
}

/// Credits from a page of staffMedia. AniList sends one edge per role; a
/// title they had several roles on is one card.
List<CreditCard> creditsOf(Json page, {required TitlePreference titles, required bool adult}) {
  final credits = <int, ({MediaCard media, List<String> roles})>{};
  for (final edge in _list(page['edges'])) {
    final node = edge['node'] as Json?;
    if (node == null || (node['isAdult'] == true && !adult)) continue;
    final id = (node['id'] as num).toInt();
    final card = credits[id] ??= (media: mediaCardOf(node, titles), roles: <String>[]);
    final role = edge['staffRole'] as String?;
    if (role != null && role.isNotEmpty && !card.roles.contains(role)) card.roles.add(role);
  }
  return [for (final c in credits.values) CreditCard(key: '${c.media.id}', media: c.media, roles: c.roles.join(' · '))];
}

bool _hasNext(Json? page) => (page?['pageInfo'] as Json?)?['hasNextPage'] == true;

StaffContent createStaffContent(
  Json staff, {
  TitlePreference titles = TitlePreference.userPreferred,
  bool adult = false,
}) {
  final death = AniListDate.fromJson(staff['dateOfDeath'] as Json?);
  final alive = death.year == null;
  final years = (staff['yearsActive'] as List? ?? const []).whereType<num>().toList();
  final occupations = (staff['primaryOccupations'] as List? ?? const []).whereType<String>().toList();
  final facts = [
    ..._fact('Occupation', occupations.join(', ')),
    ..._fact('Birthday', formatDate(AniListDate.fromJson(staff['dateOfBirth'] as Json?))),
    ...(alive ? _fact('Age', staff['age']) : _fact('Died', formatDate(death))),
    ..._fact('Gender', staff['gender']),
    ..._fact(
      'Years active',
      years.isEmpty ? null : '${years[0]} – ${years.length > 1 ? years[1] : (alive ? 'present' : '?')}',
    ),
    ..._fact('Hometown', staff['homeTown']),
    ..._fact('Blood type', staff['bloodType']),
    ..._fact('Language', staff['languageV2']),
  ];
  final voice = staff['characterMedia'] as Json?;
  final staffMedia = staff['staffMedia'] as Json?;
  final voiceEdges = _list(voice?['edges']).length;
  return StaffContent(
    id: (staff['id'] as num).toInt(),
    header: _header(staff, 'staff', facts),
    voiceRoles: voice == null ? const [] : voiceRolesOf(voice, titles: titles, adult: adult),
    voiceHasMore: _hasNext(voice),
    credits: staffMedia == null ? const [] : creditsOf(staffMedia, titles: titles, adult: adult),
    creditsHasMore: _hasNext(staffMedia),
    voiceFirst:
        voiceEdges > 0 && (occupations.contains('Voice Actor') || voiceEdges >= _list(staffMedia?['edges']).length),
  );
}

/// Appearances from a page of a character's media. [seen] carries across pages.
List<AppearanceCard> appearancesOf(Json page, {required TitlePreference titles, required bool adult, Set<int>? seen}) {
  final ids = seen ?? <int>{};
  final out = <AppearanceCard>[];
  for (final edge in _list(page['edges'])) {
    final node = edge['node'] as Json?;
    if (node == null || (node['isAdult'] == true && !adult) || !ids.add((node['id'] as num).toInt())) continue;
    final voices = <VoiceActor>[];
    for (final r in _list(edge['voiceActorRoles'])) {
      final va = r['voiceActor'] as Json?;
      if (va == null || voices.any((v) => v.id == va['id'])) continue;
      voices.add(
        VoiceActor(
          id: (va['id'] as num).toInt(),
          name: _name(va['name'] as Json?) ?? '',
          image: (va['image'] as Json?)?['medium'] as String?,
          language: va['languageV2'] as String? ?? 'Unknown',
          note: r['roleNotes'] as String?,
        ),
      );
    }
    out.add(
      AppearanceCard(
        key: '${node['id']}',
        media: mediaCardOf(node, titles),
        role: humanizeEnum(edge['characterRole'] as String?),
        voices: voices,
      ),
    );
  }
  return out;
}

/// Japanese first (the original), then English, then by how many titles.
List<String> languageOrder(Iterable<AppearanceCard> appearances) {
  final counts = <String, int>{};
  for (final a in appearances) {
    for (final language in {for (final v in a.voices) v.language}) {
      counts[language] = (counts[language] ?? 0) + 1;
    }
  }
  int rank(String l) => l == 'Japanese' ? 0 : (l == 'English' ? 1 : 2);
  return counts.keys.toList()..sort(
    (a, b) => rank(a) != rank(b)
        ? rank(a).compareTo(rank(b))
        : counts[b] != counts[a]
        ? counts[b]!.compareTo(counts[a]!)
        : a.compareTo(b),
  );
}

CharacterContent createCharacterContent(
  Json character, {
  TitlePreference titles = TitlePreference.userPreferred,
  bool adult = false,
}) {
  final facts = [
    ..._fact('Gender', character['gender']),
    ..._fact('Age', character['age']),
    ..._fact('Birthday', formatDate(AniListDate.fromJson(character['dateOfBirth'] as Json?))),
    ..._fact('Blood type', character['bloodType']),
  ];
  final media = character['media'] as Json?;
  final appearances = media == null ? <AppearanceCard>[] : appearancesOf(media, titles: titles, adult: adult);
  return CharacterContent(
    id: (character['id'] as num).toInt(),
    header: _header(character, 'character', facts),
    appearances: appearances,
    hasMore: _hasNext(media),
    languages: languageOrder(appearances),
  );
}

/// Thrown when AniList has no one with that id.
class PersonNotFound implements Exception {
  const PersonNotFound();
}

/// [load], with AniList's 404 as [PersonNotFound] (also a studio's).
Future<T> orNotFound<T>(Future<T> Function() load) async {
  try {
    return await load();
  } on AniListError catch (e) {
    if (e.kind == AniListErrorKind.api && e.status == 404) throw const PersonNotFound();
    rethrow;
  }
}

/// The viewer's entries for these titles, put in the list store so role
/// cards can say "Watching" (people's roles carry no list state). Best
/// effort: without them the cards just don't say.
/// [read] is a Ref's or a WidgetRef's.
Future<void> loadListState(T Function<T>(ProviderListenable<T>) read, Iterable<int> mediaIds) async {
  final userId = read(sessionProvider).user?.id;
  final ids = mediaIds.toSet().toList();
  if (userId == null || ids.isEmpty) return;
  final store = read(listStoreProvider.notifier);
  final since = store.stamp();
  final client = read(anilistClientProvider);
  try {
    for (var i = 0; i < ids.length; i += 50) {
      final found = await client.fetchListEntries(userId, ids.sublist(i, (i + 50).clamp(0, ids.length)));
      store.seed([
        for (final e in found)
          if (e.mediaId != null) ListEntry(id: e.id, mediaId: e.mediaId!, status: e.status, progress: e.progress),
      ], since: since);
    }
  } on Exception {
    // the cards show without a status
  }
}

/// The media ids in a page of roles.
Iterable<int> mediaIdsOf(Json? page) sync* {
  for (final e in _list(page?['edges'])) {
    if ((e['node'] as Json?)?['id'] case final num id) yield id.toInt();
  }
}

/// A staff member as AniList sends them, with the first page of roles in
/// [sort]. Pages are built with [createStaffContent], once more roles load.
final staffProvider = FutureProvider.autoDispose.family<Json, ({int id, PersonSort sort})>((ref, key) {
  ref.cacheFor(screenCache);
  final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
  return orNotFound(() async {
    final raw = await ref.watch(anilistClientProvider).fetchStaff(key.id, signedIn: signedIn, sort: key.sort);
    unawaited(
      loadListState(ref.read, [
        ...mediaIdsOf(raw['characterMedia'] as Json?),
        ...mediaIdsOf(raw['staffMedia'] as Json?),
      ]),
    );
    return raw;
  });
});

/// A character as AniList sends them, with the first page of titles.
final characterProvider = FutureProvider.autoDispose.family<Json, int>((ref, id) {
  ref.cacheFor(screenCache);
  final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
  return orNotFound(() async {
    final raw = await ref.watch(anilistClientProvider).fetchCharacter(id, signedIn: signedIn);
    unawaited(loadListState(ref.read, mediaIdsOf(raw['media'] as Json?)));
    return raw;
  });
});

/// [page]'s roles with [more] pages' edges added, hasNextPage from the last.
Json withPages(Json? page, List<Json> more) => {
  'pageInfo': {'hasNextPage': more.isEmpty ? _hasNext(page) : _hasNext(more.last)},
  'edges': [..._list(page?['edges']), for (final m in more) ..._list(m['edges'])],
};
