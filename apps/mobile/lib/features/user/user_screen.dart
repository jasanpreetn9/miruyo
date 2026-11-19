// Someone's page (/user/:name), ported from apps/web/src/routes/user/[name]:
// your profile is your own user page (the Profile tab), and everyone else's
// opens from a follow notification. Laid out like the staff and character
// pages: the avatar, Follow or Settings with Share, the bio and a facts card,
// then AniList's tabs: Overview, Anime list and Manga list (someone else's,
// read-only; yours is My List), Favourites and Stats.

import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/client.dart' show isPrivateUser;
import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/status.dart';
import '../../core/gestures/haptics.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/clock.dart';
import '../../core/ui/toast.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/section_error.dart';
import '../list/list_data.dart';
import '../person/person_layout.dart';
import '../person/staff_screen.dart' show PersonSkeleton;
import '../profile/profile_data.dart';
import '../profile/profile_sections.dart';
import 'user_data.dart';

/// The Profile tab: your own user page.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(sessionProvider.select((s) => s.user?.name));
    // under the app's top bar, which already clears the status bar: the
    // page starts right below it
    return MediaQuery.removePadding(
      context: context,
      removeTop: true,
      child: name == null ? const PersonSkeleton() : UserScreen(name: name, tab: true),
    );
  }
}

enum _Tab {
  overview('Overview'),
  anime('Anime list'),
  manga('Manga list'),
  favourites('Favourites'),
  stats('Stats');

  const _Tab(this.label);
  final String label;
}

class UserScreen extends ConsumerStatefulWidget {
  const UserScreen({super.key, required this.name, this.tab = false});

  final String name;

  /// The Profile tab (no Back), rather than a pushed page.
  final bool tab;

  @override
  ConsumerState<UserScreen> createState() => _UserScreenState();
}

class _UserScreenState extends ConsumerState<UserScreen> {
  var _tab = _Tab.overview;
  var _range = StatsRange.all;

  /// Follow, as toggled here; otherwise what AniList says.
  bool? _following;
  bool _followBusy = false;

  Future<void> _refresh(int id, Mode mode, {required bool own}) async {
    // a pull waits for a new copy, rather than the one already showing
    ref.read(anilistClientProvider).clearViewerCache(lists: true);
    ref
      ..invalidate(userProfileProvider(widget.name))
      ..invalidate(activityProvider(id))
      ..invalidate(own ? listCollectionProvider(mode) : userListProvider((id: id, type: mode.mediaType)));
    await ref.read(userProfileProvider(widget.name).future).then((_) {}, onError: (_) {});
  }

  /// A list for Stats and the facts card: yours whole (My List's); anyone
  /// else's as anyone sees it.
  AsyncValue<List<CollectionEntry>> _list(int id, MediaType type, {required bool own}) => own
      ? ref.watch(listCollectionProvider(type == MediaType.anime ? Mode.anime : Mode.manga)).whenData((c) => c.entries)
      : ref.watch(userListProvider((id: id, type: type)));

  Future<void> _follow(int id, bool was) async {
    if (ref.read(sessionProvider).authState != AuthState.signedIn) {
      unawaited(context.push('/login'));
      return;
    }
    if (_followBusy) return;
    unawaited(ref.read(hapticsProvider).play(was ? Haptic.light : Haptic.success));
    setState(() {
      _followBusy = true;
      _following = !was;
    });
    try {
      final now = await ref.read(anilistClientProvider).toggleFollow(id);
      if (mounted) setState(() => _following = now);
    } on Exception {
      if (!mounted) return;
      setState(() => _following = was);
      ref.read(toastProvider.notifier).show("Couldn't update who you follow. Try again.", tone: ToastTone.error);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loaded = ref.watch(userProfileProvider(widget.name));
    final session = ref.watch(sessionProvider);
    final mode = ref.watch(modeProvider);

    final data = loaded.value;
    if (data == null) {
      return Scaffold(
        body: switch (loaded) {
          AsyncError(:final error) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(Space.gutter),
              child: SectionError(
                title: "Couldn't load this profile",
                error: error,
                onRetry: () => ref.invalidate(userProfileProvider(widget.name)),
              ),
            ),
          ),
          _ => const PersonSkeleton(),
        },
      );
    }

    final account = data.account;
    final id = (account['id'] as num).toInt();
    final name = account['name'] as String? ?? widget.name;
    final own = session.signedIn && isOwnProfile(name, session.user?.name);
    final adult = own || (session.signedIn && session.showAdultContent);
    final scoreFormat = own ? session.scoreFormat : ScoreFormat.point10Decimal;
    final profile = buildProfile(data, showAdult: adult);

    // the facts card shows the Stats cards' numbers, so the two never disagree
    final list = _list(id, mode.mediaType, own: own);
    final shown = list.whenData((e) => forViewer(e, adult: adult));
    final numbers = switch (shown) {
      // a reload (a newer copy of the list landed) keeps the numbers it has
      AsyncValue(:final value?) => [
        for (final c in buildStats(
          value,
          isAnime: mode.isAnime,
          range: StatsRange.all,
          now: DateTime.now(),
          scoreFormat: scoreFormat,
        ).cards)
          (label: c.label, value: c.value),
      ],
      _ => const <({String label, String value})>[],
    };
    final header = userHeader(account, own: own, memberSince: profile.memberSince, numbers: numbers);
    final following = _following ?? account['isFollowing'] == true;

    final tabs = [
      for (final t in _Tab.values)
        if (!own || (t != _Tab.anime && t != _Tab.manga)) t,
    ];
    final tab = tabs.contains(_tab) ? _tab : _Tab.overview;

    Widget stats({bool heading = true}) => StatsPanel(
      mode: mode,
      range: _range,
      onRange: (r) => setState(() => _range = r),
      entries: shown,
      userId: id,
      scoreFormat: scoreFormat,
      own: own,
      heading: heading,
      onRetry: () =>
          ref.invalidate(own ? listCollectionProvider(mode) : userListProvider((id: id, type: mode.mediaType))),
    );

    final page = PersonPage(
      header: header,
      kind: FavouriteKind.staff,
      id: id,
      sharePath: 'user/${Uri.encodeComponent(name)}',
      banner: account['bannerImage'] as String?,
      squarePortrait: true,
      back: !widget.tab,
      actions: own
          ? OutlinedButton.icon(
              onPressed: () => context.push('/settings'),
              style: _actionStyle(TextTone.high),
              icon: const Icon(Symbols.settings_rounded, size: 20),
              label: Text('Settings', style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
            )
          : Semantics(
              container: true,
              toggled: following,
              child: OutlinedButton.icon(
                onPressed: () => _follow(id, following),
                style: _actionStyle(following ? TextTone.mid : context.mode.accentText),
                icon: Icon(following ? Symbols.how_to_reg_rounded : Symbols.person_add_rounded, size: 20),
                label: Text(
                  following ? 'Following' : 'Follow',
                  style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
            ),
      sections: [
        const SizedBox(height: Space.x6),
        _TabRow(tabs: tabs, current: tab, onSelect: (t) => setState(() => _tab = t)),
        const SizedBox(height: Space.x5),
        if (tab == _Tab.anime || tab == _Tab.manga)
          _UserList(
            key: ValueKey(tab),
            name: name,
            list: _list(id, tab == _Tab.anime ? MediaType.anime : MediaType.manga, own: own),
            isAnime: tab == _Tab.anime,
            adult: adult,
            onRetry: () =>
                ref.invalidate(userListProvider((id: id, type: tab == _Tab.anime ? MediaType.anime : MediaType.manga))),
          ),
      ],
      // favourites and Stats pad themselves, as on Profile
      wide: switch (tab) {
        _Tab.overview => [
          FavouritesView(profile: profile, mode: mode, own: own),
          const SizedBox(height: Space.x8),
          stats(),
        ],
        _Tab.favourites => [FavouritesView(profile: profile, mode: mode, own: own, allModes: true)],
        _Tab.stats => [stats(heading: false)],
        _ => const [],
      },
    );

    return Scaffold(
      body: RefreshIndicator.adaptive(
        onRefresh: () => _refresh(id, mode, own: own),
        child: page,
      ),
    );
  }

  ButtonStyle _actionStyle(Color color) => OutlinedButton.styleFrom(
    minimumSize: const Size(double.infinity, Space.minTarget),
    backgroundColor: Colors.transparent,
    foregroundColor: color,
    side: const BorderSide(color: Surface.line),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
  );
}

class _TabRow extends StatelessWidget {
  const _TabRow({required this.tabs, required this.current, required this.onSelect});

  final List<_Tab> tabs;
  final _Tab current;
  final ValueChanged<_Tab> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [
          for (final t in tabs) ...[
            ChoiceChip(
              label: Text(t.label),
              selected: t == current,
              onSelected: (_) => onSelect(t),
              showCheckmark: false,
              labelStyle: AppType.body.copyWith(
                fontSize: 13,
                color: t == current ? Surface.base : TextTone.high,
                fontWeight: t == current ? FontWeight.w600 : FontWeight.w400,
              ),
              selectedColor: TextTone.high,
              backgroundColor: Surface.base,
              side: BorderSide(color: t == current ? TextTone.high : Surface.line),
              shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
            ),
            const SizedBox(width: Space.x2),
          ],
        ],
      ),
    );
  }
}

/// Someone else's Anime list or Manga list, read-only: My List's rows by
/// status, sortable, and filtered by AniList's Genre, Country and Year.
class _UserList extends ConsumerStatefulWidget {
  const _UserList({
    super.key,
    required this.name,
    required this.list,
    required this.isAnime,
    required this.adult,
    required this.onRetry,
  });

  final String name;
  final AsyncValue<List<CollectionEntry>> list;
  final bool isAnime;
  final bool adult;
  final VoidCallback onRetry;

  @override
  ConsumerState<_UserList> createState() => _UserListState();
}

class _UserListState extends ConsumerState<_UserList> {
  var _status = MediaListStatus.current;
  ListSort? _sort;
  String? _genre;
  String? _country;
  int? _year;

  bool get _narrowed => _genre != null || _country != null || _year != null;

  @override
  Widget build(BuildContext context) {
    final minute = ref.watch(clockProvider.select((t) => (t.value ?? 0) ~/ 60));
    final now = minute > 0 ? minute * 60 : DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final titles = ref.watch(sessionProvider.select((s) => s.titles));
    final empty = AppType.body.copyWith(color: TextTone.mid);
    return switch (widget.list) {
      AsyncError(:final error) when isPrivateUser(error) => Text(
        '${possessive(widget.name)} list is private.',
        style: empty,
      ),
      AsyncError(:final error) => SectionError(
        title: "Couldn't load ${possessive(widget.name)} list",
        error: error,
        onRetry: widget.onRetry,
      ),
      // a reload (a newer copy landed) keeps the rows it has
      AsyncValue(:final value?) => () {
        final sort = _sort ?? defaultUserSort(_status);
        final view = buildUserList(
          value,
          status: _status,
          isAnime: widget.isAnime,
          adult: widget.adult,
          now: now,
          sort: sort,
          genre: _genre ?? '',
          country: _country ?? '',
          year: _year,
          titles: titles,
        );
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                for (final t in view.tabs)
                  ChoiceChip(
                    label: Text('${t.label} ${t.count}'),
                    selected: t.status == _status,
                    onSelected: (_) => setState(() {
                      _status = t.status;
                      _sort = null;
                    }),
                    showCheckmark: false,
                    labelStyle: AppType.body.copyWith(
                      fontSize: 13,
                      color: t.status == _status ? Surface.base : TextTone.high,
                    ),
                    selectedColor: TextTone.high,
                    backgroundColor: Surface.base,
                    side: const BorderSide(color: Surface.line),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
                  ),
              ],
            ),
            const SizedBox(height: Space.x3),
            Row(
              children: [
                Expanded(
                  child: Text(view.summary, style: AppType.caption.copyWith(color: TextTone.mid)),
                ),
                PopupMenuButton<ListSort>(
                  tooltip: 'Sort',
                  initialValue: sort,
                  onSelected: (s) => setState(() => _sort = s),
                  itemBuilder: (_) => [
                    for (final s in userSortsFor(_status, isAnime: widget.isAnime))
                      CheckedPopupMenuItem(value: s, checked: s == sort, child: Text(s.label)),
                  ],
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: Space.minTarget),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Symbols.sort_rounded, size: 18, color: TextTone.low),
                        const SizedBox(width: 6),
                        Text(sort.label, style: AppType.body.copyWith(fontSize: 13)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // AniList's list filters; a pick stays an option on a status without it
            Row(
              children: [
                Expanded(
                  child: _FilterMenu<String>(
                    name: 'Genre',
                    value: _genre,
                    options: {...view.genres, ?_genre}.toList()..sort(),
                    onSelected: (v) => setState(() => _genre = v),
                  ),
                ),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: _FilterMenu<String>(
                    name: 'Country',
                    value: _country,
                    options: {...view.countries, ?_country}.toList()..sort(),
                    label: countryName,
                    onSelected: (v) => setState(() => _country = v),
                  ),
                ),
                const SizedBox(width: Space.x2),
                Expanded(
                  child: _FilterMenu<int>(
                    name: 'Year',
                    value: _year,
                    options: {...view.years, ?_year}.toList()..sort((a, b) => b.compareTo(a)),
                    onSelected: (v) => setState(() => _year = v),
                  ),
                ),
              ],
            ),
            if (view.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: Space.x4),
                child: Text(_narrowed ? 'Nothing matches.' : 'Nothing here yet.', style: empty),
              ),
            for (final r in view.rows) _UserRow(row: r, isAnime: widget.isAnime),
          ],
        );
      }(),
      _ => const Padding(
        padding: EdgeInsets.all(Space.x6),
        child: Center(child: CircularProgressIndicator.adaptive()),
      ),
    };
  }
}

/// One of the list's filters: its pick, or its [name] when it has none; the
/// menu's first item clears it.
class _FilterMenu<T extends Object> extends StatelessWidget {
  const _FilterMenu({
    required this.name,
    required this.value,
    required this.options,
    required this.onSelected,
    this.label,
  });

  final String name;
  final T? value;
  final List<T> options;
  final ValueChanged<T?> onSelected;
  final String Function(T)? label;

  String _text(T v) => label?.call(v) ?? '$v';

  @override
  Widget build(BuildContext context) {
    final picked = value;
    return PopupMenuButton<_Pick<T>>(
      tooltip: name,
      onSelected: (p) => onSelected(p.value),
      itemBuilder: (_) => [
        CheckedPopupMenuItem(value: _Pick<T>(null), checked: picked == null, child: Text('Any ${name.toLowerCase()}')),
        for (final o in options) CheckedPopupMenuItem(value: _Pick(o), checked: o == picked, child: Text(_text(o))),
      ],
      child: Container(
        constraints: const BoxConstraints(minHeight: Space.minTarget),
        padding: const EdgeInsets.only(left: Space.x3, right: Space.x2),
        decoration: BoxDecoration(
          color: picked == null ? Surface.s1 : TextTone.high,
          borderRadius: BorderRadius.circular(Corner.md),
          border: Border.all(color: picked == null ? Surface.line : TextTone.high),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                picked == null ? name : _text(picked),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppType.body.copyWith(fontSize: 13, color: picked == null ? TextTone.high : Surface.base),
              ),
            ),
            Icon(Symbols.expand_more_rounded, size: 18, color: picked == null ? TextTone.mid : Surface.base),
          ],
        ),
      ),
    );
  }
}

/// A menu pick, so "any" (null) can be one too.
class _Pick<T> {
  const _Pick(this.value);
  final T? value;
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.row, required this.isAnime});

  final ListRow row;
  final bool isAnime;

  @override
  Widget build(BuildContext context) {
    final t = row.title;
    return Semantics(
      container: true,
      button: true,
      label: [
        t.title,
        statusLabel(row.status, isAnime: isAnime),
        if (row.note.isNotEmpty) row.note,
        if (row.score > 0) 'scored ${row.score}',
      ].join(', '),
      excludeSemantics: true,
      child: InkWell(
        onTap: () => context.push('/title/${t.id}'),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Surface.line)),
          ),
          child: Row(
            children: [
              SizedBox(width: 44, height: 66, child: CoverImage(title: t, thumb: true, radius: 6, showMissing: false)),
              const SizedBox(width: Space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (row.note.isNotEmpty)
                      Text(
                        row.note,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppType.caption.copyWith(color: TextTone.low),
                      ),
                  ],
                ),
              ),
              if (row.score > 0) ...[
                const SizedBox(width: Space.x3),
                const Icon(Symbols.star_rounded, size: 14, fill: 1, color: Accent.gold),
                const SizedBox(width: 3),
                Text(
                  row.score.toStringAsFixed(row.score % 1 == 0 ? 0 : 1),
                  style: AppType.numeric.copyWith(fontSize: 13),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
