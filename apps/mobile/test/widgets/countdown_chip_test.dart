import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/catalog/title.dart';
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/core/ui/clock.dart';
import 'package:miruyo/widgets/countdown_chip.dart';

void main() {
  const now = 1800000000;

  Future<void> pump(WidgetTester tester, {required bool compact, required int inSeconds}) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [clockProvider.overrideWith((ref) => Stream.value(now))],
        child: MaterialApp(
          theme: buildTheme(Mode.anime),
          home: Scaffold(
            body: Center(
              child: CountdownChip(
                next: NextAiring(ep: 3, airingAt: now + inSeconds),
                compact: compact,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('posters keep only the largest unit', (tester) async {
    await pump(tester, compact: false, inSeconds: 5 * 86400 + 18 * 3600);
    expect(find.text('EP 3 · 5d 18h'), findsOneWidget);
    await pump(tester, compact: true, inSeconds: 5 * 86400 + 18 * 3600);
    expect(find.text('EP 3 · 5d'), findsOneWidget);
    await pump(tester, compact: true, inSeconds: 3 * 3600 + 20 * 60);
    expect(find.text('EP 3 · 3h'), findsOneWidget);
    // screen readers still hear the full time
    expect(find.bySemanticsLabel(RegExp('3h 20m')), findsOneWidget);
  });
}
