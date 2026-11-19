import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/features/profile/charts.dart';
import 'package:miruyo/features/profile/profile_data.dart';

void main() {
  for (final (name, counts) in [
    ('with nothing scored yet', List.filled(10, 0)),
    ('with scores', [0, 1, 0, 2, 3, 5, 8, 13, 4, 1]),
  ]) {
    testWidgets('the score bars are 44pt tap targets $name', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: buildTheme(Mode.anime),
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: ScrubBars(
                  bars: [
                    for (final (i, count) in counts.indexed)
                      Bar(label: '${i + 1}', name: 'Score ${i + 1}', count: count, tone: Tone.mute),
                  ],
                  describe: (b) => '${b.name} · ${b.count}',
                  onReadout: (_) {},
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      for (var i = 0; i < counts.length; i++) {
        final label = 'Score ${i + 1} · ${counts[i]}';
        final size = tester.getSize(find.byWidgetPredicate((w) => w is Semantics && w.properties.label == label));
        expect(size.height, greaterThanOrEqualTo(44), reason: 'score ${i + 1}');
      }
      semantics.dispose();
    });
  }
}
