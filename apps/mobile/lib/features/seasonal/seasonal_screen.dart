import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/humanize.dart';
import '../../core/catalog/season.dart';
import '../../core/catalog/status.dart';
import '../../core/gestures/haptics.dart';
import '../../core/gestures/row_swipe.dart';
import '../../core/list/guard.dart';
import '../../core/list/list_actions.dart';
import '../../core/list/list_store.dart';
import '../../core/notifications/episode_alerts.dart';
import '../../core/providers.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/clock.dart';
import '../../core/ui/toast.dart';
import '../../widgets/cover_grid.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/motion.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/poster_row.dart' show SectionHeading;
import '../../widgets/section_error.dart';
import '../../widgets/skeleton.dart';
import '../editor/quick_actions.dart';
import '../shell/router.dart' show tabPaths;
import '../shell/tab_scroll.dart';
import 'season_card.dart';
import 'seasonal_data.dart';

/// Seasonal. In anime mode, one tab, two views: the season chart
/// (everything premiering, after AniChart) and Airing, the week's schedule.
/// Manga has no schedule on AniList, so its tab is New releases.
class SeasonalScreen extends ConsumerStatefulWidget {
  const SeasonalScreen({super.key, this.query = const {}});

  /// ?season=WINTER&year=2027 from Home's "See all".
  final Map<String, String> query;

  @override
  ConsumerState<SeasonalScreen> createState() => _SeasonalScreenState();
}

class _SeasonalScreenState extends ConsumerState<SeasonalScreen> {
  // ?view=airing opens the schedule (Home's "You're caught up" → Schedule)
  late SeasonalView _view = _viewFromQuery();
  late SeasonYear _season = _fromQuery() ?? currentSeason();
  ChartSort _sort = ChartSort.popularity;

  SeasonalView _viewFromQuery() => widget.query['view'] == 'airing' ? SeasonalView.airing : SeasonalView.season;

  SeasonYear? _fromQuery() => parseSeasonQuery(widget.query, clock.now());

  @override
  void didUpdateWidget(SeasonalScreen old) {
    super.didUpdateWidget(old);
    if (old.query.toString() != widget.query.toString()) {
      setState(() {
        _season = _fromQuery() ?? currentSeason();
        _view = _viewFromQuery();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAnime = ref.watch(modeProvider).isAnime;
    if (!isAnime) return const _NewReleases();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<SeasonalView>(
              segments: const [
                ButtonSegment(
                  value: SeasonalView.season,
                  label: Text('Season'),
                  icon: Icon(Symbols.calendar_month_rounded),
                ),
                ButtonSegment(value: SeasonalView.airing, label: Text('Airing'), icon: Icon(Symbols.schedule_rounded)),
              ],
              selected: {_view},
              showSelectedIcon: false,
              onSelectionChanged: (v) => setState(() => _view = v.first),
              // the chosen side in ink, square, as the page's main buttons are
              style: SegmentedButton.styleFrom(
                selectedBackgroundColor: TextTone.high,
                selectedForegroundColor: Surface.base,
                backgroundColor: Colors.transparent,
                foregroundColor: TextTone.mid,
                side: const BorderSide(color: Surface.line),
                shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(Corner.sm))),
                textStyle: AppType.body.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
        Expanded(
          child: _view == SeasonalView.season
              ? _SeasonChart(
                  season: _season,
                  sort: _sort,
                  onSeason: (s) => setState(() => _season = s),
                  onSort: (s) => setState(() => _sort = s),
                )
              : const _Schedule(),
        ),
      ],
    );
  }
}

// ── Season chart ──

/// The season chart's view, remembered on the device: cards carry the
/// synopsis, genres and score; posters (cover, title, countdown) fit a
/// season in a few screens instead of a dozen.
final seasonPostersProvider = NotifierProvider<_SeasonPosters, bool>(_SeasonPosters.new);

class _SeasonPosters extends Notifier<bool> {
  @override
  bool build() => ref.read(prefsProvider).getString(PrefKeys.seasonView) == 'posters';

  void set(bool posters) {
    state = posters;
    unawaited(ref.read(prefsProvider).setString(PrefKeys.seasonView, posters ? 'posters' : 'cards'));
  }
}

class _SeasonChart extends ConsumerWidget {
  const _SeasonChart({required this.season, required this.sort, required this.onSeason, required this.onSort});

  final SeasonYear season;
  final ChartSort sort;
  final ValueChanged<SeasonYear> onSeason;
  final ValueChanged<ChartSort> onSort;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chart = ref.watch(seasonChartProvider(season));
    final posters = ref.watch(seasonPostersProvider);
    final titles = ref.watch(sessionProvider.select((s) => s.titles));
    final now = currentSeason();
    final tabs = seasonWindow(now);
    if (!tabs.contains(season)) tabs[tabs.length - 1] = season;
    final mode = context.mode;

    final header = SliverToBoxAdapter(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: Space.x3),
          // the seasons, then the sort: the selected chip names the season,
          // so no heading repeats it
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.only(left: Space.gutter),
                    children: [
                      for (final s in tabs)
                        Padding(
                          padding: const EdgeInsets.only(right: Space.x2),
                          // the seasons as words, the one on show over a rule in the accent
                          child: Semantics(
                            button: true,
                            selected: s == season,
                            child: InkWell(
                              onTap: () => onSeason(s),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: Space.x2),
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  border: Border(
                                    bottom: BorderSide(color: s == season ? mode.accent : Colors.transparent, width: 2),
                                  ),
                                ),
                                child: Text(
                                  seasonName(s),
                                  style: AppType.body.copyWith(
                                    fontSize: 14,
                                    fontWeight: s == season ? FontWeight.w600 : FontWeight.w400,
                                    color: s == season ? TextTone.high : TextTone.mid,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              IconButton(
                tooltip: posters ? 'Show as cards' : 'Show as posters',
                onPressed: () => ref.read(seasonPostersProvider.notifier).set(!posters),
                icon: Icon(posters ? Symbols.view_agenda_rounded : Symbols.grid_view_rounded, size: 22),
                color: TextTone.mid,
              ),
              PopupMenuButton<ChartSort>(
                initialValue: sort,
                onSelected: onSort,
                color: Surface.s3,
                tooltip: 'Sort: ${sort.label}',
                itemBuilder: (_) => [for (final s in ChartSort.values) PopupMenuItem(value: s, child: Text(s.label))],
                child: const SizedBox(
                  width: Space.minTarget + Space.x2,
                  height: Space.minTarget,
                  child: Icon(Symbols.sort_rounded, size: 22, color: TextTone.mid),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    final body = switch (chart) {
      AsyncData(:final value) => () {
        final sections = buildSeasonChart(
          value.media,
          value.leftovers,
          season: season,
          nowSeconds: clock.now().millisecondsSinceEpoch ~/ 1000,
          titles: titles,
          sort: sort,
        );
        if (sections.isEmpty) {
          return [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(Space.x6),
                child: Text(
                  'Nothing announced for ${seasonName(season)} yet.',
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(color: TextTone.mid),
                ),
              ),
            ),
          ];
        }
        return [
          SliverToBoxAdapter(
            child: _Masthead(season: season, premiering: value.media.length, leftovers: value.leftovers.length),
          ),
          for (final section in sections) ...[
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(0, Space.x8, 0, Space.x1),
              sliver: SliverToBoxAdapter(
                child: SectionHeading(
                  heading: section.label,
                  jp: _gloss[section.key],
                  subtitle: '${section.cards.length}',
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
              sliver: posters
                  ? SliverGrid(
                      // the countdown chip adds a line under the title
                      gridDelegate: CoverGridDelegate.of(context, below: posterCardBelow + 28),
                      delegate: SliverChildBuilderDelegate(
                        (_, i) => PosterCard(title: section.cards[i].title, countdown: true),
                        childCount: section.cards.length,
                      ),
                    )
                  : SliverList.builder(
                      itemCount: section.cards.length,
                      itemBuilder: (_, i) => SeasonCardView(card: section.cards[i]),
                    ),
            ),
          ],
        ];
      }(),
      AsyncError(:final error) => [
        SliverPadding(
          padding: const EdgeInsets.all(Space.gutter),
          sliver: SliverToBoxAdapter(
            child: SectionError(
              title: "Couldn't load the season",
              error: error,
              onRetry: () => ref.invalidate(seasonChartProvider(season)),
            ),
          ),
        ),
      ],
      _ => [
        SliverPadding(
          padding: const EdgeInsets.all(Space.gutter),
          sliver: SliverList.separated(
            itemCount: 4,
            separatorBuilder: (_, _) => const SizedBox(height: Space.x3),
            itemBuilder: (_, _) => const Skeleton(height: 160, radius: Corner.sm),
          ),
        ),
      ],
    };

    return RefreshIndicator.adaptive(
      onRefresh: () {
        ref.read(anilistClientProvider).clearCache();
        return ref.refresh(seasonChartProvider(season).future);
      },
      child: CustomScrollView(
        slivers: [
          header,
          ...body,
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}

/// Each section's Japanese gloss (テレビ), as on the web.
const _gloss = {'tv': 'テレビ', 'short': 'ショート', 'leftovers': '継続', 'movie': '劇場', 'other': 'OVA・配信'};

/// The season's masthead: its kanji in
/// vermilion beside the season set large, and what's premiering.
class _Masthead extends StatelessWidget {
  const _Masthead({required this.season, required this.premiering, required this.leftovers});

  final SeasonYear season;
  final int premiering;
  final int leftovers;

  static const _kanji = {
    MediaSeason.winter: '冬',
    MediaSeason.spring: '春',
    MediaSeason.summer: '夏',
    MediaSeason.fall: '秋',
  };

  @override
  Widget build(BuildContext context) {
    final strong = AppType.body.copyWith(color: TextTone.high, fontWeight: FontWeight.w600);
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x5, Space.gutter, 0),
      child: Container(
        padding: const EdgeInsets.only(bottom: Space.x5),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Surface.line, width: 3)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Appear(
              child: ExcludeSemantics(
                child: Text(
                  _kanji[season.season] ?? '',
                  style: const TextStyle(
                    fontFamilyFallback: AppType.jpFallback,
                    fontSize: 72,
                    height: 0.9,
                    fontWeight: FontWeight.w700,
                    color: Accent.beni,
                  ),
                ),
              ),
            ),
            const SizedBox(width: Space.x4),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Appear(
                    delay: const Duration(milliseconds: 80),
                    child: Semantics(
                      header: true,
                      child: Text.rich(
                        TextSpan(
                          text: '${humanizeSeason(season.season)} ',
                          children: [
                            TextSpan(
                              text: '${season.year}',
                              style: AppType.displayL.copyWith(
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        style: AppType.displayL,
                      ),
                    ),
                  ),
                  const SizedBox(height: Space.x2),
                  Appear(
                    delay: const Duration(milliseconds: 160),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '$premiering ${premiering == 1 ? 'title' : 'titles'}', style: strong),
                          const TextSpan(text: ' premiering'),
                          if (leftovers > 0) ...[
                            const TextSpan(text: ', '),
                            TextSpan(text: '$leftovers still airing', style: strong),
                            const TextSpan(text: ' from earlier seasons'),
                          ],
                          const TextSpan(text: '.'),
                        ],
                      ),
                      style: AppType.body.copyWith(color: TextTone.mid),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Airing: the week's schedule ──

class _Schedule extends ConsumerStatefulWidget {
  const _Schedule();

  @override
  ConsumerState<_Schedule> createState() => _ScheduleState();
}

/// The week's schedule: a week bar that swipes between weeks, a day
/// strip that jumps or scrubs, the days stacked below, and a pill back to
/// now when it's out of sight.
class _ScheduleState extends ConsumerState<_Schedule> with SingleTickerProviderStateMixin {
  /// Weeks from this one: AniList's schedule is unreliable past ±4.
  int _week = 0;
  bool _mineOnly = false;
  final _keys = <int, GlobalKey>{};
  final _scroll = ScrollController();
  final _list = GlobalKey();

  /// The day (0 = Monday) whose header is at the top of the list, for the
  /// strip's highlight.
  int? _topDay;

  /// Today's header is out of sight (this week only).
  bool _todayHidden = false;

  /// The days (0 = Monday) in the order the list shows them.
  var _order = <int>[];

  /// While scrubbing the strip: the day under the finger, for the bubble.
  int? _scrubDay;

  /// This week's days already past are open (they fold under "Earlier this
  /// week", so the list reads today onwards).
  bool _earlierOpen = false;

  /// The list's sideways offset while the week bar is swiped.
  late final _weekDx = AnimationController.unbounded(vsync: this);

  static const _weekLimit = 4;

  DateTime get _monday => addDays(mondayOf(clock.now()), _week * 7);

  @override
  void dispose() {
    _weekDx.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// Counts jumps, so a newer one (scrubbing) stops an older one.
  var _jump = 0;

  /// Scrolls [day]'s header to the top. A header far off screen isn't built
  /// yet, so the list steps toward it a screen at a time until it is.
  Future<void> _jumpTo(int day, {bool animate = true}) async {
    final jump = ++_jump;
    final reduce = MediaQuery.disableAnimationsOf(context);
    // a day folded under "Earlier this week" opens first
    if (_week == 0 && !_earlierOpen && day < clock.now().weekday - 1) {
      setState(() => _earlierOpen = true);
      await WidgetsBinding.instance.endOfFrame;
    }
    for (var tries = 0; tries < 40 && jump == _jump && mounted; tries++) {
      final ctx = _keys[day]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(
          ctx,
          duration: animate && !reduce ? Motion.panel : Duration.zero,
          curve: Motion.enter,
          alignment: 0,
        );
        return;
      }
      if (!_scroll.hasClients) return;
      final pos = _scroll.position;
      final from = _topDay == null ? 0 : _order.indexOf(_topDay!);
      final down = _order.indexOf(day) > from;
      final next = (pos.pixels + pos.viewportDimension * (down ? 1 : -1)).clamp(
        pos.minScrollExtent,
        pos.maxScrollExtent,
      );
      if (next == pos.pixels) return;
      _scroll.jumpTo(next);
      await WidgetsBinding.instance.endOfFrame;
      _track();
    }
  }

  void _shift(int by) {
    final next = (_week + by).clamp(-_weekLimit, _weekLimit);
    if (next == _week) return;
    unawaited(ref.read(hapticsProvider).play(Haptic.selection));
    setState(() {
      _week = next;
      _topDay = null;
      _earlierOpen = false;
    });
    // a new week opens at its first day
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  /// Back to now: this week, scrolled to today.
  void _backToNow() {
    if (_week != 0) {
      _shift(-_week);
      return;
    }
    if (_scroll.hasClients) {
      final reduce = MediaQuery.disableAnimationsOf(context);
      unawaited(_scroll.animateTo(0, duration: reduce ? Duration.zero : Motion.sheet, curve: Motion.enter));
    }
  }

  /// After a scroll: which day is at the top, and whether today is in view.
  void _track() {
    final list = _list.currentContext?.findRenderObject();
    if (list is! RenderBox || !list.attached) return;
    final top = list.localToGlobal(Offset.zero).dy;
    final bottom = top + list.size.height;
    // the last header at or above the top edge; before any has passed it,
    // the first one below
    int? above, below;
    var aboveY = double.negativeInfinity, belowY = double.infinity;
    // a header far off screen isn't built: today is out of sight then too
    var todayHidden = _week == 0;
    final today = clock.now().weekday - 1;
    for (final MapEntry(key: day, value: key) in _keys.entries) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final y = box.localToGlobal(Offset.zero).dy;
      if (y <= top + 8 && y > aboveY) {
        above = day;
        aboveY = y;
      } else if (y > top + 8 && y < belowY) {
        below = day;
        belowY = y;
      }
      if (_week == 0 && day == today) todayHidden = y + box.size.height < top || y > bottom - 120;
    }
    // the header above may be too far up to be built: then it's the day
    // before the first one below
    final at = below == null ? -1 : _order.indexOf(below);
    final topDay = above ?? (_scroll.hasClients && _scroll.offset > 0 && at > 0 ? _order[at - 1] : below);
    if (topDay != _topDay || todayHidden != _todayHidden) {
      setState(() {
        _topDay = topDay;
        _todayHidden = todayHidden;
      });
    }
  }

  // ── swiping the week bar ──
  double get _barWidth => context.size?.width ?? 390;

  bool _canGo(double dx) {
    final by = dx < 0 ? 1 : -1;
    return (_week + by).abs() <= _weekLimit;
  }

  void _weekUpdate(DragUpdateDetails d) {
    final next = _weekDx.value + d.primaryDelta!;
    // past ±4 weeks it only stretches
    _weekDx.value = _canGo(next) ? next : _weekDx.value + d.primaryDelta! * 0.3;
  }

  void _weekEnd(DragEndDetails d) {
    final dx = _weekDx.value, v = d.primaryVelocity ?? 0;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final commit =
        _canGo(dx) && (dx.abs() >= _barWidth * 0.3 || (dx.abs() >= 24 && v.abs() > 500 && v.sign == dx.sign));
    if (!commit) {
      unawaited(_weekDx.animateTo(0, duration: reduce ? Duration.zero : Motion.lift, curve: Motion.enter));
      return;
    }
    _shift(dx < 0 ? 1 : -1);
    // the new week comes in from the side it was swiped toward
    _weekDx.value = -dx.sign * _barWidth * 0.3;
    unawaited(_weekDx.animateTo(0, duration: reduce ? Duration.zero : Motion.panel, curve: Motion.enter));
  }

  @override
  Widget build(BuildContext context) {
    // tapping the Seasonal tab again goes back to now
    ref.listen(tabReselectProvider, (_, tap) {
      if (tap != null && tap.$1 == tabPaths.indexOf('/seasonal')) _backToNow();
    });
    final monday = _monday;
    final week = ref.watch(airingWeekProvider(monday));
    final session = ref.watch(sessionProvider);
    // rebuild when entries change, so "mine" and +1 stay current
    ref.watch(listStoreProvider);
    final store = ref.read(listStoreProvider);
    final now = DateTime.fromMillisecondsSinceEpoch((ref.watch(clockProvider).value ?? 0) * 1000);
    final mode = context.mode;

    final days = switch (week) {
      AsyncData(:final value) => buildCalendar(
        value,
        monday,
        now: now.millisecondsSinceEpoch == 0 ? clock.now() : now,
        titles: session.titles,
        mineOnly: _mineOnly,
        entry: (id) {
          final e = store.entries[id];
          return e == null ? null : (status: e.status, progress: e.progress);
        },
      ),
      _ => null,
    };
    final strip = days == null ? null : ([...days]..sort((a, b) => a.date.compareTo(b.date)));
    if (days != null) {
      _order = [for (final d in days) d.date.weekday - 1];
      WidgetsBinding.instance.addPostFrameCallback((_) => mounted ? _track() : null);
    }

    final scrubbed = _scrubDay == null ? null : strip?.where((d) => d.date.weekday - 1 == _scrubDay).firstOrNull;
    final showPill = days != null && (_week != 0 || _todayHidden);

    return Column(
      children: [
        // the week bar: swipe it, or use the chevrons, to change the week
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragUpdate: _weekUpdate,
          onHorizontalDragEnd: _weekEnd,
          onHorizontalDragCancel: () => unawaited(_weekDx.animateTo(0, duration: Motion.lift, curve: Motion.enter)),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Space.x2, Space.x2, Space.gutter, 0),
            child: Row(
              children: [
                IconButton(
                  tooltip: 'Previous week',
                  onPressed: _week > -_weekLimit ? () => _shift(-1) : null,
                  icon: const Icon(Symbols.chevron_left_rounded),
                ),
                Expanded(
                  child: Text(
                    weekLabel(monday),
                    textAlign: TextAlign.center,
                    style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Next week',
                  onPressed: _week < _weekLimit ? () => _shift(1) : null,
                  icon: const Icon(Symbols.chevron_right_rounded),
                ),
                // only what's on your list
                if (session.signedIn)
                  Padding(
                    padding: const EdgeInsets.only(left: Space.x1),
                    child: Semantics(
                      toggled: _mineOnly,
                      child: FilterChip(
                        avatar: Icon(
                          Symbols.bookmarks_rounded,
                          size: 18,
                          fill: _mineOnly ? 1 : 0,
                          color: _mineOnly ? Surface.base : TextTone.mid,
                        ),
                        label: const Text('My list'),
                        labelStyle: AppType.body.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _mineOnly ? Surface.base : TextTone.high,
                        ),
                        selected: _mineOnly,
                        onSelected: (v) => setState(() => _mineOnly = v),
                        showCheckmark: false,
                        selectedColor: TextTone.high,
                        backgroundColor: Surface.base,
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
                        side: BorderSide(color: _mineOnly ? TextTone.high : Surface.line),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (strip != null) _strip(strip, mode),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: AnimatedBuilder(
                  animation: _weekDx,
                  builder: (context, child) => Opacity(
                    opacity: (1 - _weekDx.value.abs() / 480).clamp(0.4, 1.0),
                    child: Transform.translate(offset: Offset(_weekDx.value, 0), child: child),
                  ),
                  child: _days(week, days, monday),
                ),
              ),
              // the scrub bubble names the day under the finger
              if (scrubbed != null)
                Positioned(
                  top: Space.x3,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: _Bubble(
                      text: '${scrubbed.isToday ? 'Today' : scrubbed.weekday} · ${scrubbed.label}',
                      detail: '${scrubbed.slots.length} airing',
                    ),
                  ),
                ),
              // Back to now: today out of sight, or another week
              Positioned(
                bottom: 112,
                left: 0,
                right: 0,
                child: Center(
                  child: AnimatedSwitcher(
                    duration: Motion.overlay,
                    child: showPill
                        ? ActionChip(
                            key: ValueKey(_week == 0),
                            avatar: Icon(
                              _week == 0 ? Symbols.arrow_upward_rounded : Symbols.today_rounded,
                              size: 18,
                              color: mode.onAccent,
                            ),
                            label: Text(_week == 0 ? 'Back to now' : 'This week'),
                            labelStyle: AppType.body.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: mode.onAccent,
                            ),
                            backgroundColor: TextTone.high,
                            side: BorderSide.none,
                            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
                            elevation: 4,
                            onPressed: _backToNow,
                          )
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// The day strip: tap a day to scroll to it, or drag along it to scrub
  /// through the week, a day at a time with no animation.
  Widget _strip(List<CalendarDay> strip, ModeColors mode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      child: LayoutBuilder(
        builder: (context, box) {
          int dayAt(double x) {
            final i = (x / (box.maxWidth / strip.length)).floor().clamp(0, strip.length - 1);
            return strip[i].date.weekday - 1;
          }

          void scrub(double x) {
            final day = dayAt(x);
            if (day == _scrubDay) return;
            unawaited(ref.read(hapticsProvider).play(Haptic.selection));
            setState(() => _scrubDay = day);
            unawaited(_jumpTo(day, animate: false));
          }

          return GestureDetector(
            // the strip owns every drag that starts on it
            onHorizontalDragStart: (d) => scrub(d.localPosition.dx),
            onHorizontalDragUpdate: (d) => scrub(d.localPosition.dx),
            onHorizontalDragEnd: (_) => setState(() => _scrubDay = null),
            onHorizontalDragCancel: () => setState(() => _scrubDay = null),
            child: SizedBox(
              height: 52,
              child: Row(
                children: [
                  for (final (i, d) in strip.indexed)
                    Expanded(
                      child: Padding(
                        padding: EdgeInsets.only(left: i == 0 ? 0 : 3, right: i == strip.length - 1 ? 0 : 3),
                        child: _DayChip(
                          day: d,
                          current: (_scrubDay ?? _topDay) == d.date.weekday - 1,
                          onTap: () => unawaited(_jumpTo(d.date.weekday - 1)),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _days(AsyncValue<List<AiringSlot>> week, List<CalendarDay>? days, DateTime monday) {
    return switch (week) {
      AsyncError(:final error) => ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          SectionError(
            title: "Couldn't load the schedule",
            error: error,
            onRetry: () => ref.invalidate(airingWeekProvider(monday)),
          ),
        ],
      ),
      _ when days == null => ListView(
        padding: const EdgeInsets.all(Space.gutter),
        children: [
          for (var i = 0; i < 6; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: Space.x3),
              child: Skeleton(height: 64),
            ),
        ],
      ),
      _ => NotificationListener<ScrollUpdateNotification>(
        onNotification: (_) {
          _track();
          return false;
        },
        child: RefreshIndicator.adaptive(
          onRefresh: () {
            ref.read(anilistClientProvider).clearCache();
            return ref.refresh(airingWeekProvider(monday).future);
          },
          child: CustomScrollView(
            key: _list,
            controller: _scroll,
            slivers: [
              for (final (i, day) in days.indexed) ...[
                if (day.past && (i == 0 || !days[i - 1].past))
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(Space.x2, Space.x6, Space.x2, 0),
                    sliver: SliverToBoxAdapter(child: _earlier(days)),
                  ),
                if (!day.past || _earlierOpen) ..._day(day),
              ],
              // room to scroll the last day to the top, under the pill
              const SliverToBoxAdapter(child: SizedBox(height: 360)),
            ],
          ),
        ),
      ),
    };
  }

  /// "Earlier this week · 29 episodes": the days already past, folded until
  /// tapped.
  Widget _earlier(List<CalendarDay> days) {
    final episodes = days.where((d) => d.past).fold(0, (sum, d) => sum + d.slots.length);
    return Semantics(
      button: true,
      expanded: _earlierOpen,
      child: InkWell(
        borderRadius: BorderRadius.circular(Corner.sm),
        onTap: () => setState(() => _earlierOpen = !_earlierOpen),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: Space.minTarget),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.x2),
            child: Row(
              children: [
                Text('EARLIER THIS WEEK', style: AppType.overline.copyWith(color: TextTone.low)),
                const SizedBox(width: Space.x2),
                Text(
                  '· $episodes ${episodes == 1 ? 'episode' : 'episodes'}',
                  style: AppType.numeric.copyWith(fontSize: 12, color: TextTone.low),
                ),
                const SizedBox(width: Space.x1),
                AnimatedRotation(
                  turns: _earlierOpen ? 0.5 : 0,
                  duration: Motion.overlay,
                  child: const Icon(Symbols.expand_more_rounded, size: 18, color: TextTone.low),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// One day: its header (read while scrolling, for the strip), then its slots.
  List<Widget> _day(CalendarDay day) => [
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x5, Space.gutter, Space.x2),
      sliver: SliverToBoxAdapter(
        child: Row(
          // on the header's box: its position is read while scrolling
          key: _keys.putIfAbsent(day.date.weekday - 1, GlobalKey.new),
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(day.isToday ? 'Today' : day.weekday, style: AppType.section),
            const SizedBox(width: Space.x2),
            // mono and medium, as on the web: thin body strokes at this size
            // measure under 4.5:1 once anti-aliased
            Text(day.label, style: AppType.numeric.copyWith(fontSize: 14, color: TextTone.low)),
            const Spacer(),
            Text('${day.slots.length}', style: AppType.numeric.copyWith(color: TextTone.low)),
          ],
        ),
      ),
    ),
    if (day.slots.isEmpty)
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        sliver: SliverToBoxAdapter(
          child: Text(
            _mineOnly ? 'Nothing from your list.' : 'Nothing airs.',
            style: AppType.body.copyWith(color: TextTone.low),
          ),
        ),
      )
    else
      SliverList.builder(
        itemCount: day.slots.length,
        itemBuilder: (_, j) => _SlotRow(slot: day.slots[j]),
      ),
  ];
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.day, required this.current, required this.onTap});

  final CalendarDay day;

  /// The day at the top of the list (or under a scrubbing finger).
  final bool current;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final mode = context.mode;
    return Semantics(
      button: true,
      selected: current,
      label: '${day.weekday}, ${day.slots.length} airing',
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(2),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.overlay,
          decoration: BoxDecoration(
            color: day.isToday ? mode.tint : Surface.s1,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(
              color: current ? mode.accent : (day.isToday ? mode.accent.withValues(alpha: 0.4) : Surface.line),
              width: current ? 1.5 : 1,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                day.isToday ? 'Today' : day.name,
                maxLines: 1,
                style: AppType.caption.copyWith(fontSize: 11, color: day.isToday ? mode.accentText : TextTone.mid),
              ),
              Text('${day.date.day}', style: AppType.numeric.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The scrub bubble: "Friday · Oct 9", "12 airing".
class _Bubble extends StatelessWidget {
  const _Bubble({required this.text, required this.detail});

  final String text;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.x4, vertical: Space.x2),
      decoration: BoxDecoration(
        color: Surface.s3,
        borderRadius: BorderRadius.circular(Corner.full),
        border: Border.all(color: const Color(0x24FFFFFF)),
        boxShadow: const [BoxShadow(color: Color(0x66000000), blurRadius: 16, offset: Offset(0, 6))],
      ),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: text,
              style: AppType.body.copyWith(fontWeight: FontWeight.w600),
            ),
            TextSpan(
              text: '  $detail',
              style: AppType.caption.copyWith(color: TextTone.mid),
            ),
          ],
        ),
      ),
    );
  }
}

class _SlotRow extends ConsumerWidget {
  const _SlotRow({required this.slot});

  final CalendarSlot slot;

  // eases in as it's built: loaded in place of a skeleton, or scrolled to
  @override
  Widget build(BuildContext context, WidgetRef ref) => Appear(child: _build(context, ref));

  Widget _build(BuildContext context, WidgetRef ref) {
    final title = slot.title;
    final mode = context.mode;
    final until = slot.airingAt - clock.now().millisecondsSinceEpoch ~/ 1000;
    String left() {
      final d = until ~/ 86400, h = (until % 86400) ~/ 3600, m = (until % 3600) ~/ 60;
      return d > 0
          ? '${d}d ${h}h'
          : h > 0
          ? '${h}h ${m.toString().padLeft(2, '0')}m'
          : '${m}m';
    }

    final store = ref.watch(listStoreProvider);
    final entry = store.entryFor(title);
    final actions = ref.read(listActionsProvider);
    void act(void Function() run) {
      if (canEditList(context, ref)) run();
    }

    final reminded = ref.watch(
      remindersProvider.select((r) => r.any((x) => x.mediaId == title.id && x.episode == slot.episode)),
    );
    Future<void> remind() async {
      final reminders = ref.read(remindersProvider.notifier);
      final toasts = ref.read(toastProvider.notifier);
      final haptics = ref.read(hapticsProvider);
      if (reminded) {
        await reminders.remove(title.id);
        unawaited(haptics.play(Haptic.light));
        toasts.show('Reminder off · ${title.title}');
        return;
      }
      final reminder = EpisodeAlert(
        mediaId: title.id,
        title: title.title,
        episode: slot.episode,
        at: DateTime.fromMillisecondsSinceEpoch(slot.airingAt * 1000, isUtc: true),
      );
      if (!await reminders.add(reminder)) {
        toasts.show('Notifications are off for miruyo. Turn them on in the Settings app.', tone: ToastTone.error);
        return;
      }
      unawaited(haptics.play(Haptic.success));
      toasts.show(
        'Reminder · EP ${slot.episode} at ${slot.time}',
        tone: ToastTone.success,
        action: ToastAction('Undo', () => unawaited(reminders.remove(title.id))),
      );
    }

    // Slots swipe by what they can do: yours and
    // aired, +1; upcoming, a reminder on or off; aired and not on your list,
    // Planning; left is −1 on yours with progress. Caught up, nothing arms.
    final (VoidCallback? positive, String label, IconData icon) = switch (slot) {
      _ when slot.canAddOne => (() => act(() => unawaited(actions.plusOne(title))), '+1', Symbols.add_rounded),
      _ when !slot.aired => (
        () => unawaited(remind()),
        reminded ? 'Reminder off' : 'Remind me',
        reminded ? Symbols.notifications_off_rounded : Symbols.notifications_active_rounded,
      ),
      _ when entry == null => (
        () => act(() => unawaited(actions.changeStatus(title, MediaListStatus.planning))),
        'Planning',
        Symbols.bookmark_add_rounded,
      ),
      _ => (null, '+1', Symbols.add_rounded),
    };

    return RowSwipe(
      borderRadius: 12,
      onPositive: positive,
      positiveLabel: label,
      positiveIcon: icon,
      onNegative: slot.mine && (entry?.progress ?? 0) > 0 ? () => act(() => unawaited(actions.minusOne(title))) : null,
      onMore: () => unawaited(showQuickActions(context, ref, title)),
      child: InkWell(
        onTap: () => context.push('/title/${title.id}'),
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: 2),
          padding: const EdgeInsets.symmetric(horizontal: Space.x2, vertical: 6),
          decoration: BoxDecoration(
            color: slot.mine ? title.colors.tint : Colors.transparent,
            borderRadius: BorderRadius.circular(2),
            border: Border.all(color: slot.mine ? title.colors.accent.withValues(alpha: 0.4) : Colors.transparent),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 72,
                height: 108,
                child: CoverImage(title: title, thumb: true, radius: 8, showMissing: false),
              ),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                        color: slot.aired && !slot.mine ? TextTone.mid : TextTone.high,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // the time, then the episode and how long until it airs
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: slot.time,
                            style: AppType.numeric.copyWith(
                              fontWeight: FontWeight.w600,
                              color: slot.aired ? TextTone.low : TextTone.high,
                            ),
                          ),
                          TextSpan(
                            text:
                                '  EP ${slot.episode}${title.eps != null ? '/${title.eps}' : ''}'
                                ' · ${slot.aired ? 'aired' : left()}',
                            style: AppType.numeric.copyWith(
                              fontSize: 12,
                              color: slot.aired ? TextTone.low : (slot.soon ? mode.accentText : Accent.soraText),
                            ),
                          ),
                          // a reminder is set: the bell stays on the slot
                          if (reminded && !slot.aired)
                            const WidgetSpan(
                              alignment: PlaceholderAlignment.middle,
                              child: Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(
                                  Symbols.notifications_active_rounded,
                                  size: 14,
                                  fill: 1,
                                  color: Accent.sora,
                                  semanticLabel: 'Reminder set',
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      [title.format, title.studio].whereType<String>().join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.caption.copyWith(color: TextTone.mid, fontWeight: FontWeight.w400),
                    ),
                    const SizedBox(height: 4),
                    // yours: where you are; otherwise: the score and genres
                    if (entry != null)
                      Row(
                        children: [
                          Container(
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(color: statusColor[entry.status], shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              '${statusLabel(entry.status, isAnime: title.isAnime)} · '
                              '${title.unit} ${entry.progress} / ${title.total ?? '?'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(color: statusColor[entry.status]),
                            ),
                          ),
                        ],
                      )
                    else
                      Row(
                        children: [
                          if (title.score > 0) ...[
                            const Icon(Symbols.star_rounded, size: 13, fill: 1, color: Accent.gold),
                            const SizedBox(width: 2),
                            Text(
                              title.score.toStringAsFixed(1),
                              style: AppType.numeric.copyWith(fontSize: 11, fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(width: 6),
                          ],
                          Expanded(
                            child: Text(
                              title.genres.take(3).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AppType.caption.copyWith(color: title.colors.accent),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
              if (slot.canAddOne)
                IconButton.filled(
                  tooltip: 'Watched episode ${slot.episode}',
                  style: IconButton.styleFrom(
                    backgroundColor: Quiet.fill,
                    foregroundColor: TextTone.high,
                    side: const BorderSide(color: Quiet.border),
                  ),
                  icon: const Icon(Symbols.add_rounded, size: 20),
                  onPressed: () {
                    if (canEditList(context, ref)) unawaited(ref.read(listActionsProvider).plusOne(title));
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Manga: New releases ──

class _NewReleases extends ConsumerWidget {
  const _NewReleases();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releases = ref.watch(newMangaProvider);
    return RefreshIndicator.adaptive(
      onRefresh: () {
        ref.read(anilistClientProvider).clearCache();
        return ref.refresh(newMangaProvider.future);
      },
      child: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x5, Space.gutter, Space.x2),
            sliver: SliverToBoxAdapter(
              child: Row(
                children: [
                  Text('New releases', style: AppType.heading.copyWith(fontSize: 24)),
                  // why this isn't a chapter schedule, on request rather than up front
                  IconButton(
                    tooltip: 'About New releases',
                    icon: const Icon(Symbols.info_rounded, size: 20, color: TextTone.low),
                    onPressed: () => showDialog<void>(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Surface.s2,
                        title: const Text('New releases'),
                        content: const Text(
                          "AniList doesn't publish chapter release times, so this follows series: popular ones "
                          'that started serializing in the last few months.',
                        ),
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          switch (releases) {
            AsyncData(:final value) => SliverPadding(
              padding: const EdgeInsets.all(Space.gutter),
              sliver: SliverGrid(
                gridDelegate: CoverGridDelegate.of(context, below: posterCardBelow),
                delegate: SliverChildBuilderDelegate(
                  (_, i) => PosterCard(title: value[i], meta: PosterMeta.genres),
                  childCount: value.length,
                ),
              ),
            ),
            AsyncError(:final error) => SliverPadding(
              padding: const EdgeInsets.all(Space.gutter),
              sliver: SliverToBoxAdapter(
                child: SectionError(
                  title: "Couldn't load new releases",
                  error: error,
                  onRetry: () => ref.invalidate(newMangaProvider),
                ),
              ),
            ),
            _ => const SliverPadding(
              padding: EdgeInsets.all(Space.gutter),
              sliver: SliverToBoxAdapter(child: Skeleton(height: 260)),
            ),
          },
          const SliverToBoxAdapter(child: SizedBox(height: 120)),
        ],
      ),
    );
  }
}
