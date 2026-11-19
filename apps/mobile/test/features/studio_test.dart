// Ported from apps/web/src/lib/page-data/studio.test.ts, plus the screen.

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miruyo/core/anilist/client.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/catalog/title.dart';
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/features/studio/studio_data.dart';
import 'package:miruyo/features/studio/studio_screen.dart';

import '../helpers.dart';
import 'person_data_test.dart' show personMedia;

Json studio([Json overrides = const {}]) => {
  'id': 11,
  'name': 'MADHOUSE',
  'isAnimationStudio': true,
  'siteUrl': 'https://anilist.co/studio/11',
  'favourites': 20029,
  'isFavourite': false,
  'media': {
    'pageInfo': {'total': 500, 'hasNextPage': true},
    'edges': <Json>[],
  },
  ...overrides,
};

Json edge(int id, {bool main = true, Json extra = const {}}) => {
  'isMainStudio': main,
  'node': personMedia({'id': id, ...extra}),
};

void main() {
  group('createStudioContent', () {
    test('says what the studio is, with its favourites and AniList link', () {
      final content = createStudioContent(studio());
      expect(content.header.name, 'MADHOUSE');
      expect(content.kind, 'Animation studio');
      expect(content.header.favourites, '20k');
      expect(content.header.anilist.toString(), 'https://anilist.co/studio/11');
      expect(content.hasMore, isTrue);
      expect(createStudioContent(studio({'isAnimationStudio': false})).kind, 'Studio');
      // a link that isn't AniList's falls back to its studio address
      expect(
        createStudioContent(studio({'siteUrl': 'https://evil.example/11'})).header.anilist.toString(),
        'https://anilist.co/studio/11',
      );
    });

    test('lists its titles once each, marking the ones it only produced', () {
      final content = createStudioContent(
        studio({
          'media': {
            'pageInfo': {'total': 3, 'hasNextPage': false},
            'edges': [
              edge(1),
              edge(2, main: false, extra: {'format': 'MOVIE'}),
              edge(1),
            ],
          },
        }),
        titles: TitlePreference.english,
      );
      expect(content.titles.map((t) => (t.key, t.caption, t.media.meta)), [
        ('1', null, '2023 · TV'),
        ('2', 'Producer', '2023 · Movie'),
      ]);
      expect(content.titles.first.media.title, 'English Title');
      expect(content.hasMore, isFalse);
    });

    test('leaves 18+ titles out unless the account shows them', () {
      final data = studio({
        'media': {
          'pageInfo': {'total': 2, 'hasNextPage': false},
          'edges': [
            edge(1),
            edge(2, extra: {'isAdult': true}),
          ],
        },
      });
      expect(createStudioContent(data).titles.map((t) => t.key), ['1']);
      expect(createStudioContent(data, adult: true).titles.map((t) => t.key), ['1', '2']);
    });
  });

  group('the studio screen', () {
    late List<String> asked;

    Json page(int n, {required bool more}) => {
      'pageInfo': {'total': 30, 'hasNextPage': more},
      'edges': [
        for (var i = 0; i < 3; i++)
          edge(
            n * 100 + i,
            main: !(n == 1 && i == 2),
            extra: {
              'title': {'english': 'Show $n.$i'},
              'coverImage': {'large': null, 'color': '#d9a75e'},
            },
          ),
      ],
    };

    AniListClient client() => AniListClient(
      httpClient: MockClient((req) async {
        final body = jsonDecode(req.body) as Json;
        final name = RegExp(r'(?:query|mutation)\s+(\w+)').firstMatch(body['query'] as String)![1]!;
        asked.add(name);
        final v = body['variables'] as Json;
        final data = switch (name) {
          'StudioPage' => {
            'Studio': studio({'media': page(1, more: true)}),
          },
          'StudioMedia' => {
            'Studio': {'id': 11, 'media': page(v['page'] as int, more: false)},
          },
          _ => <String, Object>{},
        };
        return http.Response(
          jsonEncode({'data': data}),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );

    setUp(() => asked = []);

    testWidgets('who it is, its titles with Producer marked, Load more, and a title opens', (tester) async {
      final semantics = tester.ensureSemantics();
      final container = await testContainer(client: client());
      final router = GoRouter(
        initialLocation: '/studio/11',
        routes: [
          GoRoute(
            path: '/studio/:id',
            builder: (_, state) => StudioScreen(id: int.parse(state.pathParameters['id']!)),
          ),
          GoRoute(
            path: '/title/:id',
            builder: (_, state) => Scaffold(body: Text('title ${state.pathParameters['id']}')),
          ),
        ],
      );
      await tester.binding.setSurfaceSize(const Size(402, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(theme: buildTheme(Mode.anime), routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      final scroll = find.byType(Scrollable).first;

      expect(find.text('MADHOUSE'), findsOneWidget);
      expect(find.text('Animation studio'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Show 1.0'), 200, scrollable: scroll);
      expect(find.text('Titles'), findsOneWidget);
      expect(find.text('Popular'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Producer'), 200, scrollable: scroll);
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await tester.scrollUntilVisible(find.text('Load more'), 200, scrollable: scroll);
      await tester.tap(find.text('Load more'));
      await tester.pumpAndSettle();
      expect(asked, contains('StudioMedia'));
      await tester.scrollUntilVisible(find.text('Show 2.2'), 200, scrollable: scroll);
      expect(find.text('Load more'), findsNothing);

      await tester.ensureVisible(find.text('Show 2.2'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Show 2.2'));
      await tester.pumpAndSettle();
      expect(find.text('title 202'), findsOneWidget);

      semantics.dispose();
      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  });
}
