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
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/features/person/character_screen.dart';
import 'package:miruyo/features/person/staff_screen.dart';

import '../../helpers.dart';
import 'person_data_test.dart' show character, personMedia, role, staff, voice;

void main() {
  /// AniList, answering by operation name; [asked] records each one.
  late List<String> asked;
  late Map<String, Json Function(Json variables)> answers;

  AniListClient client() => AniListClient(
    httpClient: MockClient((req) async {
      final body = jsonDecode(req.body) as Json;
      final name = RegExp(r'(?:query|mutation)\s+(\w+)').firstMatch(body['query'] as String)![1]!;
      asked.add(name);
      final answer = answers[name];
      return http.Response(
        jsonEncode({'data': answer == null ? <String, Object>{} : answer(body['variables'] as Json)}),
        200,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );
    }),
  );

  Json voicePage(int page, {required bool more}) => {
    'pageInfo': {'total': 30, 'hasNextPage': more},
    'edges': [
      for (var i = 0; i < 3; i++)
        {
          'characterRole': 'MAIN',
          'characters': [role(page * 100 + i, 'Character $page.$i')],
          'node': personMedia({
            'id': page * 100 + i,
            'title': {'english': 'Show $page.$i'},
            'coverImage': {'large': null, 'color': '#d9a75e'},
          }),
        },
    ],
  };

  Future<ProviderContainer> pump(WidgetTester tester, String location) async {
    final container = await testContainer(client: client());
    final router = GoRouter(
      initialLocation: location,
      routes: [
        GoRoute(
          path: '/staff/:id',
          builder: (_, state) => StaffScreen(id: int.parse(state.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/character/:id',
          builder: (_, state) => CharacterScreen(id: int.parse(state.pathParameters['id']!)),
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
    return container;
  }

  Future<void> close(WidgetTester tester, ProviderContainer container) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  Finder page() => find.byType(Scrollable).first;

  setUp(() {
    asked = [];
    answers = {};
  });

  testWidgets('a staff page: who they are, their voice roles, Load more, and a role opens its character', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    answers['StaffPage'] = (v) => {
      'Staff': staff({
        'name': {
          'full': 'Atsumi Tanezaki',
          // Latin: the test font has no kana, and its boxes fail the contrast check
          'native': 'TANEZAKI Atsumi',
          'userPreferred': 'Atsumi Tanezaki',
          'alternative': ['Hana Kiritani'],
        },
        // no pictures: the image cache needs the device's file system
        'image': null,
        'description': 'A voice actress, best known as [Frieren](https://anilist.co/character/176754).',
        'characterMedia': voicePage(1, more: true),
      }),
    };
    answers['StaffVoiceRoles'] = (v) => {
      'Staff': {'id': 112215, 'characterMedia': voicePage(v['page'] as int, more: false)},
    };
    final container = await pump(tester, '/staff/112215');

    expect(find.text('Atsumi Tanezaki'), findsOneWidget);
    expect(find.text('TANEZAKI Atsumi'), findsOneWidget);
    expect(find.textContaining('Hana Kiritani'), findsOneWidget);
    expect(find.text('Voice actor'), findsNothing);
    await tester.scrollUntilVisible(find.text('Voice roles'), 200, scrollable: page());
    expect(find.text('Popular'), findsOneWidget);
    expect(find.text('Show 1.0'), findsOneWidget);
    // checked at rest: mid-scroll, the sort's selected segment is still fading in
    await tester.pumpAndSettle();

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.scrollUntilVisible(find.text('Load more'), 200, scrollable: page());
    await tester.tap(find.text('Load more'));
    await tester.pumpAndSettle();
    expect(asked, contains('StaffVoiceRoles'));
    await tester.scrollUntilVisible(find.text('Show 2.2'), 200, scrollable: page());
    expect(find.text('Load more'), findsNothing);

    await tester.ensureVisible(find.text('Show 2.2'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show 2.2'));
    await tester.pumpAndSettle();
    expect(find.text('title 202'), findsOneWidget);

    semantics.dispose();
    await close(tester, container);
  });

  testWidgets('a character page shows one language of voice actors at a time, Japanese first', (tester) async {
    answers['CharacterPage'] = (v) => {
      'Character': character({
        'name': {
          'full': 'Frieren',
          'native': 'フリーレン',
          'userPreferred': 'Frieren',
          'alternative': <String>[],
          'alternativeSpoiler': ['Great Mage'],
        },
        'media': {
          'pageInfo': {'total': 1, 'hasNextPage': false},
          'edges': [
            {
              'characterRole': 'MAIN',
              'voiceActorRoles': [voice(1, 'Atsumi Tanezaki', 'Japanese'), voice(2, 'Mallorie Rodak', 'English')],
              'node': personMedia({
                'id': 1,
                'coverImage': {'large': null, 'color': null},
              }),
            },
          ],
        },
      }),
    };
    final container = await pump(tester, '/character/176754');

    // spoiler names wait to be asked for
    expect(find.text('Great Mage'), findsNothing);
    await tester.tap(find.text('Show 1 spoiler name'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Great Mage'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Appears in'), 200, scrollable: page());
    await tester.scrollUntilVisible(find.text('Atsumi Tanezaki'), 200, scrollable: page());
    expect(find.text('Mallorie Rodak'), findsNothing);

    await tester.tap(find.text('Japanese'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English').last);
    await tester.pumpAndSettle();
    expect(find.text('Mallorie Rodak'), findsOneWidget);
    expect(find.text('Atsumi Tanezaki'), findsNothing);

    await close(tester, container);
  });
}
