import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/auth/session.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/list/list_entry.dart';
import 'package:miruyo/core/list/list_store.dart';
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/core/ui/clock.dart';
import 'package:miruyo/core/ui/toast.dart';
import 'package:miruyo/features/for_you/for_you_data.dart';
import 'package:miruyo/features/home/home_data.dart';
import 'package:miruyo/features/home/home_list.dart';
import 'package:miruyo/features/home/home_screen.dart';

import '../helpers.dart';
import 'continue_test.dart' show now, show;
import 'for_you_data_test.dart' show entry, media, rec;

/// Signed in, without touching the keychain or AniList.
class _SignedIn extends Session {
  @override
  SessionState build() => const SessionState(
    authState: AuthState.signedIn,
    user: AniListUser(id: 1, name: 'rin', scoreFormat: ScoreFormat.point10Decimal),
  );
}

void main() {
  final entries = [entry(media(1, 'Frieren'), score: 9.5)];
  final seeds = pickSeeds(entries, scoreFormat: ScoreFormat.point10Decimal);
  final picks = buildPicks(
    seeds,
    {
      1: [rec(media(10, 'Mushishi'), 40), rec(media(11, 'Monster'), 10)],
    },
    entries: entries,
    type: MediaType.anime,
    showAdult: false,
    scoreFormat: ScoreFormat.point10Decimal,
  );

  Future<ProviderContainer> pump(WidgetTester tester, {required ForYou forYou}) async {
    final container = await testContainer(
      overrides: [
        sessionProvider.overrideWith(_SignedIn.new),
        clockProvider.overrideWith((ref) => Stream.value(now)),
        homeListProvider.overrideWith((ref, mode) async => HomeList(titles: [show(5, nextEp: 9)], hasAnyEntry: true)),
        homeFeedProvider.overrideWith(
          (ref, mode) async => FeedContent(
            trending: [show(20)],
            popularHeading: 'Popular this season',
            popularSubtitle: 'Fall 2026',
            popular: [show(7), show(8)],
            upcomingHeading: 'Upcoming',
            upcoming: const [],
          ),
        ),
        forYouProvider.overrideWith((ref, mode) async => forYou),
      ],
    );
    container.read(listStoreProvider.notifier).sync = false;
    container.read(listStoreProvider.notifier).seed(const [
      ListEntry(id: 50, mediaId: 5, status: MediaListStatus.current, progress: 2),
    ]);
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: HomeScreen()),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(theme: buildTheme(Mode.anime), routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    return container;
  }

  Future<void> close(WidgetTester tester, ProviderContainer container) async {
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  testWidgets('Continue first, then a pick with its reason, then Trending; Not this hides it, with Undo', (
    tester,
  ) async {
    final container = await pump(
      tester,
      forYou: ForYou(coldStart: false, scored: 5, seeds: seeds, picks: picks),
    );
    // the masthead and Continue lead; the pick follows, then Trending
    final scroll = find.byType(Scrollable).first;
    expect(find.text('Continue watching'), findsOneWidget);
    final reason = find.text('BECAUSE YOU RATED FRIEREN 9.5/10');
    await tester.scrollUntilVisible(reason, 200, scrollable: scroll);
    expect(reason, findsOneWidget);
    final atPick = tester.state<ScrollableState>(scroll).position.pixels;
    expect(atPick, greaterThan(0));
    await tester.scrollUntilVisible(find.text('Trending now'), 200, scrollable: scroll);
    expect(tester.state<ScrollableState>(scroll).position.pixels, greaterThanOrEqualTo(atPick));
    await tester.scrollUntilVisible(reason, -200, scrollable: scroll);
    expect(find.text('Mushishi'), findsOneWidget);
    expect(find.text('Plan to watch'), findsOneWidget);
    // with picks, the popular row still shows
    expect(find.text('Popular this season'), findsOneWidget);
    // too few picks for a For You row
    expect(find.text('For You'), findsNothing);

    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();

    await tester.tap(find.byTooltip('Not this: hide Mushishi'));
    await tester.pumpAndSettle();
    expect(container.read(dismissedPicksProvider), contains(10));
    expect(find.text('Mushishi'), findsNothing);
    final toast = container.read(toastProvider).first;
    expect(toast.message, 'Hid Mushishi from your picks');
    toast.action!.run();
    await tester.pumpAndSettle();
    expect(find.text('Mushishi'), findsOneWidget);
    expect(container.read(dismissedPicksProvider), isNot(contains(10)));
    await close(tester, container);
  });

  testWidgets("no picks: the season's most popular, and its row steps aside", (tester) async {
    final container = await pump(
      tester,
      forYou: const ForYou(coldStart: true, scored: 1, seeds: [], picks: []),
    );
    expect(find.textContaining('Popular in '), findsOneWidget);
    expect(find.text('Show 7'), findsOneWidget);
    expect(find.text('Popular this season'), findsNothing);
    // not a For You pick: nothing to hide
    expect(find.byTooltip('Not this: hide Show 7'), findsNothing);
    await close(tester, container);
  });

  testWidgets('at the largest text (1.3×) on a narrow phone, the masthead and a four-digit lead still fit', (
    tester,
  ) async {
    final container = await testContainer(
      overrides: [
        sessionProvider.overrideWith(_SignedIn.new),
        clockProvider.overrideWith((ref) => Stream.value(now)),
        // a long-running show leads: four-digit counts in the counter and the totals
        homeListProvider.overrideWith(
          (ref, mode) async =>
              HomeList(titles: [show(5, nextEp: 1181, eps: 2000), show(6, nextEp: 9)], hasAnyEntry: true),
        ),
        homeFeedProvider.overrideWith(
          (ref, mode) async => FeedContent(
            trending: [show(20)],
            popularHeading: 'Popular this season',
            popularSubtitle: 'Fall 2026',
            popular: [show(7)],
            upcomingHeading: 'Upcoming',
            upcoming: const [],
          ),
        ),
        forYouProvider.overrideWith(
          (ref, mode) async => const ForYou(coldStart: true, scored: 1, seeds: [], picks: []),
        ),
      ],
    );
    container.read(listStoreProvider.notifier).sync = false;
    container.read(listStoreProvider.notifier).seed(const [
      ListEntry(id: 50, mediaId: 5, status: MediaListStatus.current, progress: 1155),
      ListEntry(id: 60, mediaId: 6, status: MediaListStatus.current, progress: 2),
    ]);
    await tester.binding.setSurfaceSize(const Size(375, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: HomeScreen()),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: buildTheme(Mode.anime),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('FURTHEST BEHIND'), findsOneWidget);
    expect(find.text('1155'), findsOneWidget);
    expect(find.text('1156'), findsOneWidget);
    expect(find.text('TO WATCH'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
