import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/gestures/haptics.dart';
import 'package:miruyo/core/gestures/row_swipe.dart';
import 'package:miruyo/core/theme/app_theme.dart';

import '../../helpers.dart';

void main() {
  late List<String> fired;
  late RecordingHaptics haptics;

  Future<void> pump(WidgetTester tester, {bool canPositive = true}) async {
    fired = [];
    haptics = RecordingHaptics();
    final container = await testContainer(haptics: haptics);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(Mode.anime),
          home: Scaffold(
            body: Center(
              child: RowSwipe(
                onPositive: canPositive ? () => fired.add('+1') : null,
                onNegative: () => fired.add('-1'),
                onMore: () => fired.add('more'),
                child: Container(width: 360, height: 80, color: Colors.grey, key: const Key('row')),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// A slow drag (no flick) by [dx], released.
  Future<void> drag(WidgetTester tester, double dx) async {
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('row'))));
    // past the drag slop first, then the rest in small steps
    final steps = 20;
    for (var i = 0; i < steps; i++) {
      await gesture.moveBy(Offset(dx / steps, 0));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
  }

  testWidgets('right at 72px is +1, with Light when it arms', (tester) async {
    await pump(tester);
    await drag(tester, 72);
    expect(fired, ['+1']);
    expect(haptics.played.first, Haptic.light);
  });

  testWidgets('right at 71px springs back and does nothing', (tester) async {
    await pump(tester);
    await drag(tester, 71);
    expect(fired, isEmpty);
    expect(haptics.played, isEmpty);
  });

  testWidgets('a short left (up to 159px) is −1', (tester) async {
    await pump(tester);
    await drag(tester, -159);
    expect(fired, ['-1']);
  });

  testWidgets('a long left (160px) opens More, with a Medium haptic', (tester) async {
    await pump(tester);
    await drag(tester, -160);
    expect(fired, ['more']);
    expect(haptics.played, contains(Haptic.medium));
  });

  testWidgets('dragging back under the threshold disarms silently', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('row'))));
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(10, 0));
      await tester.pump(const Duration(milliseconds: 40));
    }
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(const Offset(-8, 0));
      await tester.pump(const Duration(milliseconds: 40));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fired, isEmpty);
    expect(haptics.played, [Haptic.light]);
  });

  testWidgets('with no positive action, right swipes never arm', (tester) async {
    await pump(tester, canPositive: false);
    await drag(tester, 120);
    expect(fired, isEmpty);
  });

  testWidgets('holding 450ms opens More', (tester) async {
    await pump(tester);
    final gesture = await tester.startGesture(tester.getCenter(find.byKey(const Key('row'))));
    await tester.pump(const Duration(milliseconds: 500));
    await gesture.up();
    await tester.pumpAndSettle();
    expect(fired, ['more']);
  });
}
