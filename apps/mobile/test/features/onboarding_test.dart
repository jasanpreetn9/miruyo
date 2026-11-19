import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miruyo/core/anilist/client.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/auth/session.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/catalog/title.dart';
import 'package:miruyo/core/list/list_store.dart';
import 'package:miruyo/core/providers.dart';
import 'package:miruyo/core/storage/prefs.dart';
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/features/home/home_data.dart';
import 'package:miruyo/features/onboarding/quick_pick.dart';
import 'package:miruyo/features/onboarding/welcome_screen.dart';

import '../helpers.dart';

/// Signed in, recording what's saved to AniList.
class _SignedIn extends Session {
  final saved = <ViewerSettings>[];

  @override
  SessionState build() => const SessionState(
    authState: AuthState.signedIn,
    user: AniListUser(id: 1, name: 'rin', titleLanguage: TitleLanguage.romaji),
  );

  @override
  Future<void> updateSettings(ViewerSettings settings) async => saved.add(settings);
}

Title title(int id) => adaptMedia(
  AniListMedia.fromJson({
    'id': id,
    'type': 'ANIME',
    'format': 'TV',
    'title': {'romaji': 'Show $id'},
    'coverImage': <String, Object>{},
  }),
);

void main() {
  final titles = [for (var i = 1; i <= 9; i++) title(i)];

  group('QuickPickGrid', () {
    testWidgets('tap toggles; dragging across paints, the first poster deciding', (tester) async {
      final container = await testContainer();
      addTearDown(container.dispose);
      var picked = <int>{};
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildTheme(Mode.anime),
            home: Scaffold(
              body: StatefulBuilder(
                builder: (context, setState) =>
                    QuickPickGrid(titles: titles, picked: picked, onChanged: (p) => setState(() => picked = p)),
              ),
            ),
          ),
        ),
      );
      Offset centre(int id) => tester.getCenter(find.bySemanticsLabel('Show $id'));

      await tester.tapAt(centre(1));
      await tester.pump();
      expect(picked, {1});

      // across the second row: 4, 5, 6 all get picked
      var gesture = await tester.startGesture(centre(4));
      for (final id in [5, 6]) {
        await gesture.moveTo(centre(id));
        await tester.pump();
      }
      await gesture.up();
      await tester.pump();
      expect(picked, {1, 4, 5, 6});

      // starting on a picked poster removes as it goes
      gesture = await tester.startGesture(centre(5));
      await gesture.moveTo(centre(6));
      await tester.pump();
      await gesture.up();
      await tester.pump();
      expect(picked, {1, 4});

      // a still hold reads about the poster instead of picking it
      await tester.longPressAt(centre(2));
      await tester.pumpAndSettle();
      expect(find.text('Open details'), findsOneWidget);
      expect(picked, {1, 4});
    });
  });

  group('WelcomeScreen', () {
    late ProviderContainer container;
    late _SignedIn session;

    Future<void> pump(WidgetTester tester, {required int anime}) async {
      session = _SignedIn();
      container = await testContainer(
        overrides: [
          sessionProvider.overrideWith(() => session),
          viewerCountsProvider.overrideWith((ref) async => (anime: anime, manga: 3)),
          homeFeedProvider.overrideWith(
            (ref, mode) async => FeedContent(
              trending: titles,
              popularHeading: '',
              popularSubtitle: '',
              popular: const [],
              upcomingHeading: '',
              upcoming: const [],
            ),
          ),
        ],
      );
      container.read(listStoreProvider.notifier).sync = true;
      final router = GoRouter(
        initialLocation: '/welcome',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('Home')),
          ),
          GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
        ],
      );
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: buildTheme(Mode.anime), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
    }

    Future<void> close(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }

    testWidgets('setup saves what changed, then goes Home for a list with titles', (tester) async {
      await pump(tester, anime: 120);
      expect(find.textContaining('Imported 120 anime and 3 manga'), findsOneWidget);

      await tester.tap(find.text('Manga'));
      await tester.tap(find.text('English'));
      await tester.pump();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();

      expect(container.read(modeProvider), Mode.manga);
      expect(session.saved.single.titleLanguage, TitleLanguage.english);
      expect(session.saved.single.displayAdultContent, isNull);
      // manga has 3 titles: no quick-pick, straight Home
      expect(find.text('Home'), findsOneWidget);
      expect(container.read(prefsProvider).getString(PrefKeys.onboarded), '1');
      await close(tester);
    });

    testWidgets("the mode's thumb drags; it lands on the nearer side", (tester) async {
      await pump(tester, anime: 120);
      // not far enough: back to Anime
      await tester.drag(find.text('Anime'), const Offset(60, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(container.read(modeProvider), Mode.anime);
      await close(tester);
    });

    testWidgets("dragging the mode's thumb past halfway picks Manga", (tester) async {
      await pump(tester, anime: 120);
      await tester.drag(find.text('Anime'), const Offset(140, 0));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(container.read(modeProvider), Mode.manga);
      await close(tester);
    });

    testWidgets('an empty list gets the quick-pick; Back keeps the picks', (tester) async {
      await pump(tester, anime: 0);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(session.saved, isEmpty); // nothing changed
      expect(find.text('Seen any of these?'), findsOneWidget);

      await tester.tap(find.bySemanticsLabel('Show 2'));
      await tester.pump();
      expect(find.text('Add 1 to Completed'), findsOneWidget);

      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(find.text('Make it yours'), findsOneWidget);
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
      expect(find.text('Add 1 to Completed'), findsOneWidget);

      await tester.tap(find.text('Add 1 to Completed'));
      await tester.pumpAndSettle();
      expect(container.read(listStoreProvider)[2]?.status, MediaListStatus.completed);
      expect(find.text('Home'), findsOneWidget);
      await close(tester);
    });

    testWidgets('Skip for now finishes setup without saving', (tester) async {
      await pump(tester, anime: 5);
      await tester.tap(find.text('Skip for now'));
      await tester.pumpAndSettle();
      expect(session.saved, isEmpty);
      expect(find.text('Home'), findsOneWidget);
      expect(container.read(prefsProvider).getString(PrefKeys.onboarded), '1');
      await close(tester);
    });
  });
}
