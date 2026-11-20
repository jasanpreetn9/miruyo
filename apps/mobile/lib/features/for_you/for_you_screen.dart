import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/gestures/haptics.dart';
import '../../core/gestures/row_swipe.dart';
import '../../core/list/guard.dart';
import '../../core/list/list_actions.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/toast.dart';
import '../../widgets/cover_grid.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/section_error.dart';
import '../../widgets/skeleton.dart';
import 'for_you_data.dart';

/// For You: picks from AniList's
/// recommendations for the titles you rated highest, each with its reason.
/// Every pick is a yes or no: swipe right for Planning, left for Not this;
/// hold to see why it was picked. Tap a seed to filter the picks to it,
/// swipe it up to stop using it. Everything can be undone from the toast.
class ForYouScreen extends ConsumerStatefulWidget {
  const ForYouScreen({super.key});

  @override
  ConsumerState<ForYouScreen> createState() => _ForYouScreenState();
}

class _ForYouScreenState extends ConsumerState<ForYouScreen> {
  /// The seed the grid is filtered to, or null for every pick.
  int? _seed;

  void _haptic(Haptic h) => unawaited(ref.read(hapticsProvider).play(h));

  void _notThis(Pick pick) {
    _haptic(Haptic.light);
    ref.read(dismissedPicksProvider.notifier).add(pick.title.id);
    ref
        .read(toastProvider.notifier)
        .show(
          'Hid ${pick.title.title} from your picks',
          action: ToastAction('Undo', () {
            _haptic(Haptic.light);
            ref.read(dismissedPicksProvider.notifier).remove(pick.title.id);
          }),
        );
  }

  void _planning(Pick pick) {
    if (canEditList(context, ref)) {
      unawaited(ref.read(listActionsProvider).changeStatus(pick.title, MediaListStatus.planning));
    }
  }

  void _mute(Seed seed) {
    _haptic(Haptic.medium);
    ref.read(mutedSeedsProvider.notifier).add(seed.id);
    if (_seed == seed.id) setState(() => _seed = null);
    ref
        .read(toastProvider.notifier)
        .show(
          'Stopped using ${seed.title.title} for picks',
          action: ToastAction('Undo', () {
            _haptic(Haptic.light);
            ref.read(mutedSeedsProvider.notifier).remove(seed.id);
          }),
        );
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(modeProvider);
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final forYou = signedIn ? ref.watch(forYouProvider(mode)) : null;
    final dismissed = ref.watch(dismissedPicksProvider);
    final muted = ref.watch(mutedSeedsProvider);
    final tune = ref.watch(tuneProvider);
    // a new mode brings new seeds
    ref.listen(modeProvider, (_, _) => setState(() => _seed = null));

    final noun = mode.isAnime ? 'anime' : 'manga';
    return Scaffold(
      appBar: AppBar(
        title: Text('For You', style: AppType.title),
        backgroundColor: Surface.base,
        surfaceTintColor: Colors.transparent,
        actions: [
          if (forYou?.value case final data? when !data.coldStart)
            Padding(
              padding: const EdgeInsets.only(right: Space.x2),
              child: Badge(
                isLabelVisible: tune.changed,
                smallSize: 8,
                backgroundColor: TextTone.high,
                child: IconButton(
                  tooltip: tune.changed ? 'Tune picks (some left out)' : 'Tune picks',
                  icon: const Icon(Symbols.tune_rounded),
                  onPressed: () => unawaited(_showTune(context, data, isAnime: mode.isAnime)),
                ),
              ),
            ),
        ],
      ),
      body: RefreshIndicator.adaptive(
        onRefresh: () {
          ref.read(anilistClientProvider).clearViewerCache();
          return ref.refresh(forYouProvider(mode).future).then((_) {}, onError: (_) {});
        },
        child: CustomScrollView(
          slivers: [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, Space.x4),
              sliver: SliverToBoxAdapter(
                child: Text(
                  "Picks from AniList's recommendations for the $noun you rated highest. "
                  'Swipe right for Planning, left for Not this; hold one to see why.',
                  style: AppType.body.copyWith(color: TextTone.mid),
                ),
              ),
            ),
            ...switch (forYou) {
              null => [_ColdStart(signedIn: false, scored: 0, isAnime: mode.isAnime)],
              AsyncData(:final value) when value.coldStart => [
                _ColdStart(signedIn: true, scored: value.scored, isAnime: mode.isAnime),
              ],
              AsyncData(:final value) => _picks(value, dismissed, muted, tune, isAnime: mode.isAnime),
              AsyncError(:final error) => [
                SliverPadding(
                  padding: const EdgeInsets.all(Space.gutter),
                  sliver: SliverToBoxAdapter(
                    child: SectionError(
                      title: "Couldn't load your picks",
                      error: error,
                      onRetry: () => ref.invalidate(forYouProvider(mode)),
                    ),
                  ),
                ),
              ],
              _ => [
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  sliver: SliverGrid.count(
                    crossAxisCount: 3,
                    crossAxisSpacing: Space.x2,
                    mainAxisSpacing: Space.x5,
                    childAspectRatio: 0.62,
                    children: [for (var i = 0; i < 9; i++) const Skeleton(radius: Corner.sm)],
                  ),
                ),
              ],
            },
            const SliverToBoxAdapter(child: SizedBox(height: Space.x10)),
          ],
        ),
      ),
    );
  }

  List<Widget> _picks(ForYou data, Set<int> dismissed, Set<int> muted, Tune tune, {required bool isAnime}) {
    final own = {for (final s in data.seeds) s.id};
    final seeds = [
      for (final s in data.seeds)
        if (!muted.contains(s.id)) s,
      // the other list's seeds, while their picks can show
      if (tune.crossMode)
        for (final s in data.crossSeeds)
          if (!muted.contains(s.id) && !own.contains(s.id)) s,
    ];
    final tuned = visiblePicks(data, dismissed, muted, tune);
    final picks = [
      for (final p in tuned)
        if (_seed == null || p.seedIds.contains(_seed)) p,
    ];
    final filter = seeds.where((s) => s.id == _seed).firstOrNull;
    final noun = isAnime ? 'anime' : 'manga';

    return [
      if (data.seeds.isEmpty)
        // too few ratings on this list for picks of its own: these come from the other
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x4),
          sliver: SliverToBoxAdapter(
            child: Text(
              "You've rated ${data.scored} of $minRatings $noun, so for now these are the "
              '${isAnime ? 'anime of manga' : 'manga behind anime'} you loved. Rate a few $noun for picks of their own.',
              style: AppType.body.copyWith(color: TextTone.mid),
            ),
          ),
        ),
      SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x2),
          child: Text('BECAUSE YOU RATED', style: AppType.overline.copyWith(color: TextTone.low)),
        ),
      ),
      SliverToBoxAdapter(
        child: SizedBox(
          // room for a chip to lift as it's swiped up
          height: 76,
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            padding: const EdgeInsets.fromLTRB(Space.gutter, 14, Space.gutter, 6),
            children: [
              _AllChip(
                selected: _seed == null,
                onTap: () {
                  _haptic(Haptic.selection);
                  setState(() => _seed = null);
                },
              ),
              for (final seed in seeds)
                _SeedChip(
                  key: ValueKey(seed.id),
                  seed: seed,
                  // a seed from the other list says which
                  otherMode: seed.title.isAnime != isAnime ? (seed.title.isAnime ? 'anime' : 'manga') : null,
                  selected: _seed == seed.id,
                  onTap: () {
                    _haptic(Haptic.selection);
                    setState(() => _seed = _seed == seed.id ? null : seed.id);
                  },
                  onArm: () => _haptic(Haptic.light),
                  onMute: () => _mute(seed),
                ),
            ],
          ),
        ),
      ),
      if (filter != null)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, 0),
          sliver: SliverToBoxAdapter(
            child: Text(
              'Picks because you rated ${filter.title.title} ${scoreLabel(filter.score)}',
              style: AppType.body.copyWith(color: TextTone.mid),
            ),
          ),
        ),
      if (picks.isEmpty && tune.changed && tuned.isEmpty && data.picks.isNotEmpty)
        SliverPadding(
          padding: const EdgeInsets.all(Space.x8),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Text('Tune leaves out every pick', style: AppType.section, textAlign: TextAlign.center),
                const SizedBox(height: Space.x2),
                TextButton(
                  onPressed: () => ref.read(tuneProvider.notifier).reset(),
                  style: TextButton.styleFrom(minimumSize: const Size(0, Space.minTarget)),
                  child: const Text('Reset Tune'),
                ),
              ],
            ),
          ),
        )
      else if (picks.isEmpty)
        SliverPadding(
          padding: const EdgeInsets.all(Space.x8),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                Text("That's every pick for now", style: AppType.section, textAlign: TextAlign.center),
                const SizedBox(height: Space.x2),
                Text(
                  data.picks.isEmpty
                      ? 'AniList has no recommendations for your top-rated titles yet.'
                      : 'Rate a few more titles and new picks will show up here.',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: TextTone.mid),
                ),
              ],
            ),
          ),
        )
      else
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, 0),
          sliver: SliverGrid(
            // cover, status bar, two title lines and a reason of up to three
            gridDelegate: CoverGridDelegate.of(context, below: 118),
            delegate: SliverChildBuilderDelegate((context, i) {
              final pick = picks[i];
              return RowSwipe(
                key: ValueKey(pick.title.id),
                // the only grid where posters swipe: right Planning, left Not this
                onPositive: () => _planning(pick),
                positiveLabel: 'Planning',
                positiveIcon: Symbols.bookmark_add_rounded,
                onNegative: () => _notThis(pick),
                negativeLabel: 'Not this',
                negativeIcon: Symbols.block_rounded,
                borderRadius: Corner.sm,
                child: PosterCard(
                  title: pick.title,
                  reason: reasonFor(pick),
                  onHold: () => unawaited(
                    _showWhy(context, pick, onNotThis: () => _notThis(pick), onPlanning: () => _planning(pick)),
                  ),
                ),
              );
            }, childCount: picks.length),
          ),
        ),
    ];
  }
}

class _ColdStart extends StatelessWidget {
  const _ColdStart({required this.signedIn, required this.scored, required this.isAnime});

  final bool signedIn;
  final int scored;
  final bool isAnime;

  @override
  Widget build(BuildContext context) {
    final mode = context.mode;
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      sliver: SliverToBoxAdapter(
        child: Container(
          padding: const EdgeInsets.all(Space.x6),
          decoration: BoxDecoration(
            border: Border.symmetric(horizontal: BorderSide(color: Surface.line)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Symbols.auto_awesome_rounded, size: 32, color: mode.accentText),
              const SizedBox(height: Space.x3),
              Text('Picks get good after $minRatings ratings', style: AppType.heading.copyWith(fontSize: 22)),
              const SizedBox(height: Space.x2),
              Text(
                signedIn
                    ? "You've rated $scored of $minRatings. Score a few titles you've finished and your picks show up here."
                    : 'Log in with AniList and miruyo picks what to ${isAnime ? 'watch' : 'read'} next from what '
                          "you've rated, with the reason for each.",
                style: AppType.body.copyWith(color: TextTone.mid),
              ),
              const SizedBox(height: Space.x4),
              Wrap(
                spacing: Space.x2,
                runSpacing: Space.x2,
                children: [
                  FilledButton(
                    onPressed: () => signedIn ? context.go('/list') : context.push('/login'),
                    style: FilledButton.styleFrom(
                      backgroundColor: TextTone.high,
                      foregroundColor: Surface.base,
                      minimumSize: const Size(0, Space.minTarget),
                    ),
                    child: Text(signedIn ? 'Rate a few titles' : 'Log in with AniList'),
                  ),
                  OutlinedButton(
                    onPressed: () => context.go('/browse?sort=trending'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: TextTone.high,
                      side: const BorderSide(color: Surface.line),
                      minimumSize: const Size(0, Space.minTarget),
                    ),
                    child: const Text("See what's trending"),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AllChip extends StatelessWidget {
  const _AllChip({required this.selected, required this.onTap});

  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: Space.x2),
      child: Semantics(
        button: true,
        selected: selected,
        child: GestureDetector(
          onTap: onTap,
          child: _chipBox(
            selected: selected,
            child: Text(
              'All picks',
              style: AppType.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? TextTone.high : TextTone.mid,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Widget _chipBox({required bool selected, required Widget child}) => Container(
  height: 56,
  padding: const EdgeInsets.symmetric(horizontal: 14),
  alignment: Alignment.center,
  decoration: BoxDecoration(
    color: selected ? Surface.s3 : Surface.s1,
    borderRadius: BorderRadius.circular(2),
    border: Border.all(color: selected ? const Color(0x4DFFFFFF) : Surface.line),
  ),
  child: child,
);

/// A seed: tap to filter the picks to it; swipe it up (48px, or a flick) to
/// stop using it. Dragging down only stretches.
class _SeedChip extends StatefulWidget {
  const _SeedChip({
    super.key,
    required this.seed,
    required this.selected,
    required this.onTap,
    required this.onArm,
    required this.onMute,
    this.otherMode,
  });

  final Seed seed;

  /// "anime" or "manga" for a seed from the other list.
  final String? otherMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onArm;
  final VoidCallback onMute;

  static const muteAt = 48.0;

  @override
  State<_SeedChip> createState() => _SeedChipState();
}

class _SeedChipState extends State<_SeedChip> {
  double _dy = 0;
  bool _armed = false;

  @override
  Widget build(BuildContext context) {
    final seed = widget.seed;
    final lift = (-_dy).clamp(0.0, 80.0);
    return Padding(
      padding: const EdgeInsets.only(right: Space.x2),
      child: Semantics(
        button: true,
        selected: widget.selected,
        label: [seed.title.title, scoreLabel(seed.score), ?widget.otherMode].join(', '),
        customSemanticsActions: {CustomSemanticsAction(label: 'Stop using for picks'): widget.onMute},
        excludeSemantics: true,
        child: GestureDetector(
          onTap: widget.onTap,
          onVerticalDragUpdate: (d) {
            // up follows the finger; down only stretches
            final next = _dy + (d.delta.dy < 0 || _dy < 0 ? d.delta.dy : d.delta.dy * 0.2);
            final armed = -next >= _SeedChip.muteAt;
            if (armed && !_armed) widget.onArm();
            setState(() {
              _dy = next.clamp(-120.0, 12.0);
              _armed = armed;
            });
          },
          onVerticalDragEnd: (d) {
            final flick = (d.primaryVelocity ?? 0) < -500;
            final mute = _armed || flick && _dy < -GestureSpec.rowFlickMin / 2;
            setState(() {
              _dy = 0;
              _armed = false;
            });
            if (mute) widget.onMute();
          },
          child: AnimatedContainer(
            duration: _dy == 0 ? Motion.lift : Duration.zero,
            curve: Motion.enter,
            transform: Matrix4.translationValues(0, _dy, 0),
            child: Opacity(
              opacity: (1 - lift / 120).clamp(0.3, 1.0),
              child: _chipBox(
                selected: widget.selected,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 30,
                      height: 44,
                      child: CoverImage(title: seed.title, thumb: true, radius: 5, showMissing: false),
                    ),
                    const SizedBox(width: Space.x2),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            seed.title.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppType.body.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: widget.selected ? TextTone.high : const Color(0xFFDDD3C3),
                            ),
                          ),
                          Text(
                            _armed ? 'Let go to stop using' : [scoreLabel(seed.score), ?widget.otherMode].join(' · '),
                            style: AppType.numeric.copyWith(fontSize: 11, color: _armed ? Accent.danger : TextTone.low),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Why this pick (the hold): the title you rated and your score, the genres
/// they share, and how many AniList users recommend it. Not this, Planning,
/// Details.
Future<void> _showWhy(
  BuildContext context,
  Pick pick, {
  required VoidCallback onNotThis,
  required VoidCallback onPlanning,
}) async {
  final title = pick.title;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    // sized to its content, not capped at 9/16 of the screen
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Surface.s2,
    builder: (sheet) {
      void then(VoidCallback run) {
        Navigator.of(sheet).pop();
        run();
      }

      Widget fact(IconData icon, String text) => Padding(
        padding: const EdgeInsets.only(bottom: Space.x2),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: TextTone.mid),
            const SizedBox(width: Space.x2),
            Expanded(child: Text(text, style: AppType.body)),
          ],
        ),
      );

      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  SizedBox(width: 48, height: 72, child: CoverImage(title: title, thumb: true, radius: 6)),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.title),
                        Text(
                          [
                            if (title.score > 0) '★ ${title.score.toStringAsFixed(1)}',
                            ?title.knownFormat,
                            ?title.knownCount,
                          ].join(' · '),
                          style: AppType.caption.copyWith(color: TextTone.mid),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: Space.x4),
              Text('WHY THIS PICK', style: AppType.overline.copyWith(color: TextTone.low)),
              const SizedBox(height: Space.x2),
              if (pick.kind == PickKind.adaptation)
                fact(Symbols.swap_horiz_rounded, reasonFor(pick))
              else
                fact(Symbols.star_rounded, 'You rated ${pick.because.title.title} ${scoreLabel(pick.because.score)}'),
              if (pick.studio case final studio?)
                InkWell(
                  onTap: () => then(() => context.push('/studio/${studio.id}')),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Space.minTarget),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: fact(Symbols.movie_rounded, 'From ${studio.name}, a studio you rate highly ›'),
                    ),
                  ),
                ),
              if (pick.sharedGenres.isNotEmpty)
                fact(Symbols.sell_rounded, 'Shares ${pick.sharedGenres.join(', ')}, which you rate highly'),
              if (pick.kind == PickKind.recommended && pick.votes > 0)
                fact(
                  Symbols.group_rounded,
                  '${pick.votes} AniList ${pick.votes == 1 ? 'user recommends' : 'users recommend'} it to fans of '
                  '${pick.because.title.short}',
                ),
              if (pick.seedIds.length > 1)
                fact(Symbols.hub_rounded, 'Also recommended for ${pick.seedIds.length - 1} more of your top titles'),
              const SizedBox(height: Space.x3),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => then(onNotThis),
                      icon: const Icon(Symbols.block_rounded, size: 18),
                      label: const Text('Not this'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: TextTone.high,
                        side: const BorderSide(color: Surface.line),
                        minimumSize: const Size(0, Space.minTarget),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.x2),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => then(onPlanning),
                      icon: const Icon(Symbols.bookmark_add_rounded, size: 18),
                      label: const Text('Planning'),
                      style: FilledButton.styleFrom(
                        backgroundColor: TextTone.high,
                        foregroundColor: Surface.base,
                        minimumSize: const Size(0, Space.minTarget),
                      ),
                    ),
                  ),
                  const SizedBox(width: Space.x2),
                  IconButton.outlined(
                    tooltip: 'Details',
                    onPressed: () => then(() => context.push('/title/${title.id}')),
                    icon: const Icon(Symbols.info_rounded),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// "Tune picks": what to leave out, kept on this device. It filters the picks
/// already loaded, so nothing new is fetched.
Future<void> _showTune(BuildContext context, ForYou data, {required bool isAnime}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    showDragHandle: true,
    backgroundColor: Surface.s2,
    builder: (sheet) => Consumer(
      builder: (context, ref, _) {
        final tune = ref.watch(tuneProvider);
        final notifier = ref.read(tuneProvider.notifier);
        final genres = {...pickGenres(data.picks), ...tune.hiddenGenres}.toList();
        Widget toggle(String title, String detail, bool value, ValueChanged<bool> onChanged) => SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: Text(title, style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text(detail, style: AppType.caption.copyWith(color: TextTone.mid)),
          value: value,
          activeTrackColor: context.mode.accent,
          onChanged: onChanged,
        );
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(Space.gutter, 0, Space.gutter, Space.x4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(child: Text('Tune picks', style: AppType.title)),
                    if (tune.changed)
                      TextButton(
                        onPressed: notifier.reset,
                        style: TextButton.styleFrom(minimumSize: const Size(0, Space.minTarget)),
                        child: const Text('Reset'),
                      ),
                  ],
                ),
                const SizedBox(height: Space.x2),
                toggle(
                  'Only titles that are out',
                  "Leave out what hasn't started yet.",
                  tune.outOnly,
                  (v) => notifier.set(tune.copyWith(outOnly: v)),
                ),
                toggle(
                  isAnime ? 'Anime of manga you loved' : 'Manga of anime you loved',
                  isAnime
                      ? 'From your manga list: the anime of a manga you rated highly.'
                      : 'From your anime list: the manga or novel behind an anime you rated highly.',
                  tune.crossMode,
                  (v) => notifier.set(tune.copyWith(crossMode: v)),
                ),
                if (genres.isNotEmpty) ...[
                  const SizedBox(height: Space.x3),
                  Text('Leave out genres', style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: Space.x2),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final g in genres)
                        FilterChip(
                          label: Text(g),
                          selected: tune.hiddenGenres.contains(g),
                          onSelected: (_) => notifier.toggleGenre(g),
                          showCheckmark: false,
                          avatar: tune.hiddenGenres.contains(g)
                              ? const Icon(Symbols.block_rounded, size: 16, color: Accent.danger)
                              : null,
                          labelStyle: AppType.body.copyWith(
                            fontSize: 13,
                            color: tune.hiddenGenres.contains(g) ? Accent.danger : TextTone.high,
                            decoration: tune.hiddenGenres.contains(g) ? TextDecoration.lineThrough : null,
                            decorationColor: Accent.danger,
                          ),
                          backgroundColor: Surface.base,
                          selectedColor: Accent.danger.withValues(alpha: 0.08),
                          side: BorderSide(
                            color: tune.hiddenGenres.contains(g) ? Accent.danger.withValues(alpha: 0.35) : Surface.line,
                          ),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
                          materialTapTargetSize: MaterialTapTargetSize.padded,
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    ),
  );
}
