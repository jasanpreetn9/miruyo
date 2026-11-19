import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/auth/session.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/notifications/episode_alerts.dart';
import 'package:miruyo/core/providers.dart';
import 'package:miruyo/core/storage/prefs.dart';
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/core/ui/clock.dart';
import 'package:miruyo/features/seasonal/seasonal_data.dart';
import 'package:miruyo/features/seasonal/seasonal_screen.dart';

import '../helpers.dart';

class _SignedOut extends Session {
  @override
  SessionState build() => const SessionState(authState: AuthState.signedOut);
}

void main() {
  // a fixed day: the screen shows whichever week holds today, so its labels
  // (and what the contrast check reads) would otherwise change with the date
  final now = DateTime(2026, 10, 14, 12);
  testWidgets(
    'Posters are remembered; Airing: a reminder by swipe, earlier days folded, the week bar swipes',
    (tester) => withClock(Clock.fixed(now), () async {
      final nowS = now.millisecondsSinceEpoch ~/ 1000;
      // one show a day, every day of whichever week is asked for, in the future
      // when it's this week's today or later
      AiringSlot slot(int id, int at) => AiringSlot.fromJson({
        'id': id,
        'episode': 3,
        'airingAt': at,
        'media': {
          'id': id,
          'type': 'ANIME',
          'format': 'TV',
          'title': {'romaji': 'Show $id', 'userPreferred': 'Show $id'},
          'coverImage': <String, Object>{},
        },
      });
      final alerts = FakeAlertScheduler();
      final weeks = <DateTime>[];
      final container = await testContainer(
        alerts: alerts,
        overrides: [
          sessionProvider.overrideWith(_SignedOut.new),
          clockProvider.overrideWith((ref) => Stream.value(nowS)),
          airingWeekProvider.overrideWith((ref, monday) async {
            weeks.add(monday);
            final base = monday.millisecondsSinceEpoch ~/ 1000;
            return [
              for (var d = 0; d < 7; d++)
                for (var k = 0; k < 4; k++) slot(monday.day * 100 + d * 10 + k, base + d * 86400 + 23 * 3600 + k * 60),
            ];
          }),
        ],
      );
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: buildTheme(Mode.anime),
            home: const Scaffold(body: SeasonalScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // the season chart's Posters view is remembered
      await tester.tap(find.byTooltip('Show as posters'));
      await tester.pumpAndSettle();
      expect(container.read(prefsProvider).getString(PrefKeys.seasonView), 'posters');
      expect(find.byTooltip('Show as cards'), findsOneWidget);

      await tester.tap(find.text('Airing'));
      await tester.pumpAndSettle();

      // accessibility: labelled tap targets, 44pt targets, readable text
      final semantics = tester.ensureSemantics();
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();

      // today's last show airs at 23:03, so it's still upcoming: swipe it right
      final today = now.weekday - 1;
      final monday = weeks.last;
      final id = monday.day * 100 + today * 10 + 3;
      expect(find.text('Back to now'), findsNothing);
      await tester.timedDrag(find.text('Show $id'), const Offset(120, 0), const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      expect(container.read(remindersProvider).single.mediaId, id);
      expect(alerts.scheduled.single.mediaId, id);
      expect(find.byWidgetPredicate((w) => w is Icon && w.semanticLabel == 'Reminder set'), findsOneWidget);

      // Monday and Tuesday are past: folded under "Earlier this week" after Sunday
      final earlier = find.text('EARLIER THIS WEEK');
      await tester.scrollUntilVisible(earlier, 400, scrollable: find.byType(Scrollable).last);
      await tester.pumpAndSettle();
      expect(find.text('· 8 episodes'), findsOneWidget);
      final mondayShow = find.text('Show ${monday.day * 100}');
      expect(mondayShow, findsNothing);
      await tester.tap(earlier);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(mondayShow, 200, scrollable: find.byType(Scrollable).last);
      expect(mondayShow, findsOneWidget);

      // the week bar swipes to next week; the pill offers this week back
      await tester.timedDrag(find.textContaining(' – '), const Offset(-200, 0), const Duration(milliseconds: 300));
      await tester.pumpAndSettle();
      expect(weeks.last, monday.add(const Duration(days: 7)));
      await tester.tap(find.text('This week'));
      await tester.pumpAndSettle();
      expect(weeks.last, monday);
      // let the toast's timer run out, and the screen caches' with the container
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    }),
  );
}
