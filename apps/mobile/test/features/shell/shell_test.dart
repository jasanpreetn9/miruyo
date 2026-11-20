import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/app.dart';
import 'package:miruyo/core/auth/session.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/gestures/haptics.dart';
import 'package:miruyo/core/providers.dart';
import 'package:miruyo/core/storage/prefs.dart';
import 'package:miruyo/core/ui/toast.dart';
import 'package:miruyo/features/shell/mode_toggle.dart';

import '../../helpers.dart';

void main() {
  late ProviderContainer container;
  late RecordingHaptics haptics;

  Future<void> pumpApp(WidgetTester tester) async {
    haptics = RecordingHaptics();
    container = await testContainer(
      haptics: haptics,
      overrides: [
        tokenStoreProvider.overrideWithValue(MemoryTokenStore()),
        onlineProvider.overrideWith((ref) => Stream.value(true)),
      ],
    );
    await tester.pumpWidget(UncontrolledProviderScope(container: container, child: const MiruyoApp()));
    await tester.pumpAndSettle();
  }

  /// Unmounts the app and disposes the container inside the test, so the
  /// screens' cache timers are gone before Flutter checks for pending ones.
  Future<void> closeApp(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  /// A widget test against the whole app, closed afterwards.
  void appTest(String description, Future<void> Function(WidgetTester tester) body) {
    testWidgets(description, (tester) async {
      await pumpApp(tester);
      await body(tester);
      await closeApp(tester);
    });
  }

  appTest('starts on Home with five tabs and Log In while signed out', (tester) async {
    for (final label in ['Home', 'Browse', 'Seasonal', 'My List', 'Profile']) {
      expect(find.text(label), findsWidgets);
    }
    expect(find.text('Log In'), findsOneWidget);
    expect(container.read(sessionProvider).authState, AuthState.signedOut);
  });

  appTest('tabs switch screens', (tester) async {
    await tester.tap(find.text('Browse').last); // the tab bar's, not Home's button
    await tester.pumpAndSettle();
    expect(find.text('Browse anime'), findsOneWidget);
  });

  appTest('tapping Manga switches mode, renames Seasonal and remembers it', (tester) async {
    await tester.tap(find.bySemanticsLabel('Manga mode'));
    await tester.pumpAndSettle();
    expect(container.read(modeProvider), Mode.manga);
    expect(find.text('Releases'), findsOneWidget);
    expect(find.text('Seasonal'), findsNothing);
    expect(container.read(prefsProvider).getString(PrefKeys.mode), 'manga');
    expect(haptics.played, [Haptic.selection]);
  });

  appTest('dragging the thumb past halfway switches mode with one Selection haptic', (tester) async {
    final toggle = find.byType(ModeToggle);
    final gesture = await tester.startGesture(tester.getCenter(toggle) - const Offset(30, 0));
    for (var i = 0; i < 12; i++) {
      await gesture.moveBy(const Offset(8, 0));
      await tester.pump();
    }
    await gesture.up();
    await tester.pumpAndSettle();
    expect(container.read(modeProvider), Mode.manga);
    expect(haptics.played, [Haptic.selection]);
  });

  appTest('a short drag snaps back and keeps the mode', (tester) async {
    final gesture = await tester.startGesture(tester.getCenter(find.byType(ModeToggle)));
    await gesture.moveBy(const Offset(12, 0));
    await tester.pump();
    await gesture.moveBy(const Offset(6, 0));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(container.read(modeProvider), Mode.anime);
    expect(haptics.played, isEmpty);
  });

  appTest('tapping the current tab again scrolls it back to the top', (tester) async {
    final page = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down).first;
    double offset() => tester.state<ScrollableState>(page).position.pixels;
    await tester.drag(page, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(offset(), greaterThan(0));
    await tester.tap(find.text('Home').last);
    await tester.pumpAndSettle();
    expect(offset(), 0);
  });

  appTest('toasts stack above the tab bar, at most three, with Undo', (tester) async {
    var undone = 0;
    final toasts = container.read(toastProvider.notifier);
    for (final n in [1, 2, 3, 4]) {
      toasts.show('Toast $n', action: ToastAction('Undo', () => undone++));
    }
    await tester.pumpAndSettle();
    expect(find.text('Toast 1'), findsNothing);
    expect(find.text('Toast 4'), findsOneWidget);
    await tester.tap(find.text('Undo').first);
    await tester.pumpAndSettle();
    expect(undone, 1);
    expect(find.text('Toast 4'), findsNothing);
    // the rest time out after 4s
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    expect(find.text('Toast 3'), findsNothing);
  });

  appTest('accessibility on every tab and Log In: labelled tap targets of at least 44pt', (tester) async {
    final semantics = tester.ensureSemantics();
    Future<void> check(String where) async {
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: where);
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline), reason: where);
      // (text contrast is checked in the screens' own tests: here it samples the
      // selected tab's tinted pill against the bar, not the label on it)
    }

    await check('Home');
    for (final tab in ['Browse', 'Seasonal', 'My List', 'Profile']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      await check(tab);
    }
    await tester.tap(find.text('Log In').first);
    await tester.pumpAndSettle();
    await check('Log In');
    semantics.dispose();
  });
}
