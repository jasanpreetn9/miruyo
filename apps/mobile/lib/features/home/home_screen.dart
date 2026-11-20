import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/errors.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/humanize.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/season.dart';
import '../../core/catalog/status.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';
import '../../core/storage/prefs.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/clock.dart';
import '../../core/ui/toast.dart';
import '../../widgets/motion.dart';
import '../../widgets/offline_note.dart';
import '../../widgets/poster_row.dart';
import '../../widgets/section_error.dart';
import '../../widgets/skeleton.dart';
import '../for_you/for_you_data.dart';
import '../onboarding/quick_pick.dart';
import '../onboarding/welcome_screen.dart' show quickPickChoices;
import 'continue_row.dart';
import 'hero_carousel.dart';
import 'home_data.dart';
import 'home_list.dart';
import 'home_masthead.dart';
import 'logged_out_hero.dart';
import 'upcoming_list.dart';

/// Home, editorial: finding what to
/// watch and tracking it. Signed out: the pitch, then the public rows.
/// Signed in: the masthead and Continue first (logging an episode is what
/// you open it for), then Picked for you, the For You rows, Trending,
/// Popular and Upcoming.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final mode = ref.watch(modeProvider);

    Future<void> refresh() async {
      ref.read(anilistClientProvider).clearCache();
      ref.invalidate(homeFeedProvider(mode));
      ref.invalidate(homeListProvider(mode));
      ref.invalidate(publicTrendingProvider(mode));
      await ref
          .read(homeFeedProvider(mode).future)
          .catchError(
            (_) => const FeedContent(
              trending: [],
              popularHeading: '',
              popularSubtitle: '',
              popular: [],
              upcomingHeading: '',
              upcoming: [],
            ),
          );
    }

    final children = switch (session.authState) {
      AuthState.loading => const [
        SizedBox(height: Space.x6),
        PosterRowSkeleton(),
        SizedBox(height: Space.x10),
        PosterRowSkeleton(),
      ],
      AuthState.error => [
        Padding(
          padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x10, Space.gutter, 0),
          child: SectionError(
            title: "Couldn't check your AniList account",
            error: AniListError(
              session.loadError,
              session.rateLimited ? AniListErrorKind.rateLimit : AniListErrorKind.network,
              retryAfter: session.retryAt?.difference(DateTime.now()).inSeconds,
            ),
            onRetry: () => ref.read(sessionProvider.notifier).loadCurrentUser(),
          ),
        ),
      ],
      AuthState.signedOut => [
        _OfflineBanner(mode: mode, signedIn: false, onRetry: refresh),
        const LoggedOutHero(),
        _FeedRows(mode: mode),
      ],
      AuthState.signedIn => [
        _OfflineBanner(mode: mode, signedIn: true, onRetry: refresh),
        // where you stand and what you're watching lead; then the pick and the rows
        _YourSection(mode: mode),
        const SizedBox(height: Space.x10),
        _PickedForYou(mode: mode),
        const SizedBox(height: Space.x10),
        _ForYouRow(mode: mode),
        _FeedRows(mode: mode, part: _FeedPart.trending),
        const SizedBox(height: Space.x10),
        _FeedRows(mode: mode, part: _FeedPart.rest),
      ],
    };

    return RefreshIndicator.adaptive(
      onRefresh: refresh,
      child: ListView(padding: const EdgeInsets.only(bottom: 120), children: children),
    );
  }
}

/// Which of the discovery rows to build: signed in, Trending sits at the
/// top of Home and the rest under For You; signed out, all of them together.
enum _FeedPart { all, trending, rest }

class _FeedRows extends ConsumerWidget {
  const _FeedRows({required this.mode, this.part = _FeedPart.all});

  final Mode mode;
  final _FeedPart part;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final feed = ref.watch(homeFeedProvider(mode));
    final store = ref.watch(listStoreProvider);
    final next = nextSeason(currentSeason());
    // the hero shows the season's most popular: the row would repeat it
    final heroes = ref.watch(sessionProvider).authState == AuthState.signedIn ? _heroes(ref, mode) : null;
    final heroIsPopular = heroes != null && heroes.isNotEmpty && !heroes.first.pick;

    final trending = part != _FeedPart.rest;
    final rest = part != _FeedPart.trending;
    // the rest wait quietly: the Trending part already shows loading and errors
    if (!trending && !feed.hasValue) return const SizedBox.shrink();

    return switch (feed) {
      AsyncData(:final value) when !rest => Appear(
        child: PosterRow(heading: 'Trending now', titles: value.trending, seeAll: '/browse?sort=trending'),
      ),
      AsyncData(:final value) => Appear(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (trending) ...[
              PosterRow(heading: 'Trending now', titles: value.trending, seeAll: '/browse?sort=trending'),
              const SizedBox(height: Space.x10),
            ],
            if (!heroIsPopular) ...[
              PosterRow(
                heading: value.popularHeading,
                subtitle: value.popularSubtitle,
                // what you're already watching is in Continue: not again here
                titles: [
                  for (final t in value.popular)
                    if (!switch (store.entryFor(t)?.status) {
                      final s? => isInProgress(s),
                      null => false,
                    })
                      t,
                ],
                countdown: true,
                seeAll: mode.isAnime ? '/seasonal' : '/browse?status=RELEASING',
              ),
              const SizedBox(height: Space.x10),
            ],
            UpcomingList(
              heading: value.upcomingHeading,
              items: value.upcoming,
              seeAll: mode.isAnime ? '/seasonal?season=${next.season.api}&year=${next.year}' : '/seasonal',
            ),
          ],
        ),
      ),
      // offline with nothing saved: the list still works, discovery waits (1j)
      AsyncError(:final error) when isAniListError(error, AniListErrorKind.network) || !ref.watch(isOnlineProvider) =>
        Padding(
          padding: const EdgeInsets.only(top: Space.x2),
          child: NeedsConnection(
            heading: 'Trending now',
            signedIn: ref.watch(sessionProvider).authState == AuthState.signedIn,
          ),
        ),
      AsyncError(:final error) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trending now', style: AppType.section),
            const SizedBox(height: 14),
            SectionError(
              title: "Couldn't load these rows",
              error: error,
              onRetry: () => ref.invalidate(homeFeedProvider(mode)),
            ),
          ],
        ),
      ),
      _ => Column(
        children: [
          const PosterRowSkeleton(),
          if (rest) ...[const SizedBox(height: Space.x10), const PosterRowSkeleton()],
        ],
      ),
    };
  }
}

/// The full offline banner (1j), once at the top of Home: when the device
/// is offline, or when what's shown is the device's copy because AniList
/// couldn't be reached.
class _OfflineBanner extends ConsumerWidget {
  const _OfflineBanner({required this.mode, required this.signedIn, required this.onRetry});

  final Mode mode;
  final bool signedIn;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listSaved = signedIn ? ref.watch(homeListProvider(mode)).value?.savedAt : null;
    final feedSaved = ref.watch(homeFeedProvider(mode)).value?.savedAt;
    final offline = !ref.watch(isOnlineProvider);
    if (listSaved == null && feedSaved == null && !offline) return const SizedBox.shrink();
    return OfflineNote(
      savedAt: listSaved ?? feedSaved,
      what: listSaved != null ? 'your list' : 'these',
      onRetry: () => unawaited(onRetry()),
    );
  }
}

/// Continue from one plan, re-planned as progress changes: a title
/// that's caught up moves to the waiting ones, an Up next you start joins
/// the rest.
class _Planned extends ConsumerWidget {
  const _Planned({required this.list});

  final HomeList list;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(listStoreProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final plan = planContinue(
      // titles taken off the list this visit drop out right away
      [
        for (final t in list.titles)
          if (!store.isRemoved(t.id)) t,
      ],
      upNext: [
        for (final t in list.upNext)
          if (!store.isRemoved(t.id)) t,
      ],
      entry: (t) => switch (store.entryFor(t)) {
        final e? => (status: e.status, progress: e.progress),
        null => null,
      },
      now: now,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        HomeMasthead(plan: plan, mode: ref.watch(modeProvider)),
        const SizedBox(height: Space.x8),
        ContinueSection(plan: plan),
      ],
    );
  }
}

/// Picked for you, at the top of Home: the hero's slides, or null while For
/// You is still answering (so the popular titles don't show, then swap for
/// picks). For You's picks first; with none, the season's most popular you
/// haven't added.
List<HeroPick>? _heroes(WidgetRef ref, Mode mode) {
  final forYou = ref.watch(forYouProvider(mode));
  if (!forYou.hasValue && !forYou.hasError) return null;
  final data = forYou.value;
  final picks = data == null || data.coldStart
      ? const <Pick>[]
      : visiblePicks(data, ref.watch(dismissedPicksProvider), ref.watch(mutedSeedsProvider), ref.watch(tuneProvider));
  final store = ref.watch(listStoreProvider);
  final season = currentSeason();
  final seasonName = '${humanizeSeason(season.season)} ${season.year}';
  return heroPicks(
    picks,
    ref.watch(homeFeedProvider(mode)).value?.popular ?? const [],
    season: seasonName,
    fallbackReason: mode.isAnime ? 'Popular in $seasonName' : 'Popular releasing',
    onList: (t) => store.entryFor(t) != null,
  );
}

/// The hero: what to watch next, and why. A placeholder the hero's
/// size while For You answers, so the page doesn't jump when it lands.
class _PickedForYou extends ConsumerWidget {
  const _PickedForYou({required this.mode});

  final Mode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // an empty list gets the quick-pick instead
    final list = ref.watch(homeListProvider(mode)).value;
    if (list != null && !list.hasAnyEntry && !_skipped(ref, mode)) return const SizedBox.shrink();
    final heroes = _heroes(ref, mode);
    if (heroes == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x5, Space.gutter, 0),
        child: Skeleton(height: HeroCarousel.cardHeight(context), radius: Corner.sm),
      );
    }
    if (heroes.isEmpty) return const SizedBox.shrink();
    final season = currentSeason();
    return Padding(
      padding: const EdgeInsets.only(top: Space.x5),
      child: Appear(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionHeading(
              heading: heroes.first.pick
                  ? 'Picked for you'
                  : 'Popular in ${humanizeSeason(season.season)} ${season.year}',
              jp: heroes.first.pick ? 'おすすめ' : '人気',
            ),
            const SizedBox(height: Space.x3),
            HeroCarousel(
              slides: heroes,
              onDismiss: (hero) {
                ref.read(dismissedPicksProvider.notifier).add(hero.title.id);
                ref
                    .read(toastProvider.notifier)
                    .show(
                      'Hid ${hero.title.title} from your picks',
                      action: ToastAction(
                        'Undo',
                        () => ref.read(dismissedPicksProvider.notifier).remove(hero.title.id),
                      ),
                    );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The quick-pick was skipped for this account and mode.
bool _skipped(WidgetRef ref, Mode mode) {
  ref.watch(_quickPickSkips);
  final userId = ref.read(sessionProvider).user?.id;
  return ref.read(prefsProvider).readSet(PrefKeys.quickPickSkipped).contains('$userId:${mode.name}');
}

/// Ticks when a quick-pick is skipped, so Home rebuilds.
final _quickPickSkips = NotifierProvider<_Tick, int>(_Tick.new);

class _Tick extends Notifier<int> {
  @override
  int build() => 0;

  void tick() => state++;
}

/// Home's empty-list card (1d): the quick-pick over popular titles, so the
/// list (and Continue, and For You) has something to start from.
class _EmptyListPick extends ConsumerStatefulWidget {
  const _EmptyListPick({required this.mode});

  final Mode mode;

  @override
  ConsumerState<_EmptyListPick> createState() => _EmptyListPickState();
}

class _EmptyListPickState extends ConsumerState<_EmptyListPick> {
  var _picked = <int>{};

  @override
  Widget build(BuildContext context) {
    final feed = ref.watch(homeFeedProvider(widget.mode)).value;
    final name = ref.watch(sessionProvider.select((s) => s.user?.name));
    if (feed == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.fromLTRB(Space.gutter, Space.x4, Space.gutter, 0),
      padding: const EdgeInsets.all(Space.x5),
      decoration: BoxDecoration(
        border: Border.symmetric(horizontal: BorderSide(color: Surface.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            name == null ? 'WELCOME' : 'WELCOME, ${name.toUpperCase()}',
            style: AppType.overline.copyWith(color: context.mode.accentText),
          ),
          const SizedBox(height: Space.x2),
          QuickPick(
            heading: 'Your ${widget.mode.isAnime ? 'anime' : 'manga'} list is empty. Seen any of these?',
            titles: quickPickChoices(feed),
            picked: _picked,
            onPicked: (p) => setState(() => _picked = p),
            onDone: () => ref.invalidate(homeListProvider(widget.mode)),
            onSkip: () {
              final userId = ref.read(sessionProvider).user?.id;
              unawaited(ref.read(prefsProvider).addToSet(PrefKeys.quickPickSkipped, '$userId:${widget.mode.name}'));
              ref.read(_quickPickSkips.notifier).tick();
            },
          ),
        ],
      ),
    );
  }
}

/// For You on Home: picks grouped by the title they come from, a row
/// for each of the top two ("Because you loved Cowboy Bebop"), rather than
/// the same reason under every poster. Only full rows (six or more), and
/// without what the hero already shows. Nothing while it loads, fails, or
/// before there are enough ratings: the page itself explains those.
class _ForYouRow extends ConsumerWidget {
  const _ForYouRow({required this.mode});

  final Mode mode;

  /// Posters per row.
  static const _row = 10;

  /// Fewer than this from one title, and it doesn't get a row.
  static const _full = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(forYouProvider(mode)).value;
    if (data == null || data.coldStart) return const SizedBox.shrink();
    final heroIds = {for (final h in _heroes(ref, mode) ?? const <HeroPick>[]) h.title.id};
    final picks = [
      for (final p in visiblePicks(
        data,
        ref.watch(dismissedPicksProvider),
        ref.watch(mutedSeedsProvider),
        ref.watch(tuneProvider),
      ))
        if (!heroIds.contains(p.title.id)) p,
    ];
    // by the seed that contributed most, in the order the picks rank
    final groups = <int, List<Pick>>{};
    for (final p in picks) {
      groups.putIfAbsent(p.because.id, () => []).add(p);
    }
    final top = groups.values.where((g) => g.length >= _full).take(2).toList();
    // too few per seed to group: one row, still without the repeated line
    final rows = top.isNotEmpty ? top : (picks.length >= _full ? [picks] : const <List<Pick>>[]);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, group) in rows.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.x10),
            child: PosterRow(
              heading: top.isEmpty ? 'For You' : 'Because you loved',
              em: top.isEmpty ? null : group.first.because.title.title,
              subtitle: top.isEmpty ? 'From titles you rated highly' : null,
              // the first row leads to the page with every pick
              seeAll: i == 0 ? '/for-you' : null,
              seeAllPushes: true,
              titles: [for (final p in group.take(_row)) p.title],
            ),
          ),
      ],
    );
  }
}

/// The signed-in viewer's own section: Continue, or a note when nothing is
/// in progress.
class _YourSection extends ConsumerWidget {
  const _YourSection({required this.mode});

  final Mode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (ref.watch(homeListProvider(mode))) {
      AsyncData(:final value) when value.titles.isNotEmpty || value.upNext.isNotEmpty => Appear(
        child: _Planned(list: value),
      ),
      // nothing on the list at all: the quick-pick, until it's skipped (1d)
      AsyncData(:final value) when !value.hasAnyEntry && !_skipped(ref, mode) => _EmptyListPick(mode: mode),
      AsyncData() => Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x6, Space.gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SectionHeading(heading: continueHeading(mode), padding: EdgeInsets.zero),
            const SizedBox(height: Space.x3),
            Container(
              padding: const EdgeInsets.symmetric(vertical: Space.x4),
              decoration: const BoxDecoration(
                border: Border.symmetric(horizontal: BorderSide(color: Surface.line)),
              ),
              child: Row(
                children: [
                  const Icon(Symbols.inventory_2_rounded, size: 22, color: TextTone.low),
                  const SizedBox(width: Space.x3),
                  Expanded(
                    child: Text(
                      mode.isAnime
                          ? "Nothing in progress. Start something from your Planning list, or find what's airing."
                          : 'Nothing in progress. Start something from your Planning list, or browse new releases.',
                      style: AppType.body.copyWith(color: TextTone.mid),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      AsyncError(:final error) => Padding(
        padding: const EdgeInsets.fromLTRB(Space.gutter, Space.x6, Space.gutter, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(continueHeading(mode), style: AppType.section),
            const SizedBox(height: 14),
            SectionError(
              title: "Couldn't load your list",
              error: error,
              onRetry: () => ref.invalidate(homeListProvider(mode)),
            ),
          ],
        ),
      ),
      _ => const Padding(
        padding: EdgeInsets.fromLTRB(Space.gutter, Space.x3, Space.gutter, 0),
        child: Skeleton(height: 460, radius: Corner.lg),
      ),
    };
  }
}
