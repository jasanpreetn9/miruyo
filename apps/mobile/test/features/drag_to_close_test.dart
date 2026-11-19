import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miruyo/core/gestures/haptics.dart';
import 'package:miruyo/core/providers.dart';
import 'package:miruyo/features/shell/drag_to_close.dart';
import 'package:miruyo/features/shell/swipe_back.dart';

void main() {
  Future<(GoRouter, RecordingHaptics)> pump(WidgetTester tester) async {
    late GoRouter router;
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/page',
          pageBuilder: (_, state) => SwipeBackPage(
            key: state.pageKey,
            child: Scaffold(
              body: DragToClose(
                onClose: () => router.pop(),
                builder: (_, physics) => ListView(
                  physics: physics,
                  children: [for (var i = 0; i < 40; i++) SizedBox(height: 60, child: Text('Row $i'))],
                ),
              ),
            ),
          ),
        ),
      ],
    );
    final haptics = RecordingHaptics();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [hapticsProvider.overrideWithValue(haptics)],
        child: MaterialApp.router(
          theme: ThemeData(platform: TargetPlatform.iOS),
          routerConfig: router,
        ),
      ),
    );
    unawaited(router.push('/page'));
    await tester.pumpAndSettle();
    return (router, haptics);
  }

  testWidgets('from the top, a long drag down closes, with a tick at the arm', (tester) async {
    final (_, haptics) = await pump(tester);
    final gesture = await tester.startGesture(const Offset(200, 300));
    for (var i = 0; i < 20; i++) {
      await gesture.moveBy(const Offset(0, 10));
      await tester.pump(const Duration(milliseconds: 40));
    }
    // the page behind shows through while pulling
    expect(find.text('Home'), findsOneWidget);
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Row 0'), findsNothing);
    expect(haptics.played, [Haptic.light]);
  });

  testWidgets('a short slow drag springs back', (tester) async {
    await pump(tester);
    await tester.timedDragFrom(const Offset(200, 300), const Offset(0, 80), const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Row 0'), findsOneWidget);
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('scrolled down, a drag down scrolls instead', (tester) async {
    await pump(tester);
    await tester.drag(find.byType(ListView), const Offset(0, -600));
    await tester.pumpAndSettle();
    await tester.timedDragFrom(const Offset(200, 300), const Offset(0, 200), const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Home'), findsNothing);
    expect(find.text('Row 0'), findsNothing); // still scrolled partway
  });
}
