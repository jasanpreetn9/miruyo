import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/auth/session.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/core/ui/clock.dart';
import 'package:miruyo/features/detail/detail_data.dart';
import 'package:miruyo/features/detail/detail_screen.dart';
import 'package:miruyo/features/detail/title_stats.dart';

import '../../helpers.dart';

class _SignedOut extends Session {
  @override
  SessionState build() => const SessionState(authState: AuthState.signedOut);
}

void main() {
  testWidgets('the title page: labelled tap targets of at least 44pt, readable text', (tester) async {
    final semantics = tester.ensureSemantics();
    final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    final container = await testContainer(
      overrides: [
        sessionProvider.overrideWith(_SignedOut.new),
        clockProvider.overrideWith((ref) => Stream.value(now)),
        detailProvider.overrideWith(
          (ref, id) async => createDetailContent({
            'id': id,
            'type': 'ANIME',
            'format': 'TV',
            'status': 'RELEASING',
            'episodes': 12,
            'averageScore': 87,
            'popularity': 120000,
            'genres': ['Adventure', 'Fantasy'],
            'description': 'An elf mage sets out again.',
            'title': {'romaji': 'Sousou no Frieren', 'userPreferred': 'Frieren'},
            'coverImage': <String, Object>{},
            'nextAiringEpisode': {'episode': 5, 'airingAt': now + 2 * 86400, 'timeUntilAiring': 2 * 86400},
            'synonyms': ['Frieren at the Funeral'],
            'tags': [
              {'id': 1, 'name': 'Travel', 'rank': 96, 'isMediaSpoiler': false, 'isGeneralSpoiler': false},
              {'id': 2, 'name': 'Time Skip', 'rank': 82, 'isMediaSpoiler': true, 'isGeneralSpoiler': false},
            ],
            'externalLinks': [
              for (final (i, site) in ['Crunchyroll', 'Netflix', 'Hulu', 'Prime', 'HIDIVE', 'Bilibili', 'Muse'].indexed)
                {'id': i, 'url': 'https://example.com/$i', 'site': site, 'type': 'STREAMING'},
              {'id': 9, 'url': 'https://frieren-anime.jp', 'site': 'Official Site', 'type': 'INFO'},
            ],
          }),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(Mode.anime), home: const DetailScreen(id: 1)),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Frieren'), findsWidgets);
    expect(find.bySemanticsLabel(RegExp('Remind me when episode 5 airs')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Add to favourites')), findsOneWidget);

    // where to watch: the first six, then "1 more"
    expect(find.text('WHERE TO WATCH'), findsOneWidget);
    expect(find.text('Muse'), findsNothing);
    await tester.ensureVisible(find.text('1 more'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('1 more'));
    await tester.pumpAndSettle();
    expect(find.text('Muse'), findsOneWidget);

    // tags: the spoiler hides until asked for
    await tester.scrollUntilVisible(find.text('Travel'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Time Skip'), findsNothing);
    await tester.tap(find.text('Show 1 spoiler'));
    await tester.pumpAndSettle();
    expect(find.text('Time Skip'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Frieren at the Funeral'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Official Site'), findsOneWidget);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('the open tab is brought fully into view on a phone', (tester) async {
    final container = await testContainer(
      overrides: [
        sessionProvider.overrideWith(_SignedOut.new),
        detailProvider.overrideWith(
          (ref, id) async => createDetailContent({
            'id': id,
            'type': 'ANIME',
            'format': 'TV',
            'title': {'romaji': 'Sousou no Frieren', 'userPreferred': 'Frieren'},
            'coverImage': <String, Object>{},
          }),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(Mode.anime), home: const DetailScreen(id: 1)),
      ),
    );
    await tester.pumpAndSettle();
    final tab = find.text('Recommendations');
    await tester.scrollUntilVisible(find.text('Overview'), 200, scrollable: find.byType(Scrollable).first);
    // four tabs are wider than the phone: the last one starts cut off
    expect(tester.getRect(tab).right, greaterThan(402));

    // the "All →" links and taps both open tabs; a tap on what shows of it
    final rect = tester.getRect(tab);
    await tester.tapAt(Offset((rect.left + 402) / 2, rect.center.dy));
    await tester.pumpAndSettle();
    expect(tester.getRect(tab).right, lessThanOrEqualTo(402));
    expect(tester.getRect(tab).left, greaterThanOrEqualTo(0));

    // and back: the tab cut off at the left edge comes fully in when tapped
    final labels = ['Overview', 'Relations', 'Characters & Staff', 'Stats'];
    final cut = labels.firstWhere((l) {
      final r = tester.getRect(find.text(l));
      return r.left < 0 && r.right > 0;
    });
    final c = tester.getRect(find.text(cut));
    await tester.tapAt(Offset(c.right / 2, c.center.dy));
    await tester.pumpAndSettle();
    expect(tester.getRect(find.text(cut)).left, greaterThanOrEqualTo(0));

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('the Stats tab: rankings, lists and scores, loaded when it opens', (tester) async {
    final semantics = tester.ensureSemantics();
    var statsLoads = 0;
    final container = await testContainer(
      overrides: [
        sessionProvider.overrideWith(_SignedOut.new),
        detailProvider.overrideWith(
          (ref, id) async => createDetailContent({
            'id': id,
            'type': 'ANIME',
            'format': 'TV',
            // scored, as the first test: an unscored title's headline "★ —" is a
            // hairline dash that CI's contrast check misreads against the banner
            'averageScore': 87,
            'title': {'romaji': 'Sousou no Frieren', 'userPreferred': 'Frieren'},
            'coverImage': {'color': '#e4a15d'},
          }),
        ),
        titleStatsProvider.overrideWith((ref, id) async {
          statsLoads++;
          return {
            'id': id,
            'averageScore': 91,
            'favourites': 12345,
            'stats': {
              'scoreDistribution': [
                {'score': 100, 'amount': 10000},
                {'score': 90, 'amount': 5000},
              ],
              'statusDistribution': [
                {'status': 'CURRENT', 'amount': 3000},
                {'status': 'COMPLETED', 'amount': 6000},
                {'status': 'PLANNING', 'amount': 1000},
              ],
            },
            'rankings': [
              {'id': 1, 'rank': 1, 'type': 'RATED', 'format': 'TV', 'allTime': true, 'context': ''},
              {
                'id': 2,
                'rank': 3,
                'type': 'POPULAR',
                'format': 'TV',
                'season': 'FALL',
                'year': 2023,
                'allTime': false,
                'context': '',
              },
            ],
          };
        }),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(Mode.anime), home: const DetailScreen(id: 1)),
      ),
    );
    await tester.pumpAndSettle();
    // not fetched until the tab opens
    expect(statsLoads, 0);
    await tester.scrollUntilVisible(find.text('Stats'), 200, scrollable: find.byType(Scrollable).first);
    final tab = tester.getRect(find.text('Stats'));
    await tester.tapAt(Offset((tab.left + tab.right.clamp(0, 402)) / 2, tab.center.dy));
    await tester.pumpAndSettle();
    expect(statsLoads, 1);

    expect(find.text('#1'), findsOneWidget);
    expect(find.text('Highest rated'), findsOneWidget);
    expect(find.text('Fall 2023 · TV'), findsOneWidget);
    expect(find.text('10k people'), findsOneWidget);
    expect(find.text('Watching'), findsOneWidget);
    expect(find.text('Average 9.1'), findsOneWidget);
    expect(find.text('15k scores'), findsOneWidget);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    semantics.dispose();

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('opening a manga switches the mode to Manga, once: switching back by hand stays', (tester) async {
    final container = await testContainer(
      overrides: [
        sessionProvider.overrideWith(_SignedOut.new),
        detailProvider.overrideWith(
          (ref, id) async => createDetailContent({
            'id': id,
            'type': 'MANGA',
            'format': 'MANGA',
            'title': {'romaji': 'Dandadan', 'userPreferred': 'Dandadan'},
            'coverImage': <String, Object>{},
          }),
        ),
      ],
    );
    expect(container.read(modeProvider), Mode.anime);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(Mode.anime), home: const DetailScreen(id: 7)),
      ),
    );
    await tester.pumpAndSettle();
    expect(container.read(modeProvider), Mode.manga);

    container.read(modeProvider.notifier).set(Mode.anime);
    await tester.pumpAndSettle();
    expect(container.read(modeProvider), Mode.anime);

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });

  testWidgets('tags fold to the best-fitting eight, open on request, and all open with spoilers', (tester) async {
    final semantics = tester.ensureSemantics();
    final names = ['Travel', 'Magic', 'Elf', 'Female Protagonist', 'Medieval', 'Iyashikei', 'Episodic', 'Demons'];
    final container = await testContainer(
      overrides: [
        sessionProvider.overrideWith(_SignedOut.new),
        detailProvider.overrideWith(
          (ref, id) async => createDetailContent({
            'id': id,
            'type': 'ANIME',
            'format': 'TV',
            // scored, as the first test: an unscored title's headline "★ —" is a
            // hairline dash that CI's contrast check misreads against the banner
            'averageScore': 87,
            'title': {'romaji': 'Sousou no Frieren', 'userPreferred': 'Frieren'},
            'coverImage': <String, Object>{},
            'tags': [
              for (final (i, n) in [...names, 'Coming of Age', 'Philosophy'].indexed)
                {'id': i, 'name': n, 'rank': 96 - i * 4, 'isMediaSpoiler': false, 'isGeneralSpoiler': false},
              {'id': 99, 'name': 'Time Skip', 'rank': 82, 'isMediaSpoiler': true, 'isGeneralSpoiler': false},
            ],
          }),
        ),
      ],
    );
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(theme: buildTheme(Mode.anime), home: const DetailScreen(id: 1)),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('2 more'), 200, scrollable: find.byType(Scrollable).first);
    for (final n in names) {
      expect(find.text(n), findsOneWidget, reason: n);
    }
    expect(find.text('Philosophy'), findsNothing);
    expect(find.text('Time Skip'), findsNothing);

    await tester.tap(find.text('2 more'));
    await tester.pumpAndSettle();
    expect(find.text('Philosophy'), findsOneWidget);
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    await tester.tap(find.text('Show fewer'));
    await tester.pumpAndSettle();
    expect(find.text('Philosophy'), findsNothing);

    // showing spoilers shows every tag, so one ranked low isn't left folded away
    await tester.tap(find.text('Show 1 spoiler'));
    await tester.pumpAndSettle();
    expect(find.text('Time Skip'), findsOneWidget);
    expect(find.text('Philosophy'), findsOneWidget);
    expect(find.text('Show fewer'), findsOneWidget);
    semantics.dispose();

    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
