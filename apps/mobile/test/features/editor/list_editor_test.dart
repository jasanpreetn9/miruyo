import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miruyo/core/anilist/client.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/auth/session.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/catalog/title.dart';
import 'package:miruyo/core/list/list_entry.dart';
import 'package:miruyo/core/list/list_store.dart';
import 'package:miruyo/core/theme/app_theme.dart';
import 'package:miruyo/features/editor/list_editor.dart';

import '../../helpers.dart';
import '../for_you/for_you_data_test.dart' show media;

/// Signed in, with three custom anime lists (one of them empty).
class _SignedIn extends Session {
  @override
  SessionState build() => const SessionState(
    authState: AuthState.signedIn,
    user: AniListUser(
      id: 1,
      name: 'rin',
      scoreFormat: ScoreFormat.point10Decimal,
      animeCustomLists: ['Rewatch someday', 'Comfort shows', 'Empty one'],
    ),
  );
}

void main() {
  late FakeEditApi api;
  late ProviderContainer container;

  /// Opens the editor on title 1 (Watching, EP 7, on 'Rewatch someday').
  /// With [hold], the full entry only arrives once it completes.
  Future<void> open(WidgetTester tester, {Completer<void>? hold}) async {
    api = FakeEditApi();
    final client = AniListClient(
      httpClient: MockClient((req) async {
        final query = (jsonDecode(req.body) as Json)['query'] as String;
        if (query.contains('query Entry')) await hold?.future;
        final data = query.contains('query Entry')
            ? {
                'MediaList': {
                  'id': 10,
                  'mediaId': 1,
                  'status': 'CURRENT',
                  'progress': 7,
                  'score': 8,
                  'customLists': [
                    {'name': 'Rewatch someday', 'enabled': true},
                    {'name': 'Comfort shows', 'enabled': false},
                    {'name': 'Empty one', 'enabled': false},
                  ],
                },
              }
            : <String, Object>{};
        return http.Response(jsonEncode({'data': data}), 200, headers: {'content-type': 'application/json'});
      }),
    );
    container = await testContainer(api: api, client: client, overrides: [sessionProvider.overrideWith(_SignedIn.new)]);
    final store = container.read(listStoreProvider.notifier)..sync = true;
    store.seed([const ListEntry(id: 10, mediaId: 1, status: MediaListStatus.current, progress: 7)]);
    final title = adaptMedia(AniListMedia.fromJson(media(1, 'Frieren', extra: {'episodes': 28})));
    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(Mode.anime),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(onPressed: () => showListEditor(context, ref, title), child: const Text('Edit')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  }

  Finder chip(String name) => find.widgetWithText(FilterChip, name, skipOffstage: false);

  testWidgets("before the full entry arrives, chips wait and a +1 doesn't wipe the lists", (tester) async {
    final hold = Completer<void>();
    await open(tester, hold: hold);
    // toggling now would save a set without 'Rewatch someday'
    expect(tester.widget<FilterChip>(chip('Comfort shows')).onSelected, isNull);

    await tester.tap(find.bySemanticsLabel('Add one episode'));
    await tester.pump(const Duration(seconds: 1)); // past the stepper's debounce
    await tester.pumpAndSettle();
    expect(api.saves.last.$2, {'progress': 8});

    hold.complete();
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(chip('Rewatch someday')).selected, isTrue);
    await tester.ensureVisible(chip('Comfort shows'));
    await tester.pumpAndSettle();
    await tester.tap(chip('Comfort shows'));
    await tester.pumpAndSettle();
    // the lists it was on stay, and the +1 isn't sent again
    expect(api.saves.last.$2, {
      'customLists': ['Rewatch someday', 'Comfort shows'],
    });
    await close(tester);
  });

  testWidgets('closing right after a chip tap saves it without an error', (tester) async {
    await open(tester);
    await tester.ensureVisible(chip('Empty one'));
    await tester.pumpAndSettle();
    await tester.tap(chip('Empty one'));
    await tester.pump();
    // as Done does; the list scrolled the header away
    unawaited(tester.state<NavigatorState>(find.byType(Navigator)).maybePop());
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(api.saves.last.$2['customLists'], ['Rewatch someday', 'Empty one']);
    await close(tester);
  });

  testWidgets('the editor puts a title on a custom list and saves the whole set', (tester) async {
    final semantics = tester.ensureSemantics();
    final api = FakeEditApi();
    final client = AniListClient(
      httpClient: MockClient((req) async {
        final query = (jsonDecode(req.body) as Json)['query'] as String;
        final data = query.contains('query Entry')
            ? {
                'MediaList': {
                  'id': 10,
                  'mediaId': 1,
                  'status': 'CURRENT',
                  'progress': 7,
                  'customLists': [
                    {'name': 'Rewatch someday', 'enabled': true},
                    {'name': 'Comfort shows', 'enabled': false},
                    {'name': 'Empty one', 'enabled': false},
                  ],
                },
              }
            : <String, Object>{};
        return http.Response(jsonEncode({'data': data}), 200, headers: {'content-type': 'application/json'});
      }),
    );
    final container = await testContainer(
      api: api,
      client: client,
      overrides: [sessionProvider.overrideWith(_SignedIn.new)],
    );
    final store = container.read(listStoreProvider.notifier)..sync = true;
    store.seed([const ListEntry(id: 10, mediaId: 1, status: MediaListStatus.current, progress: 7)]);
    final title = adaptMedia(AniListMedia.fromJson(media(1, 'Frieren', extra: {'episodes': 28})));

    await tester.binding.setSurfaceSize(const Size(402, 874));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: buildTheme(Mode.anime),
          home: Consumer(
            builder: (context, ref, _) => Scaffold(
              body: Center(
                child: TextButton(onPressed: () => showListEditor(context, ref, title), child: const Text('Edit')),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Edit'));
    await tester.pumpAndSettle();

    final chip = find.widgetWithText(FilterChip, 'Empty one', skipOffstage: false);
    await tester.ensureVisible(chip);
    await tester.pumpAndSettle();
    expect(find.text('CUSTOM LISTS'), findsOneWidget);
    expect(tester.widget<FilterChip>(find.widgetWithText(FilterChip, 'Rewatch someday')).selected, isTrue);
    expect(tester.widget<FilterChip>(chip).selected, isFalse);

    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));

    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(tester.widget<FilterChip>(chip).selected, isTrue);
    // saved at once, as the whole set in the account's order, and nothing else
    expect(api.saves.last.$1, 1);
    expect(api.saves.last.$2, {
      'customLists': ['Rewatch someday', 'Empty one'],
    });

    semantics.dispose();
    await tester.pumpWidget(const SizedBox());
    container.dispose();
  });
}
