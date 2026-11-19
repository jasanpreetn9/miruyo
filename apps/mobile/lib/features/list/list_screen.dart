import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/errors.dart';
import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/status.dart';
import '../../core/gestures/haptics.dart';
import '../../core/list/list_actions.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/clock.dart';
import '../../widgets/cover_grid.dart';
import '../../widgets/offline_note.dart';
import '../../widgets/section_error.dart';
import '../../widgets/skeleton.dart';
import 'carry_overlay.dart';
import 'list_data.dart';
import 'list_edit.dart';
import 'list_grid_card.dart';
import 'list_row.dart';

/// My List (05, 21): status tabs with counts, filter and sort, and the
/// list or a grid (one choice for every tab). Rows edit in place: +1, the
/// row swipes, quick actions. Edit selects several entries to carry to a
/// status, move or remove; on Planning it also orders Up next.
class MyListScreen extends ConsumerStatefulWidget {
  const MyListScreen({super.key, this.tab, this.list, this.sort});

  /// From a link (/list?tab=COMPLETED&sort=score): the tab to open on.
  final MediaListStatus? tab;

  /// From a link (/list?list=Rewatch): the custom list to open on.
  final String? list;
  final ListSort? sort;

  @override
  ConsumerState<MyListScreen> createState() => _MyListScreenState();
}

class _MyListScreenState extends ConsumerState<MyListScreen> with SingleTickerProviderStateMixin {
  late var _tab = widget.tab ?? MediaListStatus.current;

  /// The custom list open, by name, or null on a status tab.
  late String? _list = widget.list;
  late ListSort? _sort = widget.sort;

  @override
  void didUpdateWidget(MyListScreen old) {
    super.didUpdateWidget(old);
    // a new link while the tab is already open
    if ((widget.tab != null || widget.list != null) &&
        (widget.tab != old.tab || widget.list != old.list || widget.sort != old.sort)) {
      setState(() {
        _tab = widget.tab ?? _tab;
        _list = widget.list;
        _sort = widget.sort;
      });
      _edit.showTab(_tab);
    }
  }

  final _filter = TextEditingController();
  late bool _grid = ref.read(prefsProvider).getString(PrefKeys.listView) == 'grid';

  /// Each row's context on screen, for finding the row under a painting
  /// finger. Not GlobalKeys: a row being reordered is built twice.
  final _rowContexts = <int, BuildContext>{};

  /// The rows on screen, by id, for the gestures to act on.
  var _rows = <ListRow>[];

  // ── The coach mark (Gestures · Rows 11): taught once, on the top row ──
  late bool _coachSeen = ref.read(prefsProvider).getString(PrefKeys.rowsCoachSeen) != null;
  late final _coachLoop = AnimationController(vsync: this, duration: const Duration(milliseconds: 4800));

  /// My List's swipes: a short left is +1, right is −1; back to rest between.
  late final Animation<double> _coachDx = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(0), weight: 700),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: -96.0).chain(CurveTween(curve: Motion.enter)), weight: 350),
    TweenSequenceItem(tween: ConstantTween(-96), weight: 750),
    TweenSequenceItem(tween: Tween(begin: -96.0, end: 0.0).chain(CurveTween(curve: Motion.enter)), weight: 300),
    TweenSequenceItem(tween: ConstantTween(0), weight: 500),
    TweenSequenceItem(tween: Tween(begin: 0.0, end: 110.0).chain(CurveTween(curve: Motion.enter)), weight: 350),
    TweenSequenceItem(tween: ConstantTween(110), weight: 750),
    TweenSequenceItem(tween: Tween(begin: 110.0, end: 0.0).chain(CurveTween(curve: Motion.enter)), weight: 300),
    TweenSequenceItem(tween: ConstantTween(0), weight: 800),
  ]).animate(_coachLoop);

  void _coachDone() {
    _coachLoop.stop();
    unawaited(ref.read(prefsProvider).setString(PrefKeys.rowsCoachSeen, '1'));
    setState(() => _coachSeen = true);
  }

  @override
  void dispose() {
    _autoScroll?.cancel();
    _coachLoop.dispose();
    _filter.dispose();
    super.dispose();
  }

  ListEditController get _edit => ref.read(listEditProvider.notifier);

  void _haptic(Haptic h) => unawaited(ref.read(hapticsProvider).play(h));

  void _showTab(MediaListStatus tab) {
    if (tab == _tab && _list == null) return;
    setState(() {
      _tab = tab;
      _list = null;
      _sort = null;
    });
    _edit.showTab(tab);
  }

  void _showList(String name) {
    if (name == _list) return;
    _edit.stop();
    setState(() {
      _list = name;
      _sort = null;
    });
  }

  void _setGrid(bool grid) {
    setState(() => _grid = grid);
    unawaited(ref.read(prefsProvider).setString(PrefKeys.listView, grid ? 'grid' : 'list'));
  }

  Future<void> _refresh(Mode mode) async {
    // a pull waits for a new copy, rather than the one already showing
    ref.read(anilistClientProvider).clearViewerCache(lists: true);
    ref.invalidate(listCollectionProvider(mode));
    await ref.read(listCollectionProvider(mode).future).catchError((_) => const ListCollection(entries: []));
  }

  // ── Paint to select: the first circle decides select or deselect ──
  bool _paintValue = true;
  final _painted = <int>{};

  PaintCallbacks _paintFrom(ListRow row) => PaintCallbacks(
    start: () {
      _paintValue = !ref.read(listEditProvider).isSelected(row.id);
      _painted
        ..clear()
        ..add(row.id);
      _edit.set(row.title, _paintValue);
    },
    move: (position) {
      _paintAt = position;
      _paintUnder(position);
      _autoScroll ??= Timer.periodic(const Duration(milliseconds: 16), (_) => _scrollWhilePainting());
    },
    end: () {
      _painted.clear();
      _paintAt = null;
      _autoScroll?.cancel();
      _autoScroll = null;
    },
  );

  void _paintUnder(Offset position) {
    final under = _rowAt(position);
    if (under != null && _painted.add(under.id)) _edit.set(under.title, _paintValue);
  }

  // ── Painting near the top or bottom edge scrolls the list along ──
  Offset? _paintAt;
  Timer? _autoScroll;

  /// How close to an edge (px) the finger starts the list scrolling, and the
  /// fastest it goes (px per frame), reached at the edge itself.
  static const _edgeZone = 72.0;
  static const _edgeSpeed = 14.0;

  void _scrollWhilePainting() {
    final at = _paintAt;
    final controller = PrimaryScrollController.maybeOf(context);
    if (at == null || controller == null || !controller.hasClients) return;
    final position = controller.positions.first;
    final box = position.context.notificationContext?.findRenderObject();
    if (box is! RenderBox || !box.attached) return;
    final top = box.localToGlobal(Offset.zero).dy;
    // the edit bar covers the bottom of the list
    final bottom = math.min(top + box.size.height, MediaQuery.sizeOf(context).height) - 120;
    final double speed;
    if (at.dy < top + _edgeZone) {
      speed = -_edgeSpeed * ((top + _edgeZone - at.dy) / _edgeZone).clamp(0.0, 1.0);
    } else if (at.dy > bottom - _edgeZone) {
      speed = _edgeSpeed * ((at.dy - (bottom - _edgeZone)) / _edgeZone).clamp(0.0, 1.0);
    } else {
      return;
    }
    final next = (position.pixels + speed).clamp(position.minScrollExtent, position.maxScrollExtent);
    if (next == position.pixels) return;
    position.jumpTo(next);
    // the rows moved under a still finger: paint the one it's on now
    _paintUnder(at);
  }

  ListRow? _rowAt(Offset global) {
    for (final row in _rows) {
      final box = _rowContexts[row.id]?.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final local = box.globalToLocal(global);
      // rows span the full width, so only the vertical position matters
      if (local.dy >= 0 && local.dy < box.size.height) return row;
    }
    return null;
  }

  // ── Hold to carry the selection to a status ──
  CarryController? _carry;

  CarryCallbacks _carryFrom(ListRow row, {required bool isAnime}) => CarryCallbacks(
    start: (position) {
      _edit.set(row.title, true);
      _haptic(Haptic.medium);
      final edit = ref.read(listEditProvider);
      _carry = CarryController(
        context: context,
        titles: edit.selected.values.toList(),
        here: edit.tab,
        isAnime: isAnime,
        onEnter: () => _haptic(Haptic.selection),
      )..show(position);
      setState(() {});
    },
    move: (position) => _carry?.move(position),
    end: () {
      final target = _carry?.hot;
      _carry?.dismiss();
      setState(() => _carry = null);
      if (target != null) _edit.moveTo(target);
    },
    cancel: () {
      _carry?.dismiss();
      setState(() => _carry = null);
    },
  );

  // ── Up next ──
  void _reorder(List<ListRow> rows, int from, int to) {
    final order = [...rows];
    order.insert(to, order.removeAt(from));
    final changes = upNextPriorities(order, to);
    if (changes.isNotEmpty) unawaited(ref.read(listActionsProvider).reorderUpNext(changes));
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(modeProvider);
    final session = ref.watch(sessionProvider);
    final edit = ref.watch(listEditProvider);
    final live = ref.watch(listStoreProvider);
    // row notes count down in minutes, so a minute is fine-grained enough
    final minute = ref.watch(clockProvider.select((t) => (t.value ?? 0) ~/ 60));
    final now = minute > 0 ? minute * 60 : DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final collection = ref.watch(listCollectionProvider(mode));

    // a new mode is a different list: leave Edit
    ref.listen(modeProvider, (_, _) => _edit.stop());

    final customLists = [
      for (final l in collection.value?.custom ?? const <CustomList>[])
        (name: l.name, count: l.mediaIds.where((id) => !live.isRemoved(id)).length),
    ];
    final custom = collection.value?.custom.where((l) => l.name == _list).firstOrNull;
    // a custom list mixes statuses: the sorts that suit any of them
    final sortTab = custom != null ? MediaListStatus.completed : _tab;
    final view = collection.value == null
        ? null
        : buildListView(
            collection.value!.entries,
            tab: _tab,
            isAnime: mode.isAnime,
            now: now,
            live: live,
            only: custom?.mediaIds.toSet(),
            hidden: collection.value!.hidden,
            filter: _filter.text,
            sort: _sort ?? ListSort.defaultFor(sortTab),
            titles: session.titles,
            scoreFormat: session.scoreFormat,
          );
    _rows = view?.rows ?? const [];
    final sort = _sort ?? ListSort.defaultFor(sortTab);
    final canReorder =
        edit.editing &&
        custom == null &&
        _tab == MediaListStatus.planning &&
        sort == ListSort.upNext &&
        _filter.text.trim().isEmpty;

    return PopScope(
      canPop: !edit.editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _edit.stop();
      },
      child: RefreshIndicator.adaptive(
        // pull to refresh pauses in Edit, like the row swipes
        notificationPredicate: (n) => !edit.editing && n.depth == 0,
        onRefresh: () => _refresh(mode),
        child: CustomScrollView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          slivers: [
            SliverToBoxAdapter(
              child: _Header(
                heading: edit.editing
                    ? (edit.selected.isEmpty ? 'Select' : '${edit.selected.length} selected')
                    : 'My List',
                summary: edit.editing
                    ? (canReorder
                          ? 'Drag ⋮⋮ to set Up next · circles to select'
                          : 'Drag down the circles · hold a row to move')
                    : view?.summary,
                editing: edit.editing,
                // Edit moves titles between statuses; a custom list isn't one
                canEdit: view != null && view.rows.isNotEmpty && custom == null,
                onEdit: () {
                  _haptic(Haptic.light);
                  edit.editing ? _edit.stop() : _edit.start(_tab);
                },
              ),
            ),
            SliverPersistentHeader(
              pinned: true,
              delegate: _TabsHeader(
                // empty statuses are hidden, except the tab you're on
                tabs:
                    view?.tabs.where((t) => t.count > 0 || t.status == _tab).toList() ??
                    [
                      for (final s in listStatuses)
                        ListTab(
                          status: s,
                          label: statusLabel(s, isAnime: mode.isAnime),
                          count: -1,
                        ),
                    ],
                current: custom == null ? _tab : null,
                onSelect: _showTab,
                custom: customLists,
                currentList: custom?.name,
                onSelectList: _showList,
              ),
            ),
            if (!edit.editing)
              SliverToBoxAdapter(
                child: _Toolbar(
                  filter: _filter,
                  onFilter: (_) => setState(() {}),
                  sorts: ListSort.on(sortTab, isAnime: mode.isAnime),
                  sort: sort,
                  onSort: (s) => setState(() => _sort = s),
                  grid: _grid,
                  onGrid: _setGrid,
                ),
              ),
            if (collection.value?.savedAt case final savedAt?)
              SliverToBoxAdapter(
                child: OfflineNote(savedAt: savedAt, what: 'your list', onRetry: () => unawaited(_refresh(mode))),
              ),
            ..._body(view, collection, session, mode, edit: edit, canReorder: canReorder, grid: _grid && !edit.editing),
            const SliverToBoxAdapter(child: SizedBox(height: 120)),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(
    MyListView? view,
    AsyncValue<ListCollection> collection,
    SessionState session,
    Mode mode, {
    required ListEditState edit,
    required bool canReorder,
    required bool grid,
  }) {
    Widget padded(Widget child) => SliverPadding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
      sliver: SliverToBoxAdapter(child: child),
    );

    if (session.authState == AuthState.error) {
      return [
        padded(
          SectionError(
            title: "Couldn't check your AniList account",
            error: AniListError(
              session.loadError,
              session.rateLimited ? AniListErrorKind.rateLimit : AniListErrorKind.network,
              retryAfter: session.retryAt?.difference(DateTime.now()).inSeconds,
            ),
            onRetry: () => ref.read(sessionProvider.notifier).loadCurrentUser(),
          ),
        ),
      ];
    }
    if (view == null) {
      if (collection case AsyncError(:final error)) {
        return [
          padded(
            SectionError(
              title: "Couldn't load your list",
              error: error,
              onRetry: () => ref.invalidate(listCollectionProvider(mode)),
            ),
          ),
        ];
      }
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
          sliver: SliverList.separated(
            itemCount: 6,
            separatorBuilder: (_, _) => const SizedBox(height: Space.x2),
            itemBuilder: (_, _) => const Skeleton(height: listRowHeight, radius: Corner.md),
          ),
        ),
      ];
    }
    if (view.rows.isEmpty) {
      return [
        padded(
          _Empty(
            filtered: _filter.text.trim().isNotEmpty,
            label: view.tabs.firstWhere((t) => t.status == _tab).label,
            list: collection.value?.custom.where((l) => l.name == _list).firstOrNull?.name,
            tab: _tab,
            isAnime: mode.isAnime,
            onClear: () => setState(_filter.clear),
          ),
        ),
      ];
    }
    // taught once, on the first row or card, when there's one to show it on
    final coach = !_coachSeen && !edit.editing;
    final demo = coach && !MediaQuery.disableAnimationsOf(context);
    if (demo && !_coachLoop.isAnimating) {
      unawaited(_coachLoop.repeat());
    } else if (!demo && _coachLoop.isAnimating) {
      _coachLoop.stop();
    }

    if (grid) {
      return [
        if (coach)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
            sliver: SliverToBoxAdapter(
              child: _CoachMark(unit: mode.isAnime ? 'episode' : 'chapter', onDone: _coachDone),
            ),
          ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
          sliver: SliverGrid(
            // the 2:3 cover, the status bar, two title lines, the status and the note
            gridDelegate: CoverGridDelegate.of(context, below: 98),
            delegate: SliverChildBuilderDelegate(
              (_, i) => ListGridCard(
                key: ValueKey(view.rows[i].id),
                row: view.rows[i],
                demo: demo && i == 0 ? _coachDx : null,
              ),
              childCount: view.rows.length,
            ),
          ),
        ),
      ];
    }

    final rows = view.rows;
    Widget item(BuildContext context, int i) {
      final row = rows[i];
      return Padding(
        key: ValueKey(row.id),
        padding: const EdgeInsets.only(bottom: Space.x2),
        child: _RowProbe(
          id: row.id,
          contexts: _rowContexts,
          child: ListRowTile(
            row: row,
            editing: edit.editing,
            selected: edit.isSelected(row.id),
            dimmed: _carry != null && edit.isSelected(row.id),
            onToggle: () => _edit.toggle(row.title),
            onPaint: edit.editing ? _paintFrom(row) : null,
            carry: edit.editing ? _carryFrom(row, isAnime: mode.isAnime) : null,
            handle: canReorder ? _Handle(index: i, onSlot: () => _haptic(Haptic.selection)) : null,
            demo: demo && i == 0 ? _coachDx : null,
          ),
        ),
      );
    }

    return [
      if (coach)
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
          sliver: SliverToBoxAdapter(
            child: _CoachMark(unit: mode.isAnime ? 'episode' : 'chapter', onDone: _coachDone),
          ),
        ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
        sliver: SliverReorderableList(
          itemCount: rows.length,
          itemExtent: listRowExtent,
          itemBuilder: item,
          onReorderStart: (_) => _haptic(Haptic.medium),
          onReorderItem: (from, to) => _reorder(rows, from, to),
          proxyDecorator: (child, _, animation) => AnimatedBuilder(
            animation: animation,
            builder: (context, child) => Transform.scale(
              scale: 1 + 0.02 * Curves.easeOut.transform(animation.value),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(Corner.md),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0x8C000000),
                      blurRadius: 32 * animation.value,
                      offset: Offset(0, 16 * animation.value),
                    ),
                  ],
                ),
                child: child,
              ),
            ),
            child: child,
          ),
        ),
      ),
    ];
  }
}

/// Explains the rows' swipes while the top row demonstrates them. "Got it"
/// saves that it's been seen; the buttons and quick actions stay as the
/// other way in, so gestures are never the only one.
class _CoachMark extends StatelessWidget {
  const _CoachMark({required this.unit, required this.onDone});

  final String unit;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final mode = context.mode;
    Widget line(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: mode.accentText),
          const SizedBox(width: Space.x2),
          Expanded(child: Text(text, style: AppType.body)),
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(Space.x4, Space.x3, Space.x2, Space.x2),
      decoration: BoxDecoration(
        color: mode.tint,
        borderRadius: BorderRadius.circular(Corner.md),
        border: Border.all(color: mode.accent.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Rows move', style: AppType.title.copyWith(fontSize: 16)),
          line(Symbols.swipe_left_rounded, 'Swipe left to add one $unit'),
          line(Symbols.swipe_right_rounded, 'Swipe right for one less'),
          line(Symbols.touch_app_rounded, 'Hold, or swipe far left, for more'),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: onDone,
              style: TextButton.styleFrom(foregroundColor: mode.accentText),
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Registers its row's context while mounted (see _rowContexts).
class _RowProbe extends StatefulWidget {
  const _RowProbe({required this.id, required this.contexts, required this.child});

  final int id;
  final Map<int, BuildContext> contexts;
  final Widget child;

  @override
  State<_RowProbe> createState() => _RowProbeState();
}

class _RowProbeState extends State<_RowProbe> {
  @override
  void initState() {
    super.initState();
    widget.contexts.putIfAbsent(widget.id, () => context);
  }

  @override
  void dispose() {
    if (widget.contexts[widget.id] == context) widget.contexts.remove(widget.id);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _Header extends StatelessWidget {
  const _Header({
    required this.heading,
    required this.summary,
    required this.editing,
    required this.canEdit,
    required this.onEdit,
  });

  final String heading;
  final String? summary;
  final bool editing;
  final bool canEdit;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, Space.x2),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // a page title: large and light, as on the web
                Text(
                  heading,
                  style: AppType.displayL.copyWith(fontSize: 40),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  summary ?? ' ',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppType.caption.copyWith(color: TextTone.mid, fontWeight: FontWeight.w400),
                ),
              ],
            ),
          ),
          const SizedBox(width: Space.x3),
          TextButton(
            onPressed: editing || canEdit ? onEdit : null,
            style: TextButton.styleFrom(
              minimumSize: const Size(64, 36),
              backgroundColor: editing ? TextTone.high : Colors.transparent,
              side: editing ? null : const BorderSide(color: Surface.line),
              foregroundColor: editing ? Surface.base : TextTone.high,
              disabledForegroundColor: TextTone.low,
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
              textStyle: AppType.body.copyWith(fontWeight: FontWeight.w600),
            ),
            child: Text(editing ? 'Done' : 'Edit'),
          ),
        ],
      ),
    );
  }
}

class _TabsHeader extends SliverPersistentHeaderDelegate {
  _TabsHeader({
    required this.tabs,
    required this.current,
    required this.onSelect,
    this.custom = const [],
    this.currentList,
    this.onSelectList,
  });

  final List<ListTab> tabs;

  /// The status tab open, or null on a custom list.
  final MediaListStatus? current;
  final ValueChanged<MediaListStatus> onSelect;

  /// Your custom lists, after the statuses.
  final List<({String name, int count})> custom;
  final String? currentList;
  final ValueChanged<String>? onSelectList;

  static const height = 56.0;

  @override
  double get minExtent => height;

  @override
  double get maxExtent => height;

  @override
  bool shouldRebuild(_TabsHeader old) =>
      old.tabs != tabs || old.current != current || old.custom != custom || old.currentList != currentList;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlapsContent) {
    return ColoredBox(
      color: Surface.base,
      child: _TabRow(
        // the open tab, kept in view: a custom list, or Dropped, can start off-screen
        open: currentList ?? current?.name,
        children: [
          for (final t in tabs)
            _TabChip(
              key: ValueKey(t.status.name),
              label: t.label,
              count: t.count,
              on: t.status == current,
              onTap: () => onSelect(t.status),
            ),
          if (custom.isNotEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              child: VerticalDivider(width: 1, thickness: 1, color: Surface.line),
            ),
          for (final l in custom)
            _TabChip(
              key: ValueKey(l.name),
              label: l.name,
              count: l.count,
              icon: Symbols.bookmarks_rounded,
              on: l.name == currentList,
              onTap: () => onSelectList?.call(l.name),
            ),
        ],
      ),
    );
  }
}

/// The tab row, scrolling sideways, with the open tab kept in view.
class _TabRow extends StatefulWidget {
  const _TabRow({required this.open, required this.children});

  /// The open tab's key value.
  final String? open;
  final List<Widget> children;

  @override
  State<_TabRow> createState() => _TabRowState();
}

class _TabRowState extends State<_TabRow> {
  final _keys = <String, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _reveal();
  }

  @override
  void didUpdateWidget(_TabRow old) {
    super.didUpdateWidget(old);
    if (old.open != widget.open || old.children.length != widget.children.length) _reveal();
  }

  /// Scrolls the open tab in from whichever side it's past (CSS's "nearest").
  void _reveal() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final duration = MediaQuery.disableAnimationsOf(context) ? Duration.zero : Motion.press;
      for (final policy in [
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ]) {
        final open = _keys[widget.open]?.currentContext;
        if (open == null || !open.mounted) return;
        await Scrollable.ensureVisible(open, alignmentPolicy: policy, duration: duration);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: Space.gutter, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (i, child) in widget.children.indexed) ...[
            if (i > 0) const SizedBox(width: 6),
            if (child.key case ValueKey<String>(:final value))
              KeyedSubtree(key: _keys.putIfAbsent(value, GlobalKey.new), child: child)
            else
              child,
          ],
        ],
      ),
    );
  }
}

class _TabChip extends StatelessWidget {
  const _TabChip({
    super.key,
    required this.label,
    required this.count,
    required this.on,
    required this.onTap,
    this.icon,
  });

  final String label;

  /// -1 while the list loads.
  final int count;
  final bool on;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final color = on ? Surface.base : const Color(0xFFDDD3C3);
    return Semantics(
      selected: on,
      button: true,
      label: count < 0 ? label : '$label, $count',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.press,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: on ? TextTone.high : Colors.transparent,
            borderRadius: BorderRadius.circular(Corner.sm),
            border: Border.all(color: on ? TextTone.high : Surface.line),
          ),
          child: Row(
            children: [
              if (icon != null) ...[Icon(icon, size: 16, color: color), const SizedBox(width: 6)],
              Text(
                label,
                style: AppType.body.copyWith(color: color, fontWeight: on ? FontWeight.w600 : FontWeight.w500),
              ),
              if (count >= 0) ...[
                const SizedBox(width: 6),
                Text('$count', style: AppType.numeric.copyWith(fontSize: 12, color: color.withValues(alpha: 0.7))),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.filter,
    required this.onFilter,
    required this.sorts,
    required this.sort,
    required this.onSort,
    required this.grid,
    required this.onGrid,
  });

  final TextEditingController filter;
  final ValueChanged<String> onFilter;
  final List<ListSort> sorts;
  final ListSort sort;
  final ValueChanged<ListSort> onSort;
  final bool grid;
  final ValueChanged<bool> onGrid;

  @override
  Widget build(BuildContext context) {
    final border = UnderlineInputBorder(borderSide: const BorderSide(color: Surface.line));
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x2, Space.gutter, 0),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: Space.minTarget,
              child: TextField(
                controller: filter,
                onChanged: onFilter,
                textInputAction: TextInputAction.search,
                style: AppType.body,
                decoration: InputDecoration(
                  hintText: 'Filter…',
                  hintStyle: AppType.body.copyWith(color: TextTone.low),
                  prefixIcon: const Icon(Symbols.filter_list_rounded, size: 20, color: TextTone.low),
                  suffixIcon: ListenableBuilder(
                    listenable: filter,
                    builder: (context, _) => filter.text.isEmpty
                        ? const SizedBox.shrink()
                        : IconButton(
                            tooltip: 'Clear',
                            icon: const Icon(Symbols.close_rounded, size: 18, color: TextTone.mid),
                            onPressed: () {
                              filter.clear();
                              onFilter('');
                            },
                          ),
                  ),
                  filled: false,
                  isDense: true,
                  // centred on the rule's line now there's no box around it
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: border,
                  enabledBorder: border,
                  focusedBorder: border.copyWith(borderSide: const BorderSide(color: TextTone.high, width: 2)),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.x2),
          PopupMenuButton<ListSort>(
            tooltip: 'Sort',
            initialValue: sort,
            onSelected: onSort,
            color: Surface.s2,
            itemBuilder: (_) => [
              for (final s in sorts)
                CheckedPopupMenuItem(
                  value: s,
                  checked: s == sort,
                  child: Text(s.label, style: AppType.body),
                ),
            ],
            child: Container(
              height: Space.minTarget,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: Surface.line)),
              ),
              child: Row(
                children: [
                  const Icon(Symbols.sort_rounded, size: 18, color: TextTone.low),
                  const SizedBox(width: 6),
                  Text(sort.label, style: AppType.body.copyWith(fontSize: 13)),
                ],
              ),
            ),
          ),
          const SizedBox(width: Space.x2),
          Semantics(
            button: true,
            label: grid ? 'Show as list' : 'Show as grid',
            excludeSemantics: true,
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(Corner.sm),
                side: const BorderSide(color: Surface.line),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(Corner.sm),
                onTap: () => onGrid(!grid),
                child: SizedBox.square(
                  dimension: Space.minTarget,
                  child: Icon(
                    grid ? Symbols.view_list_rounded : Symbols.grid_view_rounded,
                    size: 20,
                    color: TextTone.high,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The Up next drag handle: 44px on the right, owns vertical drags. Ticks a
/// Selection haptic each time the row passes a slot.
class _Handle extends StatefulWidget {
  const _Handle({required this.index, required this.onSlot});

  final int index;
  final VoidCallback onSlot;

  @override
  State<_Handle> createState() => _HandleState();
}

class _HandleState extends State<_Handle> {
  double? _startY;
  var _slot = 0;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Reorder',
      child: Listener(
        onPointerDown: (e) {
          _startY = e.position.dy;
          _slot = 0;
        },
        onPointerMove: (e) {
          if (_startY == null) return;
          final slot = ((e.position.dy - _startY!) / listRowExtent).round();
          if (slot != _slot) {
            _slot = slot;
            widget.onSlot();
          }
        },
        onPointerUp: (_) => _startY = null,
        onPointerCancel: (_) => _startY = null,
        child: ReorderableDragStartListener(
          index: widget.index,
          child: const SizedBox.square(
            dimension: Space.minTarget,
            child: Icon(Symbols.drag_indicator_rounded, size: 24, color: TextTone.mid),
          ),
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.filtered,
    required this.label,
    required this.tab,
    required this.isAnime,
    required this.onClear,
    this.list,
  });

  final bool filtered;
  final String label;

  /// The custom list open, if any.
  final String? list;
  final MediaListStatus tab;
  final bool isAnime;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Space.x6, vertical: Space.x10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: Surface.line),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              border: Border.symmetric(horizontal: BorderSide(color: Surface.line)),
            ),
            child: const Icon(Symbols.inventory_2_rounded, size: 32, color: TextTone.low),
          ),
          const SizedBox(height: Space.x3),
          if (filtered) ...[
            Text(
              list == null ? 'No matches on this tab' : 'No matches on $list',
              style: AppType.section,
              textAlign: TextAlign.center,
            ),
            TextButton(onPressed: onClear, child: const Text('Clear filter')),
          ] else ...[
            Text(
              list == null ? 'Nothing ${label.toLowerCase()} yet' : 'Nothing on $list yet',
              style: AppType.section,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: Space.x2),
            Text(
              list != null
                  ? 'Titles you add to this list on AniList will appear here.'
                  : tab == MediaListStatus.dropped
                  ? 'Either great taste or great patience. Titles you drop will show up here.'
                  : 'When you move a title here it will appear in this tab.',
              textAlign: TextAlign.center,
              style: AppType.body.copyWith(color: TextTone.mid),
            ),
            const SizedBox(height: Space.x4),
            OutlinedButton(
              onPressed: () => context.go(isAnime ? '/seasonal' : '/browse'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(0, Space.minTarget),
                foregroundColor: TextTone.high,
                backgroundColor: Surface.s3,
                side: const BorderSide(color: Surface.line),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
              ),
              child: Text(isAnime ? 'Browse seasonal' : 'Browse manga'),
            ),
          ],
        ],
      ),
    );
  }
}
