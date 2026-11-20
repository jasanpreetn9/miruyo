import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/auth/session.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/gestures/haptics.dart';
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/features/list/list_data.dart';
import 'package:miruyo/features/profile/profile_data.dart';
import 'package:miruyo/features/user/user_data.dart';
import 'package:miruyo/features/user/user_screen.dart';

import '../../helpers.dart';
import '../list/list_data_test.dart' show entry;

class _SignedIn extends Session {
  @override
  SessionState build() => const SessionState(
    authState: AuthState.signedIn,
    user: AniListUser(id: 1, name: 'rin'),
  );
}

void main() {
  testWidgets('the stat cards swipe between Anime and Manga (at 1.3× text); the wrong way only stretches', (
    tester,
  ) async {
    final haptics = RecordingHaptics();
    final container = await testContainer(
      haptics: haptics,
      overrides: [
        sessionProvider.overrideWith(_SignedIn.new),
        userProfileProvider.overrideWith(
          (ref, name) async => (
            account: <String, Object?>{'id': 1, 'name': 'rin', 'createdAt': 1552000000},
            anime: <AniListMedia>[],
            manga: <AniListMedia>[],
            titlesError: null,
          ),
        ),
        activityProvider.overrideWith(
          (ref, id) async => const [
            <HeatCell?>[null],
          ],
        ),
        listCollectionProvider.overrideWith(
          (ref, mode) async => ListCollection(
            entries: [
              if (mode.isAnime) entry(1, progress: 3) else entry(2, type: 'MANGA', format: 'MANGA', progress: 40),
            ],
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(Mode.anime),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.3)),
            child: child!,
          ),
          home: const Scaffold(body: ProfileScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    // your profile is your user page: Settings, no list tabs, and the facts card says what Stats says
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Anime list'), findsNothing);
    expect(find.text('Member since'), findsOneWidget);
    expect(find.text('Total anime'), findsNWidgets(2));

    // accessibility: labelled tap targets, 44pt targets, readable text
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();

    await tester.ensureVisible(find.text('Total anime').last);
    await tester.pumpAndSettle();

    // right from Anime leads nowhere: it stretches back
    await tester.drag(find.text('Total anime').last, const Offset(200, 0));
    await tester.pumpAndSettle();
    expect(container.read(modeProvider), Mode.anime);

    // a short drag springs back
    await tester.timedDrag(find.text('Total anime').last, const Offset(-60, 0), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(container.read(modeProvider), Mode.anime);

    // past 30% switches, the top bar's mode with it
    await tester.drag(find.text('Total anime').last, const Offset(-160, 0));
    await tester.pumpAndSettle();
    expect(container.read(modeProvider), Mode.manga);
    expect(find.text('Total manga'), findsNWidgets(2));
    expect(haptics.played, contains(Haptic.selection));

    await tester.drag(find.text('Total manga').last, const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(container.read(modeProvider), Mode.anime);
  });

  /// A menu's item, as a tap lands on it (its text alone may not take the hit).
  Finder menuItem(String text) =>
      find.ancestor(of: find.text(text).last, matching: find.byWidgetPredicate((w) => w is CheckedPopupMenuItem)).first;

  testWidgets("someone's list filters by AniList's genre, country and year", (tester) async {
    final container = await testContainer(
      overrides: [
        sessionProvider.overrideWith(_SignedIn.new),
        userProfileProvider.overrideWith(
          (ref, name) async => (
            account: <String, Object?>{'id': 7, 'name': 'mio', 'createdAt': 1552000000},
            anime: <AniListMedia>[],
            manga: <AniListMedia>[],
            titlesError: null,
          ),
        ),
        activityProvider.overrideWith(
          (ref, id) async => const [
            <HeatCell?>[null],
          ],
        ),
        userListProvider.overrideWith(
          (ref, key) async => [
            entry(
              1,
              romaji: 'Kaiju',
              media: {
                'genres': ['Action'],
                'countryOfOrigin': 'JP',
                'seasonYear': 2026,
              },
            ),
            entry(
              2,
              romaji: 'Lovers',
              media: {
                'genres': ['Drama'],
                'countryOfOrigin': 'KR',
                'seasonYear': 2019,
              },
            ),
          ],
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(Mode.anime),
          home: const Scaffold(body: UserScreen(name: 'mio')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Anime list'));
    await tester.pumpAndSettle();
    expect(find.text('Kaiju'), findsOneWidget);
    expect(find.text('Lovers'), findsOneWidget);

    // accessibility, before a menu moves the page: labelled tap targets,
    // 44pt targets, readable text
    final semantics = tester.ensureSemantics();
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();

    // the menus offer what's on the list, by name
    await tester.tap(find.text('Country'));
    await tester.pumpAndSettle();
    expect(find.text('Any country'), findsOneWidget);
    expect(find.text('Japan'), findsOneWidget);
    await tester.tap(menuItem('South Korea'));
    await tester.pumpAndSettle();
    expect(find.text('Kaiju'), findsNothing);
    expect(find.text('Lovers'), findsOneWidget);
    // the menu now says its pick
    expect(find.text('South Korea'), findsOneWidget);

    await tester.tap(find.text('Year'));
    await tester.pumpAndSettle();
    await tester.tap(menuItem('2026'));
    await tester.pumpAndSettle();
    expect(find.text('Nothing matches.'), findsOneWidget);

    // "Any country" clears it
    await tester.tap(find.text('South Korea'));
    await tester.pumpAndSettle();
    await tester.tap(menuItem('Any country'));
    await tester.pumpAndSettle();
    expect(find.text('Kaiju'), findsOneWidget);
  });
}
