import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/catalog/cover_color.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/catalog/title.dart';
import 'package:miruyo/core/list/list_entry.dart';
import 'package:miruyo/core/list/list_store.dart';
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/core/ui/clock.dart';
import 'package:miruyo/features/for_you/for_you_data.dart';
import 'package:miruyo/features/home/continue_row.dart';
import 'package:miruyo/features/home/home_list.dart';

import '../helpers.dart';

const now = 1800000000;

Title show(
  int id, {
  int? nextEp,
  int inHours = 24,
  int eps = 12,
  String status = 'Releasing',
  int? duration,
  String? season,
}) => Title(
  id: id,
  title: 'Show $id',
  type: MediaType.anime,
  format: 'TV',
  eps: eps,
  score: 8,
  colors: CoverColors.fromHex(null),
  genres: const [],
  status: status,
  season: season,
  duration: duration,
  next: nextEp == null ? null : NextAiring(ep: nextEp, airingAt: now + inHours * 3600),
);

void main() {
  group('planContinue', () {
    ({MediaListStatus status, int progress})? Function(Title) entries(Map<int, (MediaListStatus, int)> m) =>
        (t) => switch (m[t.id]) {
          final e? => (status: e.$1, progress: e.$2),
          null => null,
        };

    test('new first (the most first), then airing soonest, Paused last', () {
      final titles = [
        show(1, nextEp: 5, inHours: 48), // caught up (4 out, 4 watched), airs in 2d
        show(2, nextEp: 9), // 3 new
        show(3, nextEp: 3, inHours: 2), // caught up, airs in 2h
        show(4, nextEp: 6), // 1 new, but Paused
        show(5, nextEp: 10), // 8 new
        show(6, status: 'Finished'), // 2 left of a finished show
      ];
      final plan = planContinue(
        titles,
        entry: entries({
          1: (MediaListStatus.current, 4),
          2: (MediaListStatus.current, 5),
          3: (MediaListStatus.current, 2),
          4: (MediaListStatus.paused, 4),
          5: (MediaListStatus.current, 1),
          6: (MediaListStatus.current, 10),
        }),
        now: now,
      );
      expect([...plan.ready, ...plan.waiting, ...plan.paused].map((t) => t.id), [5, 2, 6, 3, 1, 4]);
      expect(plan.caughtUp, isFalse);
      // Paused titles don't count as new
      expect((plan.newEpisodes, plan.airingThisWeek), (8 + 3 + 2, 4));
      expect(continueSummary(plan, isAnime: true), '13 new episodes · 4 airing this week');
    });

    test('nothing ready: the next to air is featured, as caught up', () {
      final plan = planContinue(
        [show(1, nextEp: 5, inHours: 48), show(2, nextEp: 3, inHours: 2)],
        entry: entries({1: (MediaListStatus.current, 4), 2: (MediaListStatus.current, 2)}),
        now: now,
      );
      expect(plan.caughtUp, isTrue);
      expect(plan.waiting.map((t) => t.id), [2, 1]);
      // the caught-up card says so; the summary doesn't repeat it
      expect(continueSummary(plan, isAnime: true), '2 airing this week');
    });

    test('Up next stays apart until started; completed titles leave', () {
      final plan = planContinue(
        [show(1, nextEp: 9), show(2, status: 'Finished')],
        upNext: [
          show(3, status: 'Finished'),
          show(4, status: 'Finished'),
          show(1, nextEp: 9),
        ],
        entry: entries({
          1: (MediaListStatus.current, 5),
          2: (MediaListStatus.completed, 12),
          3: (MediaListStatus.planning, 0),
          // started this visit: a +1 on Planning
          4: (MediaListStatus.current, 1),
        }),
        now: now,
      );
      expect(plan.ready.map((t) => t.id), [4, 1]);
      expect(plan.upNext.map((t) => t.id), [3]);
      // Up next isn't in progress: its episodes aren't "new"
      expect(plan.newEpisodes, 11 + 3);
    });

    test("Up next leaves out titles that aren't out yet, still showing four", () {
      Title plan(int id, [String status = 'Finished']) => show(id, status: status);
      final result = planContinue(
        const [],
        upNext: [
          plan(1, 'Not yet released'),
          plan(2),
          plan(3, 'Releasing'),
          plan(4, 'Not yet released'),
          plan(5),
          plan(6),
          plan(7),
        ],
        entry: (t) => (status: MediaListStatus.planning, progress: 0),
        now: now,
      );
      // in priority order, the unreleased skipped, and no more than four
      expect(result.upNext.map((t) => t.id), [2, 3, 5, 6]);
    });
  });

  group('heroPicks', () {
    Pick pick(Title t) => Pick(
      title: t,
      because: Seed(title: show(99), score: 9.5),
      seedIds: const [99],
      score: 1,
      votes: 10,
      sharedGenres: const [],
    );

    test("For You's picks, what airs this season first, with their reason", () {
      final heroes = heroPicks(
        [pick(show(1, status: 'Finished')), pick(show(2, season: 'Fall 2026')), pick(show(3, season: 'Fall 2026'))],
        [show(7)],
        season: 'Fall 2026',
        fallbackReason: 'Popular in Fall 2026',
        onList: (_) => false,
      );
      expect(heroes.map((h) => h.title.id), [2, 3, 1]);
      expect(heroes.first.reason, 'Because you rated Show 99 9.5/10');
      expect(heroes.every((h) => h.pick), isTrue);
    });

    test("no picks: the season's most popular you haven't added", () {
      final heroes = heroPicks(
        const [],
        [for (var i = 1; i <= 8; i++) show(i)],
        season: 'Fall 2026',
        fallbackReason: 'Popular in Fall 2026',
        onList: (t) => t.id == 2,
      );
      expect(heroes.map((h) => h.title.id), [1, 3, 4, 5, 6]);
      expect(heroes.first.reason, 'Popular in Fall 2026');
      expect(heroes.first.pick, isFalse);
    });
  });

  test('hoursMinutes', () {
    expect(hoursMinutes(384), '6h 24m');
    expect(hoursMinutes(120), '2h');
    expect(hoursMinutes(45), '45m');
  });

  test("lengthOf says how long a title is: episodes, or a movie's running time", () {
    expect(lengthOf(show(1)), '12 eps');
    expect(lengthOf(show(1, eps: 1)), '1 ep');
    expect(lengthOf(show(1, eps: 1, duration: 107)), '1h 47m');
    expect(lengthOf(show(1, eps: 0)), isNull);
  });

  testWidgets('rows say when, or how long; Up next says how long it is, and Start', (tester) async {
    final semantics = tester.ensureSemantics();
    final container = await testContainer(overrides: [clockProvider.overrideWith((ref) => Stream.value(now))]);
    container.read(listStoreProvider.notifier).sync = false;
    container.read(listStoreProvider.notifier).seed(const [
      ListEntry(id: 10, mediaId: 1, status: MediaListStatus.current, progress: 2),
      ListEntry(id: 20, mediaId: 2, status: MediaListStatus.current, progress: 4),
      ListEntry(id: 30, mediaId: 3, status: MediaListStatus.planning, progress: 0),
    ]);
    final titles = [show(1, nextEp: 4, inHours: 55), show(2, status: 'Finished', duration: 24)];
    final upNext = [show(3, status: 'Finished', season: 'Fall 2026')];
    final store = container.read(listStoreProvider);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ListView(
              children: [
                ContinueSection(
                  plan: planContinue(
                    titles,
                    upNext: upNext,
                    entry: (t) => (status: store.entryFor(t)!.status, progress: store.entryFor(t)!.progress),
                    now: now,
                  ),
                ),
              ],
            ),
          ),
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
    // aired 3, watched 2: one new, and when the next one airs; 8 left of the finished one
    expect(find.text('9 new episodes · 1 airing this week'), findsOneWidget);
    expect(find.text('EP 4 in 2d 7h'), findsOneWidget);
    // a finished show: the time left to finish it (8 × 24 min)
    expect(find.text('3h 12m left'), findsOneWidget);
    expect(find.text('UP NEXT'), findsOneWidget);
    expect(find.text('TV · Fall 2026'), findsOneWidget);
    // its length, not AniList's average (which read like your own score)
    expect(find.text('12 eps'), findsOneWidget);
    expect(find.text('★ 8.0'), findsNothing);
    // the button says Start, not ▶: miruyo plays nothing
    expect(find.text('Start'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Start Show 3')), findsOneWidget);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    container.dispose();
  });

  testWidgets('caught up: the countdown card leads, the rest wait with their countdowns', (tester) async {
    final semantics = tester.ensureSemantics();
    final container = await testContainer(overrides: [clockProvider.overrideWith((ref) => Stream.value(now))]);
    container.read(listStoreProvider.notifier).sync = false;
    container.read(listStoreProvider.notifier).seed(const [
      ListEntry(id: 10, mediaId: 1, status: MediaListStatus.current, progress: 4),
      ListEntry(id: 20, mediaId: 2, status: MediaListStatus.current, progress: 2),
    ]);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: ListView(
              children: [
                ContinueSection(
                  plan: planContinue(
                    [show(1, nextEp: 5, inHours: 48), show(2, nextEp: 3, inHours: 2)],
                    entry: (t) => (status: MediaListStatus.current, progress: t.id == 1 ? 4 : 2),
                    now: now,
                  ),
                ),
              ],
            ),
          ),
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
    expect(find.text("You're caught up."), findsOneWidget);
    expect(find.text('EP 3 in 2h 00m'), findsOneWidget);
    expect(find.text('Schedule'), findsOneWidget);
    expect(find.text('ALSO ON ITS WAY'), findsOneWidget);
    // Show 1 waits for EP 5: a countdown, and no +1 to tap
    expect(find.text('2d 0h'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Add one episode')), findsNothing);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 10));
    container.dispose();
  });
}
