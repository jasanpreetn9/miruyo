// Profile's pieces, shared by every user page (yours is your profile):
// favourites, and Stats with its charts.

import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/status.dart';
import '../../core/catalog/title.dart';
import '../../core/gestures/haptics.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/motion.dart';
import '../../widgets/poster_row.dart';
import '../../widgets/section_error.dart';
import '../../widgets/skeleton.dart';
import 'charts.dart';
import 'profile_data.dart';

/// Someone's favourites: titles for [mode] (all of them with [allModes]),
/// then characters, staff and studios.
class FavouritesView extends StatelessWidget {
  const FavouritesView({super.key, required this.profile, required this.mode, this.own = true, this.allModes = false});

  final ProfileView profile;
  final Mode mode;

  /// Your own (the empty state says how to add one) or someone else's.
  final bool own;
  final bool allModes;

  @override
  Widget build(BuildContext context) {
    final p = profile;
    Widget titles(List<Title> list, String noun) => list.isEmpty
        ? (p.titlesError != null || allModes
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
                  child: Text(
                    own
                        ? 'No favourite $noun yet. Favourite a title from its page and it shows up here.'
                        : 'No favourite $noun yet.',
                    style: AppType.body.copyWith(color: TextTone.mid),
                  ),
                ))
        : PosterRow(heading: 'Favourite $noun', titles: list, showStatus: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (allModes) ...[
          if (p.anime.isNotEmpty) titles(p.anime, 'anime'),
          if (p.manga.isNotEmpty) ...[const SizedBox(height: Space.x8), titles(p.manga, 'manga')],
        ] else
          titles(mode.isAnime ? p.anime : p.manga, mode.isAnime ? 'anime' : 'manga'),
        if (p.characters.isNotEmpty) ...[
          const SizedBox(height: Space.x8),
          _People(heading: 'Favourite characters', people: p.characters),
        ],
        if (p.staff.isNotEmpty) ...[
          const SizedBox(height: Space.x8),
          _People(heading: 'Favourite staff', people: p.staff),
        ],
        if (p.studios.isNotEmpty) ...[
          const SizedBox(height: Space.x8),
          const SectionHeading(heading: 'Favourite studios'),
          const SizedBox(height: Space.x3),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                for (final s in p.studios)
                  ActionChip(
                    label: Text(s.name),
                    backgroundColor: Surface.base,
                    side: const BorderSide(color: Surface.line),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
                    onPressed: () => context.push(s.href),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _People extends StatelessWidget {
  const _People({required this.heading, required this.people});

  final String heading;
  final List<ProfilePerson> people;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeading(heading: heading),
        const SizedBox(height: Space.x3),
        SizedBox(
          height: 118,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            itemCount: people.length,
            separatorBuilder: (_, _) => const SizedBox(width: Space.x3),
            itemBuilder: (context, i) {
              final p = people[i];
              return Semantics(
                button: true,
                label: p.name,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () => context.push(p.href),
                  child: SizedBox(
                    width: 76,
                    child: Column(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Surface.s3,
                            image: p.image == null
                                ? null
                                : DecorationImage(image: CachedNetworkImageProvider(p.image!), fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          p.name,
                          maxLines: 2,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(height: 1.25),
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

/// Stats for the current mode and range, from the list collection.
/// Stats for [mode] and a range, from someone's list as the viewer is shown
/// it (forViewer). Yours has the rate prompt.
class StatsPanel extends ConsumerWidget {
  const StatsPanel({
    super.key,
    required this.mode,
    required this.range,
    required this.onRange,
    required this.entries,
    required this.userId,
    required this.scoreFormat,
    required this.onRetry,
    this.own = true,
    this.heading = true,
  });

  final Mode mode;
  final StatsRange range;
  final ValueChanged<StatsRange> onRange;
  final AsyncValue<List<CollectionEntry>> entries;
  final int userId;

  /// The scale the scores came in: yours, or 10 for anyone else.
  final ScoreFormat scoreFormat;
  final VoidCallback onRetry;
  final bool own;

  /// "Stats" over the range chips (off where a tab already says it).
  final bool heading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final collection = entries;
    final now = DateTime.now();
    final accent = context.mode;

    final header = Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (heading) ...[Text('Stats', style: AppType.section), const SizedBox(height: Space.x3)],
          Wrap(
            spacing: Space.x2,
            children: [
              for (final r in StatsRange.values)
                ChoiceChip(
                  label: Text(r.label(now)),
                  labelStyle: AppType.body.copyWith(
                    fontSize: 13,
                    fontWeight: r == range ? FontWeight.w600 : FontWeight.w400,
                    color: r == range ? accent.accentText : TextTone.high,
                  ),
                  selected: r == range,
                  onSelected: (_) => onRange(r),
                  showCheckmark: false,
                  selectedColor: accent.tint,
                  backgroundColor: Surface.base,
                  side: BorderSide(color: r == range ? accent.accent : Surface.line),
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
                ),
            ],
          ),
          const SizedBox(height: Space.x4),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        switch (collection) {
          // a reload (a newer copy of the list landed) keeps the charts it has
          AsyncValue(:final value?) => Appear(
            child: _Charts(
              stats: buildStats(value, isAnime: mode.isAnime, range: range, now: now, scoreFormat: scoreFormat),
              isAnime: mode.isAnime,
              userId: userId,
              own: own,
            ),
          ),
          AsyncError(:final error) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: SectionError(
              title: own ? "Couldn't load your stats" : "Couldn't load their stats",
              error: error,
              onRetry: onRetry,
            ),
          ),
          _ => const Padding(
            padding: EdgeInsets.symmetric(horizontal: Space.gutter),
            child: Skeleton(height: 220, radius: Corner.md),
          ),
        },
      ],
    );
  }
}

class _Charts extends ConsumerWidget {
  const _Charts({required this.stats, required this.isAnime, required this.userId, required this.own});

  final Stats stats;
  final bool isAnime;
  final int userId;
  final bool own;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activity = ref.watch(activityProvider(userId));
    String share(int count) => stats.scored == 0 ? '' : ' · ${(count * 100 / stats.scored).round()}%';

    if (stats.total == 0) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        child: Text(
          'Nothing on ${own ? 'your' : 'their'} ${isAnime ? 'anime' : 'manga'} list in this range yet.',
          style: AppType.body.copyWith(color: TextTone.mid),
        ),
      );
    }

    const gap = SizedBox(height: Space.x3);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SwipeModes(
            isAnime: isAnime,
            child: GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: Space.x3,
              crossAxisSpacing: Space.x3,
              childAspectRatio: 1.45,
              padding: EdgeInsets.zero,
              children: [for (final c in stats.cards) _Card(card: c)],
            ),
          ),
          gap,
          ChartCard(
            title: 'Score distribution',
            summary: stats.mean == null
                ? 'Nothing scored yet'
                : 'Mean ${stats.mean!.toStringAsFixed(1)} · σ ${stats.deviation!.toStringAsFixed(1)} · ${stats.scored} scored',
            builder: (context, readout) => ScrubBars(
              bars: stats.scores,
              describe: (b) => '${b.label} · ${b.count} ${b.count == 1 ? 'title' : 'titles'}${share(b.count)}',
              onReadout: readout,
            ),
          ),
          // most of the list unscored: the stats (and For You) need ratings
          if (own && stats.total - stats.scored >= 10 && stats.scored < stats.total ~/ 2)
            _RatePrompt(unscored: stats.total - stats.scored),
          gap,
          ChartCard(
            title: 'Finished · 12 months',
            summary: '${stats.months.fold(0, (a, m) => a + m.count)} finished',
            builder: (context, readout) =>
                ScrubBars(bars: stats.months, describe: (b) => '${b.name} · ${b.count} finished', onReadout: readout),
          ),
          gap,
          ChartCard(
            title: 'Formats',
            summary: '${stats.total} titles',
            builder: (context, _) => StackedBar(
              parts: [
                for (final f in stats.formats) (label: f.label, count: f.count, color: toneColor(context, f.tone)),
              ],
            ),
          ),
          gap,
          ChartCard(
            title: 'Statuses',
            summary: '${stats.total} titles',
            builder: (context, _) => StackedBar(
              parts: [for (final s in stats.statuses) (label: s.label, count: s.count, color: statusColor[s.status]!)],
            ),
          ),
          if (stats.genres.isNotEmpty) ...[
            gap,
            ChartCard(
              title: 'Top genres',
              summary: own ? 'Titles · your mean score' : 'Titles · their mean score',
              builder: (context, _) => GenreBars(genres: stats.genres),
            ),
          ],
          gap,
          ChartCard(
            title: 'Daily activity · 26 weeks',
            summary: switch (activity) {
              AsyncData(:final value) =>
                '${value.expand((w) => w).where((c) => (c?.amount ?? 0) > 0).length} active days',
              AsyncError() => "Couldn't load activity",
              _ => 'Loading…',
            },
            builder: (context, readout) => switch (activity) {
              AsyncData(:final value) when value.isNotEmpty => Heatmap(grid: value, onReadout: readout),
              _ => const Skeleton(height: 90),
            },
          ),
        ],
      ),
    );
  }
}

/// "190 titles have no score yet · Rate them": opens My List's Completed
/// tab, where rating is a tap away (the editor's score cells).
class _RatePrompt extends StatelessWidget {
  const _RatePrompt({required this.unscored});

  final int unscored;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$unscored titles have no score yet. Rate them',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(Corner.sm),
        onTap: () => context.go('/list?tab=COMPLETED&sort=updated'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.x3),
          child: Row(
            children: [
              const Icon(Symbols.star_rounded, size: 18, color: Accent.gold),
              const SizedBox(width: Space.x2),
              Expanded(
                child: Text(
                  '$unscored titles have no score yet. Rating them sharpens your stats and For You.',
                  style: AppType.caption.copyWith(color: TextTone.mid),
                ),
              ),
              Text(
                'Rate them →',
                style: AppType.caption.copyWith(color: context.mode.accentText, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The stat cards swipe between Anime and Manga: left for Manga, right
/// for Anime. They follow the finger; past 30% of the width, or a flick
/// after 24px, the mode switches (the top bar's too) and the new set slides
/// in from the side it was pulled from. Past either end only stretches.
class _SwipeModes extends ConsumerStatefulWidget {
  const _SwipeModes({required this.isAnime, required this.child});

  final bool isAnime;
  final Widget child;

  @override
  ConsumerState<_SwipeModes> createState() => _SwipeModesState();
}

class _SwipeModesState extends ConsumerState<_SwipeModes> with SingleTickerProviderStateMixin {
  late final _dx = AnimationController.unbounded(vsync: this);

  @override
  void dispose() {
    _dx.dispose();
    super.dispose();
  }

  double get _width => context.size?.width ?? 1;

  /// Left goes to Manga from Anime, right to Anime from Manga.
  bool _leads(double dx) => widget.isAnime ? dx < 0 : dx > 0;

  void _update(DragUpdateDetails d) {
    final next = _dx.value + d.primaryDelta!;
    // the way that leads nowhere only stretches
    _dx.value = _leads(next) ? next : _dx.value + d.primaryDelta! * 0.3;
  }

  void _end(DragEndDetails d) {
    final dx = _dx.value, v = d.primaryVelocity ?? 0;
    final commit = _leads(dx) && (dx.abs() >= _width * 0.3 || (dx.abs() >= 24 && v.abs() > 500 && _leads(v)));
    final reduce = MediaQuery.disableAnimationsOf(context);
    if (!commit) {
      unawaited(_dx.animateTo(0, duration: reduce ? Duration.zero : Motion.lift, curve: Motion.enter));
      return;
    }
    unawaited(ref.read(hapticsProvider).play(Haptic.selection));
    ref.read(modeProvider.notifier).set(widget.isAnime ? Mode.manga : Mode.anime);
    // the new set comes in from where the finger was pulling it
    _dx.value = -dx.sign * _width * 0.3;
    unawaited(_dx.animateTo(0, duration: reduce ? Duration.zero : Motion.panel, curve: Motion.enter));
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(label: widget.isAnime ? 'Show manga stats' : 'Show anime stats'): () =>
            ref.read(modeProvider.notifier).set(widget.isAnime ? Mode.manga : Mode.anime),
      },
      child: GestureDetector(
        onHorizontalDragUpdate: _update,
        onHorizontalDragEnd: _end,
        onHorizontalDragCancel: () => unawaited(_dx.animateTo(0, duration: Motion.lift, curve: Motion.enter)),
        child: AnimatedBuilder(
          animation: _dx,
          builder: (context, child) => Opacity(
            opacity: (1 - _dx.value.abs() / 480).clamp(0.4, 1.0),
            child: Transform.translate(offset: Offset(_dx.value, 0), child: child),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.card});

  final StatCard card;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: Surface.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(card.label, style: AppType.caption.copyWith(color: TextTone.mid)),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(card.value, style: AppType.serif(34, height: 1, weight: FontWeight.w300, tracking: -0.045)),
          ),
          Text(
            card.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppType.caption.copyWith(
              color: card.positive ? Accent.green : TextTone.low,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}
