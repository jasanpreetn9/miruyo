import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miruyo/core/anilist/client.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/auth/session.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/features/browse/browse_screen.dart';

import '../helpers.dart';

class _SignedOut extends Session {
  @override
  SessionState build() => const SessionState(authState: AuthState.signedOut);
}

void main() {
  /// The variables of every Browse request, in order.
  late List<Json> browsed;

  Json media(int id) => {
    'id': id,
    'type': 'ANIME',
    'format': 'TV',
    'title': {'english': 'Show $id', 'romaji': 'Show $id'},
    'coverImage': <String, Object>{},
  };

  AniListClient client() => AniListClient(
    httpClient: MockClient((req) async {
      final body = jsonDecode(req.body) as Json;
      final name = RegExp(r'query\s+(\w+)').firstMatch(body['query'] as String)![1]!;
      final data = switch (name) {
        'Browse' => () {
          final variables = body['variables'] as Json;
          browsed.add(variables);
          // a search finds eight, enough to run past the people
          final count = variables['search'] == null ? 3 : 8;
          return {
            'Page': {
              'pageInfo': {'total': count, 'currentPage': 1, 'hasNextPage': false},
              'media': [for (var id = 1; id <= count; id++) media(id)],
            },
          };
        }(),
        'BrowseCollections' => {
          'GenreCollection': ['Action', 'Romance'],
          'MediaTagCollection': <Json>[],
        },
        'SearchPeople' => {
          'characters': {
            'characters': [
              {
                'id': 7,
                'name': {'userPreferred': 'Frieren'},
                'image': null,
                'media': {'nodes': <Json>[]},
              },
            ],
          },
          'staff': {'staff': <Json>[]},
          'users': {
            'users': [
              {'id': 5001, 'name': 'frieren fan', 'avatar': null},
            ],
          },
          'studios': {'studios': <Json>[]},
        },
        _ => <String, Object>{},
      };
      return http.Response(jsonEncode({'data': data}), 200, headers: {'content-type': 'application/json'});
    }),
  );

  Future<ProviderContainer> pump(WidgetTester tester) async {
    final container = await testContainer(client: client(), overrides: [sessionProvider.overrideWith(_SignedOut.new)]);
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, state) => Scaffold(body: BrowseScreen(query: state.uri.queryParametersAll)),
        ),
        GoRoute(
          path: '/character/:id',
          builder: (_, state) => Scaffold(body: Text('character ${state.pathParameters['id']}')),
        ),
        GoRoute(
          path: '/user/:name',
          builder: (_, state) => Scaffold(body: Text('user ${state.pathParameters['name']}')),
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
    return container;
  }

  Future<void> close(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  setUp(() => browsed = []);

  testWidgets('ready-made lists: Top rated ranks its results, Newest does not', (tester) async {
    final container = await pump(tester);
    expect(find.text('All-time popular'), findsOneWidget);
    // plain Browse is the all-time popular list: ranked
    expect(find.text('#1'), findsOneWidget);

    await tester.tap(find.text('Top rated'));
    await tester.pumpAndSettle();
    expect(browsed.last['sort'], ['SCORE_DESC']);
    expect(find.text('Top-rated anime'), findsOneWidget);
    expect(find.text('#3'), findsOneWidget);

    await tester.dragUntilVisible(find.text('Upcoming'), find.text('Top rated'), const Offset(-120, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Upcoming'));
    await tester.pumpAndSettle();
    expect(browsed.last['status'], 'NOT_YET_RELEASED');
    expect(find.text('Upcoming anime'), findsOneWidget);
    await close(tester, container);
  });

  testWidgets('a search also shows the characters and users it matches, which open their pages', (tester) async {
    final container = await pump(tester);
    await tester.enterText(find.byType(TextField), 'frieren');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pumpAndSettle();
    // searching: no presets, no ranks
    expect(find.text('All-time popular'), findsNothing);
    expect(find.text('#1'), findsNothing);
    expect(find.text('CHARACTERS'), findsOneWidget);
    // titles come first: people follow two rows of them, then the rest carry on
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Show 6'), lessThan(top('CHARACTERS')));
    await tester.dragUntilVisible(find.text('Show 7'), find.byType(CustomScrollView), const Offset(0, -200));
    expect(top('Show 7'), greaterThan(top('CHARACTERS')));
    await tester.drag(find.byType(CustomScrollView), const Offset(0, 2000));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Frieren'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Frieren'));
    await tester.pumpAndSettle();
    expect(find.text('character 7'), findsOneWidget);

    // a user opens their page
    tester.state<NavigatorState>(find.byType(Navigator).last).pop();
    await tester.pumpAndSettle();
    expect(find.text('USERS'), findsOneWidget);
    await tester.ensureVisible(find.text('frieren fan'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('frieren fan'));
    await tester.pumpAndSettle();
    expect(find.text('user frieren fan'), findsOneWidget);
    await close(tester, container);
  });

  testWidgets('a genre goes in on the first tap, out on the second, and off on the third', (tester) async {
    final semantics = tester.ensureSemantics();
    final container = await pump(tester);
    await tester.tap(find.text('Filters'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Romance'),
      200,
      scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('Tap twice to exclude'), findsOneWidget);

    final romance = find.text('Romance');
    await tester.tap(romance);
    await tester.pumpAndSettle();
    await tester.tap(romance);
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Not Romance'), findsOneWidget);
    await tester.tap(find.text('Romance'));
    await tester.pumpAndSettle();
    expect(find.bySemanticsLabel('Not Romance'), findsNothing);

    // applied, the exclusion reaches AniList and shows as a chip
    await tester.tap(romance);
    await tester.pumpAndSettle();
    await tester.tap(romance);
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byType(FilledButton), matching: find.byType(Text)));
    await tester.pumpAndSettle();
    expect(browsed.last['notGenres'], ['Romance']);
    expect(find.text('Not Romance'), findsOneWidget);
    semantics.dispose();
    await close(tester, container);
  });
}
