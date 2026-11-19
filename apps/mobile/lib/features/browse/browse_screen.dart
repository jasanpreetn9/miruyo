import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/status.dart';
import '../../core/catalog/title.dart';
import '../../core/gestures/haptics.dart';
import '../../core/gestures/row_swipe.dart';
import '../../core/list/guard.dart';
import '../../core/list/list_actions.dart';
import '../../core/list/list_entry.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/toast.dart';
import '../../widgets/cover_grid.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/peek.dart';
import '../../widgets/poster_card.dart';
import '../../widgets/section_error.dart';
import '../../widgets/skeleton.dart';
import '../for_you/for_you_data.dart' show dismissedPicksProvider;
import 'browse_controller.dart';
import 'browse_params.dart';
import 'filter_sheet.dart';
import 'search_people.dart';

/// Search & browse (02, 15). The search bar slides away as you scroll down
/// and comes back on any scroll up; the filter chips stay pinned. Pinch to
/// switch between the 3-across grid and the list, or use the density button.
class BrowseScreen extends ConsumerStatefulWidget {
  const BrowseScreen({super.key, this.query = const {}});

  /// The link's filters (?sort=trending&status=RELEASING).
  final Map<String, List<String>> query;

  @override
  ConsumerState<BrowseScreen> createState() => _BrowseScreenState();
}

class _BrowseScreenState extends ConsumerState<BrowseScreen> {
  final _search = TextEditingController();

  /// The tab's primary controller (TabScrollScope), so tapping Browse again
  /// scrolls to the top; its own when there's none (tests).
  ScrollController? _scroll;
  ScrollController? _own;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyLink());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = PrimaryScrollController.maybeOf(context) ?? (_own ??= ScrollController());
    if (next == _scroll) return;
    _scroll?.removeListener(_onScroll);
    _scroll = next..addListener(_onScroll);
  }

  @override
  void didUpdateWidget(BrowseScreen old) {
    super.didUpdateWidget(old);
    if (old.query.toString() != widget.query.toString()) _applyLink();
  }

  /// A "See all" or a genre chip opened Browse with its filters set.
  void _applyLink() {
    if (widget.query.isEmpty) return;
    final isAnime = ref.read(modeProvider).isAnime;
    final state = BrowseState.fromQuery(widget.query, isAnime: isAnime);
    _search.text = state.q;
    ref.read(browseProvider.notifier).apply(state);
    if (_scroll?.hasClients ?? false) _scroll!.jumpTo(0);
  }

  void _onScroll() {
    final position = _scroll!.positions.firstOrNull;
    if (position != null && position.extentAfter < 800) unawaited(ref.read(browseProvider.notifier).loadMore());
  }

  @override
  void dispose() {
    _search.dispose();
    _scroll?.removeListener(_onScroll);
    _own?.dispose();
    _focus.dispose();
    super.dispose();
  }

  // ── pinch for density ──
  final _pointers = <int, Offset>{};
  double? _startSpan;

  double _span() {
    final p = _pointers.values.toList();
    return (p[0] - p[1]).distance;
  }

  void _pinch() {
    if (_pointers.length != 2) return;
    _startSpan ??= _span();
    final scale = _span() / _startSpan!;
    final controller = ref.read(browseProvider.notifier);
    final density = ref.read(browseProvider).density;
    final i = BrowseDensity.values.indexOf(density);
    // pinch in: grid → list; spread goes back; ends don't wrap
    final next = scale < 0.85 && i < BrowseDensity.values.length - 1
        ? BrowseDensity.values[i + 1]
        : scale > 1.18 && i > 0
        ? BrowseDensity.values[i - 1]
        : null;
    if (next != null) {
      controller.setDensity(next);
      unawaited(ref.read(hapticsProvider).play(Haptic.selection));
      _startSpan = _span();
    }
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(browseProvider);
    final mode = ref.watch(modeProvider);
    final isAnime = mode.isAnime;
    final chips = activeFilters(view.state, isAnime: isAnime);
    final heading = browseTitle(view.state, isAnime: isAnime);

    return Listener(
      onPointerDown: (e) => _pointers[e.pointer] = e.position,
      onPointerMove: (e) {
        _pointers[e.pointer] = e.position;
        _pinch();
      },
      onPointerUp: (e) {
        _pointers.remove(e.pointer);
        _startSpan = null;
      },
      onPointerCancel: (e) {
        _pointers.remove(e.pointer);
        _startSpan = null;
      },
      child: RefreshIndicator.adaptive(
        onRefresh: () {
          ref.read(anilistClientProvider).clearCache();
          return ref.read(browseProvider.notifier).retry();
        },
        child: CustomScrollView(
          controller: _scroll,
          primary: false,
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverAppBar(
              floating: true,
              snap: true,
              automaticallyImplyLeading: false,
              primary: false,
              toolbarHeight: 60,
              backgroundColor: Surface.base,
              surfaceTintColor: Colors.transparent,
              titleSpacing: Space.gutter,
              title: _SearchField(
                controller: _search,
                focus: _focus,
                hint: isAnime ? 'Search anime' : 'Search manga',
                onChanged: ref.read(browseProvider.notifier).search,
              ),
            ),
            // ready-made lists, while not searching
            if (view.state.q.isEmpty)
              SliverToBoxAdapter(
                child: _Presets(
                  isAnime: isAnime,
                  active: activePreset(view.state, isAnime: isAnime),
                  onPick: (p) {
                    unawaited(ref.read(hapticsProvider).play(Haptic.selection));
                    ref.read(browseProvider.notifier).apply(p.state);
                  },
                ),
              ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _ChipsHeader(
                chips: chips,
                state: view.state,
                density: view.density,
                onFilters: () => showFilterSheet(context, ref),
                onRemove: (c) => ref.read(browseProvider.notifier).apply(c.without),
                onDensity: () {
                  final i = BrowseDensity.values.indexOf(view.density);
                  ref
                      .read(browseProvider.notifier)
                      .setDensity(BrowseDensity.values[(i + 1) % BrowseDensity.values.length]);
                },
                accent: context.mode,
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, Space.x3),
              sliver: SliverToBoxAdapter(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        heading ??
                            (view.state.q.isNotEmpty ? 'Results for “${view.state.q}”' : 'Browse ${nounFor(mode)}'),
                        style: AppType.section,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (view.total > 0)
                      Text(
                        '${formatMatchCount(view.total)} ${view.total == 1 ? 'title' : 'titles'}',
                        style: AppType.caption.copyWith(color: TextTone.low),
                      ),
                  ],
                ),
              ),
            ),
            ..._results(
              view,
              people: view.state.q.trim().isEmpty
                  ? null
                  : SliverToBoxAdapter(
                      child: SearchPeopleRows(q: view.state.q.trim(), isAnime: isAnime),
                    ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  /// While searching, the characters, staff and studios it matches ([people])
  /// come after the first two rows of titles, as on the web; the rest of the
  /// titles carry on below them. With fewer titles, or none, they follow
  /// whatever there is.
  List<Widget> _results(BrowseView view, {Widget? people}) {
    if (view.error != null && view.results.isEmpty) {
      return [
        SliverPadding(
          padding: const EdgeInsets.all(Space.gutter),
          sliver: SliverToBoxAdapter(
            child: SectionError(
              title: "Couldn't load results",
              error: view.error!,
              onRetry: ref.read(browseProvider.notifier).retry,
            ),
          ),
        ),
        ?people,
      ];
    }
    if (view.firstLoad) {
      return [_grid(view.density, itemCount: 6, builder: (_, _) => const _SkeletonCard()), ?people];
    }
    // titles swiped away as Not interested stay out (For You's too)
    final dismissed = ref.watch(dismissedPicksProvider);
    final results = [
      for (final t in view.results)
        if (!dismissed.contains(t.id)) t,
    ];
    if (view.results.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: _Empty(state: view.state, search: _search),
        ),
        ?people,
      ];
    }
    // ordered lists number their results: #1, #2… in AniList's order, so a
    // title hidden as Not interested doesn't renumber the rest
    final ranks = isRanked(view.state) ? {for (final (i, t) in view.results.indexed) t.id: i + 1} : const <int, int>{};
    Widget titles(List<Title> part) => view.density == BrowseDensity.list
        ? SliverList.builder(
            itemCount: part.length,
            itemBuilder: (context, i) => _ResultRow(key: ValueKey(part[i].id), title: part[i], rank: ranks[part[i].id]),
          )
        : _grid(
            view.density,
            itemCount: part.length,
            builder: (_, i) => switch (ranks[part[i].id]) {
              final rank? => Stack(
                children: [
                  PosterCard(title: part[i]),
                  Positioned(
                    top: 6,
                    left: 6,
                    child: IgnorePointer(child: _RankBadge(rank: rank)),
                  ),
                ],
              ),
              null => PosterCard(title: part[i]),
            },
          );
    // two rows of three covers, or four list rows (a phone's four, as on the web)
    final peopleAfter = people == null ? results.length : (view.density == BrowseDensity.list ? 4 : 6);
    return [
      titles(results.take(peopleAfter).toList()),
      if (people != null) ...[people, if (results.length > peopleAfter) titles(results.skip(peopleAfter).toList())],
      if (view.loading)
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(Space.x6),
            child: Center(child: CircularProgressIndicator.adaptive()),
          ),
        )
      else if (view.error != null)
        SliverToBoxAdapter(
          child: Center(
            child: TextButton(onPressed: ref.read(browseProvider.notifier).loadMore, child: const Text('Load more')),
          ),
        ),
    ];
  }

  Widget _grid(BrowseDensity density, {required int itemCount, required NullableIndexedWidgetBuilder builder}) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
      sliver: SliverGrid(
        gridDelegate: CoverGridDelegate.of(context, below: posterCardBelow),
        delegate: SliverChildBuilderDelegate(builder, childCount: itemCount),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focus, required this.hint, required this.onChanged});

  final TextEditingController controller;
  final FocusNode focus;
  final String hint;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      focusNode: focus,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      style: AppType.body.copyWith(fontSize: 15),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppType.body.copyWith(fontSize: 15, color: TextTone.low),
        prefixIcon: const Icon(Symbols.search_rounded, size: 20, color: TextTone.low),
        suffixIcon: ListenableBuilder(
          listenable: controller,
          builder: (context, _) => controller.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Symbols.close_rounded, size: 18, color: TextTone.mid),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        ),
        filled: false,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 12),
        border: UnderlineInputBorder(borderSide: const BorderSide(color: Surface.line)),
        enabledBorder: UnderlineInputBorder(borderSide: const BorderSide(color: Surface.line)),
        focusedBorder: UnderlineInputBorder(borderSide: const BorderSide(color: TextTone.high, width: 2)),
      ),
    );
  }
}

class _ChipsHeader extends SliverPersistentHeaderDelegate {
  _ChipsHeader({
    required this.chips,
    required this.state,
    required this.density,
    required this.onFilters,
    required this.onRemove,
    required this.onDensity,
    required this.accent,
  });

  final List<FilterChipSpec> chips;
  final BrowseState state;
  final BrowseDensity density;
  final VoidCallback onFilters;
  final ValueChanged<FilterChipSpec> onRemove;
  final VoidCallback onDensity;
  final ModeColors accent;

  static const height = 52.0;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    // like My List: the button shows the view it switches to
    final toList = density == BrowseDensity.three;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          color: const Color(0xE613110F),
          child: Row(
            children: [
              Expanded(
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(left: Space.gutter, right: Space.x2),
                  children: [
                    Center(
                      child: ActionChip(
                        avatar: Icon(
                          Symbols.tune_rounded,
                          size: 18,
                          color: chips.isEmpty ? TextTone.high : Surface.base,
                        ),
                        label: Text(chips.isEmpty ? 'Filters' : 'Filters · ${chips.length}'),
                        onPressed: onFilters,
                        labelStyle: AppType.body.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: chips.isEmpty ? TextTone.high : Surface.base,
                        ),
                        backgroundColor: chips.isEmpty ? Colors.transparent : TextTone.high,
                        side: BorderSide(color: chips.isEmpty ? Surface.line : Colors.transparent),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
                      ),
                    ),
                    const SizedBox(width: Space.x2),
                    Center(
                      child: ActionChip(
                        avatar: const Icon(Symbols.sort_rounded, size: 18, color: TextTone.mid),
                        label: Text(state.sort.label),
                        onPressed: onFilters,
                        labelStyle: AppType.body.copyWith(fontSize: 13, color: TextTone.high),
                        backgroundColor: Colors.transparent,
                        side: const BorderSide(color: Surface.line),
                        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
                      ),
                    ),
                    for (final c in chips) ...[
                      const SizedBox(width: Space.x2),
                      Center(
                        child: InputChip(
                          label: Text(c.label),
                          onDeleted: () => onRemove(c),
                          onPressed: () => onRemove(c),
                          deleteIcon: const Icon(Symbols.close_rounded, size: 16),
                          deleteIconColor: TextTone.mid,
                          deleteButtonTooltipMessage: 'Remove ${c.label}',
                          labelStyle: AppType.body.copyWith(fontSize: 13, color: TextTone.high),
                          backgroundColor: Colors.transparent,
                          side: const BorderSide(color: Surface.line),
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                tooltip: toList ? 'Show as list' : 'Show as grid',
                onPressed: onDensity,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  side: const BorderSide(color: Surface.line),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(Corner.sm)),
                ),
                icon: Icon(
                  toList ? Symbols.view_list_rounded : Symbols.grid_view_rounded,
                  size: 20,
                  color: TextTone.high,
                ),
              ),
              const SizedBox(width: Space.x3),
            ],
          ),
        ),
      ),
    );
  }

  @override
  bool shouldRebuild(_ChipsHeader old) =>
      old.chips.length != chips.length ||
      old.state != state ||
      old.density != density ||
      old.accent != accent ||
      !_sameChips(old.chips, chips);

  bool _sameChips(List<FilterChipSpec> a, List<FilterChipSpec> b) {
    for (var i = 0; i < a.length; i++) {
      if (a[i].key != b[i].key) return false;
    }
    return true;
  }
}

/// The compact list: a thumbnail, the facts, and a quick Plan button.
/// A row in the compact list (15). It follows the row grammar: right adds
/// to Planning (a title already on the list doesn't arm), left is Not
/// interested, hiding it from Browse and For You with Undo. Hold to peek.
class _ResultRow extends ConsumerWidget {
  const _ResultRow({super.key, required this.title, this.rank});

  final Title title;

  /// Its place in a ranked list.
  final int? rank;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entry = ref.watch(listStoreProvider.select((s) => s.entryFor(title)));
    final hidden = title.adult && !ref.watch(sessionProvider.select((s) => s.showAdultContent));

    void plan() {
      if (canEditList(context, ref)) {
        unawaited(ref.read(listActionsProvider).changeStatus(title, MediaListStatus.planning));
      }
    }

    void notInterested() {
      final dismissed = ref.read(dismissedPicksProvider.notifier)..add(title.id);
      unawaited(ref.read(hapticsProvider).play(Haptic.light));
      ref
          .read(toastProvider.notifier)
          .show('Hidden from Browse and For You', action: ToastAction('Undo', () => dismissed.remove(title.id)));
    }

    return RowSwipe(
      borderRadius: 0,
      onPositive: entry == null ? plan : null,
      positiveLabel: 'Planning',
      positiveIcon: Symbols.bookmark_add_rounded,
      onNegative: notInterested,
      negativeLabel: 'Not interested',
      negativeIcon: Symbols.visibility_off_rounded,
      child: _rowBody(context, ref, entry, hidden, plan),
    );
  }

  Widget _rowBody(BuildContext context, WidgetRef ref, ListEntry? entry, bool hidden, VoidCallback plan) {
    return InkWell(
      onTap: () => context.push('/title/${title.id}'),
      onLongPress: hidden
          ? null
          : () {
              unawaited(ref.read(hapticsProvider).play(Haptic.medium));
              unawaited(showPeek(context, title));
            },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: Space.gutter),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Surface.line)),
        ),
        child: Row(
          children: [
            if (rank != null)
              SizedBox(
                width: 32,
                child: Text(
                  '$rank',
                  style: AppType.numeric.copyWith(fontSize: 13, color: TextTone.low, fontWeight: FontWeight.w600),
                ),
              ),
            SizedBox(
              width: 52,
              height: 78,
              child: hidden
                  ? Container(
                      decoration: BoxDecoration(color: Surface.s2, borderRadius: BorderRadius.circular(2)),
                      child: const Icon(Symbols.visibility_off_rounded, size: 18, color: TextTone.low),
                    )
                  : CoverImage(title: title, thumb: true, radius: 6, showMissing: false),
            ),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hidden ? 'Hidden title' : title.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(color: TextTone.low),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (title.score > 0) ...[
                        const Icon(Symbols.star_rounded, size: 14, fill: 1, color: Accent.gold),
                        const SizedBox(width: 3),
                        Text(title.score.toStringAsFixed(1), style: AppType.numeric.copyWith(fontSize: 12)),
                        const SizedBox(width: Space.x3),
                      ],
                      if (entry != null) ...[
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(color: statusColor[entry.status], shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          statusLabel(entry.status, isAnime: title.isAnime),
                          style: AppType.caption.copyWith(
                            color: statusColor[entry.status],
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            if (entry == null)
              IconButton(
                tooltip: 'Plan to ${title.isAnime ? 'watch' : 'read'}',
                icon: const Icon(Symbols.bookmark_add_rounded, size: 22, color: TextTone.high),
                onPressed: plan,
              ),
          ],
        ),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return const Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AspectRatio(aspectRatio: 2 / 3, child: Skeleton()),
        SizedBox(height: 10),
        Skeleton(width: 120, height: 14, radius: 4),
        SizedBox(height: 6),
        Skeleton(width: 80, height: 12, radius: 4),
      ],
    );
  }
}

class _Empty extends ConsumerWidget {
  const _Empty({required this.state, required this.search});

  final BrowseState state;
  final TextEditingController search;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(browseProvider.notifier);
    final isAnime = ref.watch(modeProvider).isAnime;
    final q = state.q.trim();
    final suggestion = q.isEmpty ? null : ref.watch(didYouMeanProvider(q)).value;
    final filters = state.hasFilters ? activeFilters(state, isAnime: isAnime).length : 0;
    final mode = context.mode;

    void searchFor(String text) {
      search.text = text;
      controller.apply(state.copyWith(q: text));
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.x6, Space.x10, Space.x6, 0),
      child: Column(
        children: [
          const Icon(Symbols.search_off_rounded, size: 40, color: TextTone.low),
          const SizedBox(height: Space.x3),
          Text(q.isEmpty ? 'No matches' : 'Nothing for “$q”', textAlign: TextAlign.center, style: AppType.section),
          const SizedBox(height: Space.x2),
          if (suggestion != null)
            Semantics(
              button: true,
              label: 'Did you mean $suggestion?',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () => searchFor(suggestion),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Did you mean '),
                      TextSpan(
                        text: suggestion,
                        style: TextStyle(color: mode.accentText, fontWeight: FontWeight.w600),
                      ),
                      const TextSpan(text: '?'),
                    ],
                  ),
                  textAlign: TextAlign.center,
                  style: AppType.body.copyWith(fontSize: 16, color: TextTone.high),
                ),
              ),
            ),
          if (filters > 0) ...[
            const SizedBox(height: Space.x1),
            Text(
              q.isEmpty
                  ? 'Nothing matches these filters.'
                  : 'You also have $filters ${filters == 1 ? 'filter' : 'filters'} on.',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: TextTone.mid),
            ),
          ] else if (suggestion == null)
            Text(
              'Nothing on AniList matches that. Try another spelling.',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: TextTone.mid),
            ),
          const SizedBox(height: Space.x4),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: Space.x2,
            runSpacing: Space.x2,
            children: [
              if (filters > 0)
                OutlinedButton(
                  onPressed: () => controller.apply(state.withoutFilters()),
                  child: const Text('Clear filters'),
                ),
              if (suggestion != null)
                FilledButton.icon(
                  onPressed: () => searchFor(suggestion),
                  style: FilledButton.styleFrom(backgroundColor: TextTone.high, foregroundColor: mode.onAccent),
                  icon: const Icon(Symbols.search_rounded, size: 18),
                  label: Text('Search “$suggestion”'),
                )
              else if (filters == 0 && q.isNotEmpty)
                OutlinedButton(
                  onPressed: () {
                    search.clear();
                    controller.apply(state.copyWith(q: ''));
                  },
                  child: const Text('Clear search'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// "#3" on a cover in a ranked list.
class _RankBadge extends StatelessWidget {
  const _RankBadge({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Rank $rank',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(color: const Color(0xB3000000), borderRadius: BorderRadius.circular(2)),
        child: Text(
          '#$rank',
          style: AppType.numeric.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: TextTone.high),
        ),
      ),
    );
  }
}

/// Ready-made lists under the search box: All-time popular, Trending, Top
/// rated, Airing now (Releasing for manga) and Upcoming.
class _Presets extends StatelessWidget {
  const _Presets({required this.isAnime, required this.active, required this.onPick});

  final bool isAnime;
  final String? active;
  final ValueChanged<BrowsePreset> onPick;

  @override
  Widget build(BuildContext context) {
    final mode = context.mode;
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: 4),
        itemCount: browsePresets(isAnime: isAnime).length,
        separatorBuilder: (_, _) => const SizedBox(width: Space.x2),
        itemBuilder: (_, i) {
          final p = browsePresets(isAnime: isAnime)[i];
          final on = p.key == active;
          return ChoiceChip(
            label: Text(p.label),
            selected: on,
            onSelected: (_) => onPick(p),
            showCheckmark: false,
            labelStyle: AppType.body.copyWith(
              fontSize: 13,
              color: on ? mode.onAccent : TextTone.high,
              fontWeight: on ? FontWeight.w600 : FontWeight.w400,
            ),
            selectedColor: TextTone.high,
            backgroundColor: Colors.transparent,
            side: BorderSide(color: on ? Colors.transparent : Surface.line),
            shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
          );
        },
      ),
    );
  }
}
