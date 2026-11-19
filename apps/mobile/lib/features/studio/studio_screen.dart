// A studio (/studio/:id), ported from apps/web/src/routes/studio/[id]: what
// it is, then the titles it made, most popular or newest first, as the staff
// page lists someone's credits. It uses the person pages' layout; a studio
// has no picture or bio on AniList, so its portrait is an icon.

import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/section_error.dart';
import '../person/person_data.dart';
import '../person/person_layout.dart';
import '../person/staff_screen.dart' show PersonNotFoundView, PersonSkeleton, PersonSortControl;
import 'studio_data.dart';

class StudioScreen extends ConsumerStatefulWidget {
  const StudioScreen({super.key, required this.id, this.sort = PersonSort.popularity});

  final int id;

  /// From a link (/studio/11?sort=newest).
  final PersonSort sort;

  @override
  ConsumerState<StudioScreen> createState() => _StudioScreenState();
}

class _StudioScreenState extends ConsumerState<StudioScreen> {
  late var _sort = widget.sort;

  /// The studio as last shown: a new sort keeps the page up while its titles load.
  Json? _shown;

  /// Pages after the first, for the current sort.
  final _more = <Json>[];
  bool _loading = false;
  bool _failed = false;

  void _setSort(PersonSort sort) {
    if (sort == _sort) return;
    setState(() {
      _sort = sort;
      _more.clear();
      _failed = false;
    });
  }

  Future<void> _loadMore() async {
    final sort = _sort;
    setState(() => _loading = true);
    try {
      final next = await ref.read(anilistClientProvider).fetchStudioMedia(widget.id, _more.length + 2, sort);
      if (!mounted || sort != _sort) return;
      unawaited(loadListState(ref.read, mediaIdsOf(next)));
      setState(() {
        _more.add(next);
        _failed = false;
      });
    } on Exception {
      if (mounted) setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(studioProvider((id: widget.id, sort: _sort)));
    final session = ref.watch(sessionProvider);
    if (loaded.value case final raw?) _shown = raw;
    final raw = _shown;

    if (raw == null) {
      return Scaffold(
        body: switch (loaded) {
          AsyncError(error: PersonNotFound()) => const PersonNotFoundView(
            title: "This studio isn't on AniList",
            detail: 'It may have been removed or merged.',
          ),
          AsyncError(:final error) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Space.gutter),
              child: SectionError(
                title: "Couldn't load this studio",
                error: error,
                onRetry: () => ref.invalidate(studioProvider((id: widget.id, sort: _sort))),
              ),
            ),
          ),
          _ => const PersonSkeleton(),
        },
      );
    }

    // a new sort: the page stays, its titles fade until theirs arrive
    final stale = loaded.isLoading && loaded.value == null;
    final content = createStudioContent(
      {...raw, 'media': withPages(raw['media'] as Json?, _more)},
      titles: session.titles,
      adult: session.signedIn && session.showAdultContent,
    );
    final animation = content.kind == 'Animation studio';

    return Scaffold(
      body: PersonPage(
        header: content.header,
        kind: FavouriteKind.studio,
        id: content.id,
        portraitIcon: animation ? Symbols.movie_rounded : Symbols.domain_rounded,
        squarePortrait: true,
        sections: [
          PersonSectionHeading(
            text: 'Titles',
            trailing: PersonSortControl(sort: _sort, onSort: _setSort),
          ),
          if (content.titles.isNotEmpty)
            RoleGrid(
              faded: stale,
              cards: [
                for (final t in content.titles) RoleCard(key: ValueKey(t.key), media: t.media, caption: t.caption),
              ],
            )
          else if (!stale)
            Padding(
              padding: const EdgeInsets.only(top: Space.x4),
              child: Text('No titles listed on AniList yet.', style: AppType.body.copyWith(color: TextTone.mid)),
            ),
          if (content.hasMore || _failed)
            LoadMore(loading: _loading, failed: _failed, onTap: _loadMore, what: 'titles'),
        ],
      ),
    );
  }
}
