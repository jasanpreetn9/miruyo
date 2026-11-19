// A staff member (/staff/:id), ported from apps/web/src/routes/staff/[id]:
// who they are, then their voice roles and credits, most popular or newest
// first. "What else has this voice actor done" is the point of the page.

import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/section_error.dart';
import '../../widgets/skeleton.dart';
import 'person_data.dart';
import 'person_layout.dart';

class StaffScreen extends ConsumerStatefulWidget {
  const StaffScreen({super.key, required this.id, this.sort = PersonSort.popularity});

  final int id;

  /// From a link (/staff/1?sort=newest).
  final PersonSort sort;

  @override
  ConsumerState<StaffScreen> createState() => _StaffScreenState();
}

class _StaffScreenState extends ConsumerState<StaffScreen> {
  late var _sort = widget.sort;

  /// The person as last shown: a new sort keeps the page up while its roles load.
  Json? _shown;

  /// Pages after the first, per section, for the current sort.
  final _voice = <Json>[];
  final _credits = <Json>[];
  bool _loadingVoice = false;
  bool _loadingCredits = false;
  bool _voiceFailed = false;
  bool _creditsFailed = false;

  void _setSort(PersonSort sort) {
    if (sort == _sort) return;
    setState(() {
      _sort = sort;
      _voice.clear();
      _credits.clear();
      _voiceFailed = _creditsFailed = false;
    });
  }

  Future<void> _more({required bool voice}) async {
    final pages = voice ? _voice : _credits;
    final sort = _sort;
    setState(() => voice ? _loadingVoice = true : _loadingCredits = true);
    try {
      final client = ref.read(anilistClientProvider);
      final page = pages.length + 2;
      final next = voice
          ? await client.fetchStaffVoiceRoles(widget.id, page, sort)
          : await client.fetchStaffCredits(widget.id, page, sort);
      if (!mounted || sort != _sort) return;
      unawaited(loadListState(ref.read, mediaIdsOf(next)));
      setState(() {
        pages.add(next);
        voice ? _voiceFailed = false : _creditsFailed = false;
      });
    } on Exception {
      if (mounted) setState(() => voice ? _voiceFailed = true : _creditsFailed = true);
    } finally {
      if (mounted) setState(() => voice ? _loadingVoice = false : _loadingCredits = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(staffProvider((id: widget.id, sort: _sort)));
    final session = ref.watch(sessionProvider);
    if (loaded.value case final raw?) _shown = raw;
    final raw = _shown;

    if (raw == null) {
      return Scaffold(
        body: switch (loaded) {
          AsyncError(error: PersonNotFound()) => const _NotFound(),
          AsyncError(:final error) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Space.gutter),
              child: SectionError(
                title: "Couldn't load this person",
                error: error,
                onRetry: () => ref.invalidate(staffProvider((id: widget.id, sort: _sort))),
              ),
            ),
          ),
          _ => const _PersonSkeleton(),
        },
      );
    }

    // a new sort: the page stays, its roles fade until theirs arrive
    final stale = loaded.isLoading && loaded.value == null;
    final content = createStaffContent(
      {
        ...raw,
        'characterMedia': withPages(raw['characterMedia'] as Json?, _voice),
        'staffMedia': withPages(raw['staffMedia'] as Json?, _credits),
      },
      titles: session.titles,
      adult: session.signedIn && session.showAdultContent,
    );

    final sortControl = PersonSortControl(sort: _sort, onSort: _setSort);
    final voice = [
      if (content.voiceRoles.isNotEmpty) ...[
        PersonSectionHeading(text: 'Voice roles', trailing: sortControl),
        RoleGrid(
          faded: stale,
          cards: [
            for (final r in content.voiceRoles)
              RoleCard(
                key: ValueKey(r.key),
                media: r.media,
                people: [
                  (
                    href: '/character/${r.character.id}',
                    name: r.character.name,
                    image: r.character.image,
                    caption: r.role,
                  ),
                ],
              ),
          ],
        ),
        if (content.voiceHasMore || _voiceFailed)
          LoadMore(loading: _loadingVoice, failed: _voiceFailed, onTap: () => _more(voice: true), what: 'roles'),
      ],
    ];
    final credits = [
      if (content.credits.isNotEmpty) ...[
        PersonSectionHeading(
          text: content.voiceRoles.isNotEmpty ? 'Staff credits' : 'Works',
          trailing: content.voiceFirst ? null : sortControl,
        ),
        RoleGrid(
          faded: stale,
          cards: [for (final c in content.credits) RoleCard(key: ValueKey(c.key), media: c.media, caption: c.roles)],
        ),
        if (content.creditsHasMore || _creditsFailed)
          LoadMore(loading: _loadingCredits, failed: _creditsFailed, onTap: () => _more(voice: false), what: 'credits'),
      ],
    ];

    return Scaffold(
      body: PersonPage(
        header: content.header,
        kind: FavouriteKind.staff,
        id: content.id,
        sections: [
          // voice actors lead with their roles; authors and directors with their credits
          ...content.voiceFirst ? [...voice, ...credits] : [...credits, ...voice],
          if (content.voiceRoles.isEmpty && content.credits.isEmpty && !stale)
            Padding(
              padding: const EdgeInsets.only(top: Space.x8),
              child: Text('No roles listed on AniList yet.', style: AppType.body.copyWith(color: TextTone.mid)),
            ),
        ],
      ),
    );
  }
}

/// Popular / Newest (also a studio's titles).
class PersonSortControl extends StatelessWidget {
  const PersonSortControl({super.key, required this.sort, required this.onSort});

  final PersonSort sort;
  final ValueChanged<PersonSort> onSort;

  @override
  Widget build(BuildContext context) {
    // chips, as the user page's tabs: 13px dark text on the light fill reads
    // (and measures) better than a segmented button's 12px
    Widget chip(PersonSort value, String label) => ChoiceChip(
      label: Text(label),
      selected: sort == value,
      onSelected: (_) => onSort(value),
      showCheckmark: false,
      labelStyle: AppType.body.copyWith(
        fontSize: 13,
        color: sort == value ? Surface.base : TextTone.high,
        fontWeight: sort == value ? FontWeight.w600 : FontWeight.w400,
      ),
      selectedColor: TextTone.high,
      backgroundColor: Colors.transparent,
      side: BorderSide(color: sort == value ? TextTone.high : Surface.line),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [chip(PersonSort.popularity, 'Popular'), const SizedBox(width: 6), chip(PersonSort.newest, 'Newest')],
    );
  }
}

class _NotFound extends StatelessWidget {
  const _NotFound();

  @override
  Widget build(BuildContext context) => const PersonNotFoundView();
}

class _PersonSkeleton extends StatelessWidget {
  const _PersonSkeleton();

  @override
  Widget build(BuildContext context) => const PersonSkeleton();
}

/// Someone AniList doesn't have (removed, or merged into someone else).
class PersonNotFoundView extends StatelessWidget {
  const PersonNotFoundView({
    super.key,
    this.title = "This person isn't on AniList",
    this.detail = 'They may have been removed or merged.',
  });

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(Space.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RoundIconButton(
              icon: Icons.arrow_back_rounded,
              label: 'Back',
              onTap: () => context.canPop() ? context.pop() : context.go('/'),
            ),
            const SizedBox(height: Space.x8),
            Text(title, style: AppType.heading.copyWith(fontSize: 24)),
            const SizedBox(height: Space.x2),
            Text(detail, style: AppType.body.copyWith(color: TextTone.mid)),
            TextButton(
              onPressed: () => context.go('/browse'),
              style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, Space.minTarget)),
              child: const Text('Browse titles →'),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page's shape while it loads.
class PersonSkeleton extends StatelessWidget {
  const PersonSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Semantics(
      label: 'Loading',
      child: Padding(
        padding: EdgeInsets.fromLTRB(Space.gutter, top + 80, Space.gutter, 0),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Skeleton(width: 112, height: 150, radius: 10),
                SizedBox(width: 14),
                Expanded(child: Skeleton(height: 28)),
              ],
            ),
            SizedBox(height: Space.x6),
            Skeleton(height: Space.minTarget),
            SizedBox(height: Space.x6),
            Skeleton(height: 120),
          ],
        ),
      ),
    );
  }
}
