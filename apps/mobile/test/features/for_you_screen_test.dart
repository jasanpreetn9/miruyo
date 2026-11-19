import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/auth/session.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/catalog/title.dart';
import 'package:miruyo/core/list/list_store.dart';
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/core/ui/toast.dart';
import 'package:miruyo/features/for_you/for_you_data.dart';
import 'package:miruyo/features/for_you/for_you_screen.dart';

import '../helpers.dart';
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
  late ProviderContainer container;

  final entries = [
    entry(media(1, 'Frieren', genres: ['Fantasy']), score: 9.5),
    entry(media(2, 'Apothecary', genres: ['Mystery']), score: 9),
    // a lower score, so Fantasy stands out from the list's mean ("Shares Fantasy")
    entry(media(3, 'Meh'), score: 5),
  ];
  final seeds = pickSeeds(entries, scoreFormat: ScoreFormat.point10Decimal);
  final picks = buildPicks(
    seeds,
    {
      1: [
        rec(media(10, 'Mushishi', genres: ['Fantasy']), 40),
        rec(media(11, 'Monster'), 10),
      ],
      2: [rec(media(12, 'Ping Pong'), 30)],
    },
    entries: entries,
    type: MediaType.anime,
    showAdult: false,
    scoreFormat: ScoreFormat.point10Decimal,
  );

  Future<void> pump(WidgetTester tester, {double textScale = 1}) async {
    container = await testContainer(
      overrides: [
        sessionProvider.overrideWith(_SignedIn.new),
        forYouProvider.overrideWith(
          (ref, mode) async => ForYou(coldStart: false, scored: 2, seeds: seeds, picks: picks),
        ),
      ],
    );
    container.read(listStoreProvider.notifier).sync = true;
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(Mode.anime),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
          home: const ForYouScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  Future<void> swipe(WidgetTester tester, Finder target, Offset by) async {
    final gesture = await tester.startGesture(tester.getCenter(target));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(by / 20);
      await tester.pump(const Duration(milliseconds: 40));
    }
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('at the largest text (1.3×), the picks still fit', (tester) async {
    await pump(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);
    expect(find.text('Mushishi'), findsWidgets);
  });

  testWidgets('picks show with their reasons, best first', (tester) async {
    await pump(tester);
    expect(find.text('Mushishi'), findsWidgets);
    expect(find.text('Because you rated Frieren 9.5/10'), findsNWidgets(2));
    expect(find.text('Because you rated Apothecary 9/10'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('Mushishi').last).dx,
      lessThan(tester.getTopLeft(find.text('Ping Pong').last).dx),
    );
    await close(tester);
  });

  testWidgets('swipe right adds to Planning; swipe left is Not this, with Undo', (tester) async {
    await pump(tester);
    await swipe(tester, find.text('Mushishi').last, const Offset(110, 0));
    expect(container.read(listStoreProvider)[10]?.status, MediaListStatus.planning);

    await swipe(tester, find.text('Monster').last, const Offset(-110, 0));
    expect(find.text('Monster'), findsNothing);
    expect(container.read(dismissedPicksProvider), {11});
    final toast = container.read(toastProvider).first;
    expect(toast.message, 'Hid Monster from your picks');
    toast.action!.run();
    await tester.pumpAndSettle();
    expect(find.text('Monster'), findsWidgets);
    await close(tester);
  });

  testWidgets('tap a seed to filter; swipe it up to stop using it', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.text('Apothecary'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Apothecary'));
    await tester.pumpAndSettle();
    expect(find.text('Ping Pong'), findsWidgets);
    expect(find.text('Mushishi'), findsNothing);
    expect(find.text('Picks because you rated Apothecary 9/10'), findsOneWidget);

    await swipe(tester, find.text('Apothecary'), const Offset(0, -70));
    expect(container.read(mutedSeedsProvider), {2});
    // its only pick leaves with it, and the filter clears
    expect(find.text('Ping Pong'), findsNothing);
    expect(find.text('Mushishi'), findsWidgets);
    await close(tester);
  });

  testWidgets('hold a pick to see why', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.text('Mushishi').last));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('WHY THIS PICK'), findsOneWidget);
    expect(find.text('You rated Frieren 9.5/10'), findsOneWidget);
    expect(find.textContaining('Shares Fantasy'), findsOneWidget);
    expect(find.textContaining('40 AniList users recommend it'), findsOneWidget);
    await close(tester);
  });

  testWidgets('fewer than five ratings: the cold start', (tester) async {
    container = await testContainer(
      overrides: [
        sessionProvider.overrideWith(_SignedIn.new),
        forYouProvider.overrideWith(
          (ref, mode) async => const ForYou(coldStart: true, scored: 2, seeds: [], picks: []),
        ),
      ],
    );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(Mode.anime), home: const ForYouScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Picks get good after 5 ratings'), findsOneWidget);
    expect(find.textContaining("You've rated 2 of 5"), findsOneWidget);
    await close(tester);
  });

  testWidgets('accessibility: labelled tap targets, 44pt targets, readable text', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  testWidgets(
    'Tune picks: leaving out a genre hides its picks, the sheet passes the a11y checks, Reset brings them back',
    (tester) async {
      final semantics = tester.ensureSemantics();
      await pump(tester);
      expect(find.text('Mushishi'), findsOneWidget);
      await tester.tap(find.byTooltip('Tune picks'));
      await tester.pumpAndSettle();
      expect(find.text('Only titles that are out'), findsOneWidget);
      expect(find.text('Anime of manga you loved'), findsOneWidget);

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      // every pick here is Fantasy or has no genre: leave Fantasy out
      await tester.tap(find.widgetWithText(FilterChip, 'Fantasy'));
      await tester.pumpAndSettle();
      expect(container.read(tuneProvider).hiddenGenres, ['Fantasy']);
      await tester.tapAt(const Offset(200, 40));
      await tester.pumpAndSettle();
      expect(find.text('Mushishi'), findsNothing);
      expect(find.text('Monster'), findsOneWidget);
      // the button says something's tuned
      expect(find.byTooltip('Tune picks (some left out)'), findsOneWidget);

      container.read(tuneProvider.notifier).reset();
      await tester.pumpAndSettle();
      expect(find.text('Mushishi'), findsOneWidget);
      semantics.dispose();
      await close(tester);
    },
  );

  testWidgets('a list with too few ratings shows the other list\'s picks, saying so', (tester) async {
    final anime = Seed(title: adaptMedia(AniListMedia.fromJson(media(1, 'Frieren'))), score: 9);
    final crossPicks = buildPicks(
      const [],
      const {},
      entries: const [],
      type: MediaType.manga,
      showAdult: false,
      crossSeeds: [anime],
      relations: {
        1: [(relationType: 'SOURCE', media: AniListMedia.fromJson(media(100, 'Frieren (manga)', type: 'MANGA')))],
      },
    );
    container = await testContainer(
      overrides: [
        sessionProvider.overrideWith(_SignedIn.new),
        forYouProvider.overrideWith(
          (ref, mode) async =>
              ForYou(coldStart: false, scored: 0, seeds: const [], crossSeeds: [anime], picks: crossPicks),
        ),
      ],
    );
    container.read(modeProvider.notifier).set(Mode.manga);
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(Mode.manga), home: const ForYouScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining("You've rated 0 of 5 manga"), findsOneWidget);
    expect(find.text('Frieren (manga)'), findsOneWidget);
    expect(find.textContaining('· anime'), findsOneWidget);
    await close(tester);
  });
}
