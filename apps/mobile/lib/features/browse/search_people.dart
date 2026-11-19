// What else a Browse search matches besides titles, ported from
// apps/web/src/lib/page-data/search-people.ts: characters (with the title
// they're best known from), staff (with what they do), AniList users and,
// for anime, studios. Each opens its miruyo page.

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/title.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../person/person_layout.dart' show Portrait;
import '../studio/studio_data.dart' show studioHref;

class PersonResult {
  const PersonResult({required this.id, required this.name, required this.href, this.image, this.sub});

  final int id;
  final String name;
  final String? image;

  /// "Frieren: Beyond Journey's End" / "Voice Actor".
  final String? sub;
  final String href;
}

typedef StudioResult = ({int id, String name, String href});

class PeopleResults {
  const PeopleResults({
    this.characters = const [],
    this.staff = const [],
    this.users = const [],
    this.studios = const [],
  });

  final List<PersonResult> characters;
  final List<PersonResult> staff;

  /// AniList users, whose pages are /user/:name.
  final List<PersonResult> users;
  final List<StudioResult> studios;

  /// Whether there's anything besides titles to show.
  bool get isNotEmpty => characters.isNotEmpty || staff.isNotEmpty || users.isNotEmpty || studios.isNotEmpty;
}

List<Json> _page(Json data, String page, String key) =>
    ((data[page] as Json?)?[key] as List? ?? const []).whereType<Json>().toList();

String? _image(Json p) => (p['image'] as Json?)?['large'] as String? ?? (p['image'] as Json?)?['medium'] as String?;

String? _first(List<Object?> names) => names.whereType<String>().where((n) => n.isNotEmpty).firstOrNull;

PeopleResults buildPeopleResults(Json data, {required bool isAnime, required TitlePreference titles}) {
  return PeopleResults(
    characters: [
      for (final c in _page(data, 'characters', 'characters'))
        () {
          final t = ((((c['media'] as Json?)?['nodes'] as List?)?.firstOrNull as Json?)?['title']) as Json?;
          return PersonResult(
            id: (c['id'] as num).toInt(),
            name: (c['name'] as Json?)?['userPreferred'] as String? ?? 'Unknown',
            image: _image(c),
            sub: t == null
                ? null
                : titles == TitlePreference.english
                ? _first([t['english'], t['romaji'], t['userPreferred']])
                : _first([t['userPreferred'], t['english'], t['romaji']]),
            href: '/character/${c['id']}',
          );
        }(),
    ],
    staff: [
      for (final s in _page(data, 'staff', 'staff'))
        PersonResult(
          id: (s['id'] as num).toInt(),
          name: (s['name'] as Json?)?['userPreferred'] as String? ?? 'Unknown',
          image: _image(s),
          sub: (s['primaryOccupations'] as List?)?.whereType<String>().firstOrNull,
          href: '/staff/${s['id']}',
        ),
    ],
    // anyone's list is anime and manga both, so users show in either mode
    users: [
      for (final u in _page(data, 'users', 'users'))
        if (u['name'] case final String name)
          PersonResult(
            id: (u['id'] as num).toInt(),
            name: name,
            image: (u['avatar'] as Json?)?['large'] as String? ?? (u['avatar'] as Json?)?['medium'] as String?,
            href: '/user/${Uri.encodeComponent(name)}',
          ),
    ],
    // studios make anime; in manga mode they'd only be noise
    studios: [
      if (isAnime)
        for (final s in _page(data, 'studios', 'studios'))
          if (s['isAnimationStudio'] == true)
            (
              id: (s['id'] as num).toInt(),
              name: s['name'] as String? ?? '',
              href: studioHref((s['id'] as num).toInt()),
            ),
    ],
  );
}

/// The people a search matches, by its text (lowercased, so "Frieren" and
/// "frieren" are one request). A failure just leaves the titles.
final searchPeopleProvider = FutureProvider.autoDispose.family<Json, String>((ref, search) async {
  ref.cacheFor(screenCache);
  return ref.watch(anilistClientProvider).fetchSearchPeople(search);
});

/// Among Browse's titles while searching, after the first rows: the
/// characters, staff, users and studios the search also matches, a row each. Nothing shows until there's a match,
/// and a failure just leaves the titles (it's extra, not the search).
class SearchPeopleRows extends ConsumerWidget {
  const SearchPeopleRows({super.key, required this.q, required this.isAnime});

  final String q;
  final bool isAnime;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(searchPeopleProvider(q.toLowerCase())).value;
    final titles = ref.watch(sessionProvider.select((s) => s.titles));
    if (data == null) return const SizedBox.shrink();
    final results = buildPeopleResults(data, isAnime: isAnime, titles: titles);
    if (!results.isNotEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: Space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (results.characters.isNotEmpty) _PeopleRow(heading: 'Characters', people: results.characters),
          if (results.staff.isNotEmpty) _PeopleRow(heading: 'Staff', people: results.staff),
          if (results.users.isNotEmpty) _PeopleRow(heading: 'Users', people: results.users),
          if (results.studios.isNotEmpty) ...[
            _heading('Studios'),
            SizedBox(
              height: 48,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                itemCount: results.studios.length,
                separatorBuilder: (_, _) => const SizedBox(width: Space.x2),
                itemBuilder: (_, i) {
                  final s = results.studios[i];
                  return ActionChip(
                    label: Text(s.name),
                    onPressed: () => context.push(s.href),
                    labelStyle: AppType.body.copyWith(fontSize: 13),
                    backgroundColor: Surface.s1,
                    side: const BorderSide(color: Surface.line),
                    shape: const StadiumBorder(),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Widget _heading(String text) => Padding(
  padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, Space.x2),
  child: Text(text.toUpperCase(), style: AppType.overline.copyWith(color: TextTone.mid)),
);

class _PeopleRow extends StatelessWidget {
  const _PeopleRow({required this.heading, required this.people});

  final String heading;
  final List<PersonResult> people;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heading(heading),
        SizedBox(
          height: 136,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.x3),
            itemBuilder: (context, i) {
              final p = people[i];
              return Semantics(
                container: true,
                button: true,
                label: [p.name, ?p.sub].join(', '),
                excludeSemantics: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => context.push(p.href),
                  child: SizedBox(
                    width: 72,
                    child: Column(
                      children: [
                        Portrait(image: p.image, width: 64, height: 64, radius: Corner.full),
                        const SizedBox(height: 6),
                        Text(
                          p.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(height: 1.15, fontWeight: FontWeight.w600),
                        ),
                        if (p.sub != null)
                          Text(
                            p.sub!,
                            maxLines: 1,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.caption.copyWith(fontSize: 11, color: TextTone.low),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
