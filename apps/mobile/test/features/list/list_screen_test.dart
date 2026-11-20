import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/gestures/haptics.dart';
import 'package:miruyo/core/list/list_entry.dart';
import 'package:miruyo/core/list/list_store.dart';
import 'package:miruyo/core/providers.dart';
import 'package:miruyo/core/storage/prefs.dart';
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/core/ui/clock.dart';
import 'package:miruyo/core/ui/toast.dart';
import 'package:miruyo/features/list/list_data.dart';
import 'package:miruyo/features/list/list_edit.dart';
import 'package:miruyo/features/list/list_grid_card.dart';
import 'package:miruyo/features/list/list_screen.dart';
import 'package:miruyo/widgets/poster_card.dart' show StatusBar;

import '../../helpers.dart';
import 'list_data_test.dart' show entry, now;

void main() {
  late ProviderContainer container;
  late RecordingHaptics haptics;

  final entries = [
    entry(
      1,
      romaji: 'Frieren',
      progress: 6,
      score: 9.5,
      updatedAt: now - 60,
      next: {'episode': 9, 'airingAt': now + 3600, 'timeUntilAiring': 0},
    ),
    entry(2, romaji: 'Dandadan', progress: 3, updatedAt: now - 120),
    entry(3, romaji: 'Apothecary', progress: 12, updatedAt: now - 180),
    entry(4, romaji: 'Mushishi', status: 'PLANNING', updatedAt: now - 240),
    entry(5, romaji: 'Monster', status: 'PLANNING', priority: 2),
    entry(6, romaji: 'Ping Pong', status: 'COMPLETED', progress: 11, completedAt: {'year': 2025, 'month': 3, 'day': 2}),
  ];

  Future<void> pump(
    WidgetTester tester, {
    bool coachSeen = true,
    double textScale = 1,
    List<CustomList> custom = const [],
    Set<int> hidden = const {},
  }) async {
    haptics = RecordingHaptics();
    container = await testContainer(
      haptics: haptics,
      overrides: [
        listCollectionProvider.overrideWith((ref, mode) async {
          final collection = ListCollection(entries: entries, custom: custom, hidden: hidden);
          await Future<void>.value(); // as the real fetch would
          ref.read(listStoreProvider.notifier).seed([for (final c in collection.entries) ListEntry.fromSaved(c.entry)]);
          return collection;
        }),
        clockProvider.overrideWith((ref) => Stream.value(now)),
      ],
    );
    // the coach mark loops until "Got it"; most tests start past it
    if (coachSeen) await container.read(prefsProvider).setString(PrefKeys.rowsCoachSeen, '1');
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
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: const MyListScreen(),
              // the shell swaps the tab bar for this in Edit
              bottomNavigationBar: ref.watch(listEditProvider).editing ? const ListEditBar() : null,
            ),
          ),
        ),
      ),
    );
    if (coachSeen) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  MediaListStatus? statusOf(int id) => container.read(listStoreProvider)[id]?.status;

  testWidgets('tabs show counts; Planning lists Up next in order', (tester) async {
    await pump(tester);
    expect(find.text('Watching'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('Frieren'), findsOneWidget);
    expect(find.text('Mushishi'), findsNothing);

    await tester.ensureVisible(find.text('Planning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planning'));
    await tester.pumpAndSettle();
    expect(find.text('Up next'), findsOneWidget); // the sort
    expect(find.textContaining('Up next #1'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Monster')).dy, lessThan(tester.getTopLeft(find.text('Mushishi')).dy));
    await close(tester);
  });

  testWidgets('a custom list is a tab after the statuses, holding its titles whatever their status', (tester) async {
    // Mushishi is only on the custom list ("hide from status lists")
    await pump(
      tester,
      custom: [
        const CustomList(name: 'Rewatch someday', mediaIds: [1, 6, 7]),
      ],
      hidden: {1},
    );
    // off the status tabs: Watching counts 2
    expect(find.text('Frieren'), findsNothing);
    expect(find.bySemanticsLabel('Watching, 2'), findsOneWidget);

    await tester.ensureVisible(find.text('Rewatch someday'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Rewatch someday, 3'), findsOneWidget);
    await tester.tap(find.text('Rewatch someday'));
    await tester.pumpAndSettle();
    expect(find.text('Frieren'), findsOneWidget);
    expect(find.text('Ping Pong'), findsOneWidget);
    expect(find.textContaining('Completed · '), findsOneWidget);
    // Edit moves titles between statuses: off on a custom list
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Edit')).onPressed, isNull);
    await close(tester);
  });

  testWidgets('My List swaps the swipes: right is −1, a short left +1', (tester) async {
    await pump(tester);
    // as when signed in: edits go through (to the fake API)
    container.read(listStoreProvider.notifier).sync = true;
    int progressOf(int id) => container.read(listStoreProvider)[id]!.progress;

    Future<void> swipe(double dx) async {
      final gesture = await tester.startGesture(tester.getCenter(find.text('Frieren')));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(Offset(dx / 20, 0));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await swipe(110);
    expect(progressOf(1), 5);
    await swipe(-110);
    expect(progressOf(1), 6);
    await close(tester);
  });

  testWidgets('the coach mark teaches the swipes once, on the top row', (tester) async {
    await pump(tester, coachSeen: false);
    expect(find.text('Rows move'), findsOneWidget);
    expect(find.text('Swipe left to add one episode'), findsOneWidget);
    // the top row moves on its own, and nothing is saved by it
    final rest = tester.getTopLeft(find.text('Frieren')).dx;
    await tester.pump(const Duration(milliseconds: 1200));
    expect(tester.getTopLeft(find.text('Frieren')).dx, lessThan(rest));
    expect(container.read(listStoreProvider)[1]?.progress, 6);

    await tester.tap(find.text('Got it'));
    await tester.pumpAndSettle();
    expect(find.text('Rows move'), findsNothing);
    expect(container.read(prefsProvider).getString(PrefKeys.rowsCoachSeen), isNotNull);
    await close(tester);
  });

  testWidgets('the filter narrows the tab and says when nothing matches', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'dan');
    await tester.pumpAndSettle();
    expect(find.text('Dandadan'), findsOneWidget);
    expect(find.text('Frieren'), findsNothing);

    await tester.enterText(find.byType(TextField), 'zzz');
    await tester.pumpAndSettle();
    expect(find.text('No matches on this tab'), findsOneWidget);
    await tester.tap(find.text('Clear filter'));
    await tester.pumpAndSettle();
    expect(find.text('Frieren'), findsOneWidget);
    await close(tester);
  });

  testWidgets('the grid is one choice for every tab, remembered', (tester) async {
    await pump(tester);
    await tester.tap(find.bySemanticsLabel('Show as grid'));
    await tester.pumpAndSettle();
    expect(find.byType(ListGridCard), findsNWidgets(3));
    expect(container.read(prefsProvider).getString(PrefKeys.listView), 'grid');
    await close(tester);
  });

  testWidgets('grid cards: nothing on the cover, status under it, swipes for +1 and −1', (tester) async {
    await pump(tester);
    container.read(listStoreProvider.notifier).sync = true;
    await tester.tap(find.bySemanticsLabel('Show as grid'));
    await tester.pumpAndSettle();

    // Frieren: where you are (the tab names the status), then your score and the note
    expect(find.text('EP 6 / 24'), findsOneWidget);
    expect(find.textContaining('9.5'), findsOneWidget);
    expect(find.textContaining('2 new · EP 9 in 1h 00m'), findsOneWidget);
    expect(find.byType(StatusBar), findsNWidgets(3));

    // no +1 button: a short swipe left on the card is +1, a swipe right −1
    expect(find.byIcon(Symbols.add_rounded), findsNothing);
    Future<void> swipe(double dx) async {
      final card = find.ancestor(of: find.text('Frieren'), matching: find.byType(ListGridCard)).first;
      final gesture = await tester.startGesture(tester.getCenter(card));
      for (var i = 0; i < 20; i++) {
        await gesture.moveBy(Offset(dx / 20, 0));
        await tester.pump(const Duration(milliseconds: 40));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    await swipe(-110);
    expect(container.read(listStoreProvider)[1]?.progress, 7);
    expect(find.text('EP 7 / 24'), findsOneWidget);
    await swipe(110);
    expect(container.read(listStoreProvider)[1]?.progress, 6);

    // the Completed shelf: no progress, when you finished it
    await tester.ensureVisible(find.text('Completed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Completed'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Finished Mar 2025'), findsOneWidget);
    expect(find.text('Completed'), findsWidgets);
    expect(find.textContaining('11/'), findsNothing);
    await close(tester);
  });

  testWidgets('Edit: tap to select, Move to… a status, Undo', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.text('Select'), findsOneWidget);
    expect(find.text('Done'), findsOneWidget);

    await tester.tap(find.text('Frieren'));
    await tester.tap(find.text('Dandadan'));
    await tester.pumpAndSettle();
    expect(find.text('2 selected'), findsOneWidget);

    await tester.tap(find.text('Move to…'));
    await tester.pumpAndSettle();
    expect(find.text('Watching · here'), findsOneWidget);
    await tester.tap(find.text('Paused'));
    await tester.pumpAndSettle();

    expect(statusOf(1), MediaListStatus.paused);
    expect(statusOf(2), MediaListStatus.paused);
    expect(find.text('Frieren'), findsNothing);
    expect(find.text('Select'), findsOneWidget); // Edit stays on, selection cleared
    final toast = container.read(toastProvider).first;
    expect(toast.message, 'Moved 2 to Paused');
    expect(haptics.played.last, Haptic.success);

    toast.action!.run();
    await tester.pumpAndSettle();
    expect(statusOf(1), MediaListStatus.current);
    expect(find.text('Frieren'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Edit: painting down the circles selects every row passed', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    // the circle sits in the row's first 44px
    final first = tester.getTopLeft(find.text('Frieren'));
    final start = Offset(tester.getTopLeft(find.byType(CustomScrollView).first).dx + 30, first.dy + 8);
    final gesture = await tester.startGesture(start);
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('3 selected'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Edit: hold a row to carry the selection and drop it on a status', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Dandadan'));
    await tester.pumpAndSettle();

    final gesture = await tester.startGesture(tester.getCenter(find.text('Frieren')));
    await tester.pump(const Duration(milliseconds: 350));
    expect(haptics.played.last, Haptic.medium);
    await tester.pumpAndSettle();
    expect(find.text('Drop on a status'), findsOneWidget);

    await gesture.moveTo(tester.getCenter(find.text('Dropped')));
    await tester.pump();
    expect(haptics.played.last, Haptic.selection);
    await gesture.up();
    await tester.pumpAndSettle();

    expect(statusOf(1), MediaListStatus.dropped);
    expect(statusOf(2), MediaListStatus.dropped);
    expect(find.text('Drop on a status'), findsNothing);
    await close(tester);
  });

  testWidgets('Edit: dropping anywhere else changes nothing and keeps the selection', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    final gesture = await tester.startGesture(tester.getCenter(find.text('Frieren')));
    await tester.pump(const Duration(milliseconds: 350));
    await gesture.moveBy(const Offset(0, -40));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(statusOf(1), MediaListStatus.current);
    expect(find.text('1 selected'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Edit: hold Remove to take the selection off, with Undo', (tester) async {
    await pump(tester);
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frieren'));
    await tester.pumpAndSettle();

    // letting go early does nothing
    var gesture = await tester.startGesture(tester.getCenter(find.text('Remove · hold')));
    await tester.pump(const Duration(milliseconds: 400));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(container.read(listStoreProvider).isRemoved(1), isFalse);

    gesture = await tester.startGesture(tester.getCenter(find.text('Remove · hold')));
    await tester.pump(const Duration(milliseconds: 150)); // the tap-down delay
    await tester.pump(const Duration(milliseconds: 900));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(container.read(listStoreProvider).isRemoved(1), isTrue);
    expect(find.text('Frieren'), findsNothing);
    final toast = container.read(toastProvider).first;
    expect(toast.message, 'Removed Frieren from your list');

    toast.action!.run();
    await tester.pumpAndSettle();
    expect(find.text('Frieren'), findsOneWidget);
    await close(tester);
  });

  testWidgets('Edit on Up next: the drag handle reorders and saves one priority', (tester) async {
    await pump(tester);
    await tester.ensureVisible(find.text('Planning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Reorder'), findsNWidgets(2));

    // drag Mushishi (second) above Monster
    final handle = find.bySemanticsLabel('Reorder').last;
    final gesture = await tester.startGesture(tester.getCenter(handle));
    await tester.pump(const Duration(milliseconds: 50));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(0, -12));
      await tester.pump(const Duration(milliseconds: 16));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    expect(container.read(listStoreProvider)[4]?.priority, 3);
    expect(tester.getTopLeft(find.text('Mushishi')).dy, lessThan(tester.getTopLeft(find.text('Monster')).dy));
    expect(container.read(toastProvider).first.message, 'Up next order saved to AniList');
    await close(tester);
  });

  testWidgets('quick actions: Move to top of Up next, the path without dragging', (tester) async {
    await pump(tester);
    // signed in, as far as the list is concerned
    container.read(listStoreProvider.notifier).sync = true;
    await tester.ensureVisible(find.text('Planning'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planning'));
    await tester.pumpAndSettle();

    await tester.longPress(find.text('Mushishi'));
    await tester.pumpAndSettle();
    expect(find.text('Open details'), findsOneWidget); // the hold opened the sheet, and nothing else
    container.read(listStoreProvider.notifier).sync = false; // saves stay on the device
    await tester.tap(find.text('Move to top of Up next'));
    await tester.pumpAndSettle();
    expect(container.read(listStoreProvider)[4]?.priority, 3);
    expect(tester.getTopLeft(find.text('Mushishi')).dy, lessThan(tester.getTopLeft(find.text('Monster')).dy));

    // first already: offered, but off
    container.read(listStoreProvider.notifier).sync = true;
    await tester.longPress(find.text('Mushishi'));
    await tester.pumpAndSettle();
    final tile = tester.widget<ListTile>(
      find.ancestor(of: find.text('Move to top of Up next'), matching: find.byType(ListTile)),
    );
    expect(tile.enabled, isFalse);
    await close(tester);
  });

  testWidgets('at the largest text (1.3×), the rows and the grid still fit', (tester) async {
    await pump(tester, textScale: 1.3);
    expect(tester.takeException(), isNull);
    await tester.tap(find.bySemanticsLabel('Show as grid'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(ListGridCard), findsWidgets);
    await close(tester);
  });

  testWidgets('accessibility: labelled tap targets, 44pt targets, readable text', (tester) async {
    final handle = tester.ensureSemantics();
    await pump(tester);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
    await close(tester);
  });
}
