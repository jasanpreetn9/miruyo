import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miruyo/core/anilist/client.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/auth/session.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/providers.dart';
import 'package:miruyo/core/storage/prefs.dart';
import 'package:miruyo/features/browse/browse_controller.dart';
import 'package:miruyo/features/browse/browse_params.dart';

import '../helpers.dart';

Json media(int id) => {
  'id': id,
  'type': 'ANIME',
  'title': {'romaji': 'Title $id'},
  'coverImage': <String, Object>{},
};

/// A token store whose read waits until the test lets it finish, so the
/// session stays "checking" for as long as the test needs.
class SlowTokenStore extends MemoryTokenStore {
  final gate = Completer<void>();

  @override
  Future<String?> read() async {
    await gate.future;
    return token;
  }
}

void main() {
  late List<Json> sent;

  AniListClient client({bool hasNext = true}) => AniListClient(
    httpClient: MockClient((req) async {
      final vars = (jsonDecode(req.body) as Json)['variables'] as Json;
      sent.add(vars);
      final page = vars['page'] as int? ?? 1;
      return http.Response(
        jsonEncode({
          'data': {
            'Page': {
              'pageInfo': {'total': 60, 'currentPage': page, 'hasNextPage': hasNext && page < 2},
              'media': [for (var i = 0; i < 3; i++) media(page * 10 + i)],
            },
          },
        }),
        200,
      );
    }),
  );

  Future<void> settle() async {
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
  }

  setUp(() => sent = []);

  test('opened while the session is still checking, it loads once the session settles', () async {
    final tokens = SlowTokenStore();
    final container = await testContainer(client: client(), overrides: [tokenStoreProvider.overrideWithValue(tokens)]);
    addTearDown(container.dispose);
    container.read(sessionProvider);
    container.listen(browseProvider, (_, _) {});
    await settle();
    expect(container.read(sessionProvider).authState, AuthState.loading);
    expect(container.read(browseProvider).firstLoad, isTrue);
    expect(sent, isEmpty);

    tokens.gate.complete();
    await settle();
    expect(container.read(sessionProvider).authState, AuthState.signedOut);
    expect(container.read(browseProvider).results, hasLength(3));
  });

  test('loads more pages, then stops at the last', () async {
    final container = await testContainer(
      client: client(),
      overrides: [tokenStoreProvider.overrideWithValue(MemoryTokenStore())],
    );
    addTearDown(container.dispose);
    container.read(sessionProvider);
    container.listen(browseProvider, (_, _) {});
    await settle();
    final controller = container.read(browseProvider.notifier);
    await controller.loadMore();
    expect(container.read(browseProvider).results, hasLength(6));
    expect(container.read(browseProvider).hasMore, isFalse);
    await controller.loadMore();
    expect(sent.where((v) => v['page'] == 3), isEmpty);
  });

  test('a new filter starts over and sends it', () async {
    final container = await testContainer(
      client: client(),
      overrides: [tokenStoreProvider.overrideWithValue(MemoryTokenStore())],
    );
    addTearDown(container.dispose);
    container.read(sessionProvider);
    container.listen(browseProvider, (_, _) {});
    await settle();
    container.read(browseProvider.notifier).apply(const BrowseState(sort: BrowseSort.trending, genres: ['Drama']));
    await settle();
    expect(sent.last['sort'], ['TRENDING_DESC']);
    expect(sent.last['genres'], ['Drama']);
    expect(container.read(browseProvider).results, hasLength(3));
  });

  test('switching mode reloads for the other type, even with no filters', () async {
    final container = await testContainer(
      client: client(),
      overrides: [tokenStoreProvider.overrideWithValue(MemoryTokenStore())],
    );
    addTearDown(container.dispose);
    container.read(sessionProvider);
    container.listen(browseProvider, (_, _) {});
    await settle();
    expect(sent.last['type'], 'ANIME');
    container.read(modeProvider.notifier).set(Mode.manga);
    await settle();
    expect(sent.last['type'], 'MANGA');
    expect(container.read(browseProvider).results, hasLength(3));
  });

  group('Did you mean', () {
    const names = ['Sousou no Frieren', "Frieren: Beyond Journey's End", 'Fire Force', 'Fruits Basket'];

    test('finds the word a typo was reaching for', () {
      expect(closestSpelling('frerien', names), 'Frieren');
      expect(closestSpelling('fruts basket', names), 'Fruits Basket');
      expect(typoDistance('teh', 'the'), 1);
    });

    test('says nothing for an exact word, or when nothing is close', () {
      expect(closestSpelling('frieren', names), isNull);
      expect(closestSpelling('zzzzzz', names), isNull);
      expect(closestSpelling('fr', names), isNull);
    });
  });

  test('tag search: up to 8, those starting with it first, not ones chosen', () {
    const tags = ['Male Protagonist', 'Female Protagonist', 'Elf', 'Shapeshifting', 'Elves', 'Self-Discovery'];
    expect(matchTags(tags, 'el', const []), ['Elf', 'Elves', 'Self-Discovery']);
    expect(matchTags(tags, 'protag', const ['Female Protagonist']), ['Male Protagonist']);
    expect(matchTags(tags, '  ', const []), isEmpty);
  });
}
