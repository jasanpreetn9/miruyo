import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:miruyo/features/shell/swipe_back.dart';

void main() {
  Future<GoRouter> pump(WidgetTester tester, {Widget? page}) async {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: Text('Home')),
        ),
        GoRoute(
          path: '/page',
          pageBuilder: (_, state) => SwipeBackPage(
            key: state.pageKey,
            child: page ?? const Scaffold(body: Center(child: Text('Page'))),
          ),
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp.router(
        theme: ThemeData(platform: TargetPlatform.iOS),
        routerConfig: router,
      ),
    );
    unawaited(router.push('/page'));
    await tester.pumpAndSettle();
    return router;
  }

  testWidgets('a swipe right from the middle of the page goes back', (tester) async {
    await pump(tester);
    expect(find.text('Page'), findsOneWidget);
    await tester.dragFrom(const Offset(200, 300), const Offset(500, 0));
    await tester.pumpAndSettle();
    expect(find.text('Page'), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });

  testWidgets('a short swipe springs back and stays', (tester) async {
    await pump(tester);
    await tester.timedDragFrom(const Offset(200, 300), const Offset(60, 0), const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    expect(find.text('Page'), findsOneWidget);
  });

  testWidgets('something inside that scrolls sideways keeps its drag', (tester) async {
    await pump(
      tester,
      page: Scaffold(
        body: SizedBox(
          height: 100,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [for (var i = 0; i < 20; i++) SizedBox(width: 80, child: Text('Item $i'))],
          ),
        ),
      ),
    );
    await tester.dragFrom(const Offset(300, 50), const Offset(-200, 0));
    await tester.dragFrom(const Offset(100, 50), const Offset(150, 0));
    await tester.pumpAndSettle();
    expect(find.text('Item 0'), findsOneWidget); // still on the page, the rail scrolled
  });
}
