// Ported from the web's client.test.ts, plus the native-only behaviour:
// real network errors, the device copy of persisted queries.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miruyo/core/anilist/client.dart';
import 'package:miruyo/core/anilist/errors.dart';
import 'package:miruyo/core/anilist/pacer.dart';
import 'package:miruyo/core/anilist/types.dart';

http.Response json(Object body, [int status = 200, Map<String, String> headers = const {}]) =>
    http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json', ...headers});

class FakeStore implements ResponseStore {
  final saved = <String, Json>{};

  @override
  Future<({Json data, DateTime savedAt})?> read(String key) async =>
      saved[key] == null ? null : (data: saved[key]!, savedAt: DateTime(2026, 10, 9, 8));

  @override
  Future<void> write(String key, Json data) async => saved[key] = data;

  @override
  Future<void> clear() async => saved.clear();
}

void main() {
  late List<http.Request> requests;
  late http.Response Function(http.Request) respond;
  late DateTime now;

  AniListClient client({ResponseStore? store}) {
    final c = AniListClient(
      httpClient: MockClient((req) async {
        requests.add(req);
        return respond(req);
      }),
      store: store,
      now: () => now,
      // waiting moves the fake clock, so a paced request never hangs
      pacer: Pacer(now: () => now, sleep: (d) async => now = now.add(d)),
    );
    return c;
  }

  Json body(int i) => jsonDecode(requests[i].body) as Json;

  Future<AniListError> caught(Future<Object?> f) async {
    try {
      await f;
    } on AniListError catch (e) {
      return e;
    }
    fail('expected the request to fail');
  }

  setUp(() {
    requests = [];
    now = DateTime(2026, 10, 9, 12);
    respond = (_) => json({'data': <String, Object>{}});
  });

  group('query errors', () {
    test('reports a 429 as a rate limit with the Retry-After delay', () async {
      respond = (_) => json(
        {
          'errors': [
            {'message': 'Too Many Requests.'},
          ],
        },
        429,
        {'retry-after': '12'},
      );
      final err = await caught(client().query('query A {}'));
      expect((err.kind, err.retryAfter), (AniListErrorKind.rateLimit, 12));
    });

    test('falls back to a minute when a 429 has no delay header', () async {
      respond = (_) => json({}, 429);
      expect((await caught(client().query('query A {}'))).retryAfter, 60);
    });

    test('reads the delay from X-RateLimit-Reset', () async {
      final reset = now.millisecondsSinceEpoch ~/ 1000 + 30;
      respond = (_) => json({}, 429, {'x-ratelimit-reset': '$reset'});
      expect((await caught(client().query('query A {}'))).retryAfter, 30);
    });

    test('reports a rejected token as unauthorized and tells the session', () async {
      var signedOut = 0;
      final c = client()
        ..token = 'stale-token'
        ..onUnauthorized = () => signedOut++;
      respond = (_) => json({
        'errors': [
          {'message': 'Invalid token', 'status': 400},
        ],
      }, 400);
      expect((await caught(c.query('query A {}'))).kind, AniListErrorKind.unauthorized);
      expect(signedOut, 1);
    });

    test("doesn't sign out over a permission error that isn't about the token", () async {
      var signedOut = 0;
      final c = client()
        ..token = 'good-token'
        ..onUnauthorized = () => signedOut++;
      respond = (_) => json({
        'errors': [
          {'message': 'Unauthorized.', 'status': 400},
        ],
      }, 400);
      expect((await caught(c.query('query A {}'))).kind, AniListErrorKind.api);
      expect(signedOut, 0);
    });

    test("doesn't treat a 401 on a token-less request as a sign-out", () async {
      var signedOut = 0;
      final c = client()..onUnauthorized = () => signedOut++;
      respond = (_) => json({
        'errors': [
          {'message': 'Unauthorized.'},
        ],
      }, 401);
      expect((await caught(c.query('query A {}', authToken: ''))).kind, AniListErrorKind.api);
      expect(signedOut, 0);
    });

    test('keeps AniList validation messages', () async {
      respond = (_) => json({
        'errors': [
          {'message': 'Bad field'},
        ],
      }, 400);
      final err = await caught(client().query('query A {}'));
      expect((err.kind, err.status, err.message), (AniListErrorKind.api, 400, 'Bad field'));
    });

    test('reports no connection as a network error', () async {
      respond = (_) => throw const SocketException('Failed host lookup');
      expect((await caught(client().query('query A {}'))).kind, AniListErrorKind.network);
    });

    test('sends no Authorization header without a token', () async {
      await client().query('query A {}');
      expect(requests.single.headers['Authorization'], isNull);
      final c = client()..token = 'tok';
      await c.query('query A {}');
      expect(requests.last.headers['Authorization'], 'Bearer tok');
      await c.query('query A {}', authToken: '');
      expect(requests.last.headers['Authorization'], isNull);
    });

    test('remembers the rate-limit budget AniList reports', () async {
      respond = (_) => json({'data': <String, Object>{}}, 200, {'x-ratelimit-remaining': '42'});
      final c = client();
      await c.query('query A {}');
      expect(c.pacer.left, 42);
    });

    test('after a 429, the next request waits out Retry-After', () async {
      respond = (_) => json(
        {
          'errors': [
            {'message': 'Too Many Requests.', 'status': 429},
          ],
        },
        429,
        {'retry-after': '30'},
      );
      final c = client();
      await caught(c.query('query A {}'));
      final before = now;
      respond = (_) => json({'data': <String, Object>{}});
      await c.query('query B {}');
      expect(now.difference(before), const Duration(seconds: 30));
    });
  });

  group('cachedQuery', () {
    test('merges identical requests that are in flight together', () async {
      respond = (_) => json({
        'data': {'n': 1},
      });
      final c = client();
      final results = await Future.wait([
        c.cachedQuery('query A {}', variables: {'x': 1}),
        c.cachedQuery('query A {}', variables: {'x': 1}),
      ]);
      expect(results[0], {'n': 1});
      expect(identical(results[0], results[1]), isTrue);
      expect(requests, hasLength(1));
    });

    test('keys on variables and token', () async {
      final c = client();
      await c.cachedQuery('query A {}', variables: {'x': 1});
      await c.cachedQuery('query A {}', variables: {'x': 2});
      await c.cachedQuery('query A {}', variables: {'x': 1}, authToken: 'someone-else');
      expect(requests, hasLength(3));
    });

    test('reuses a result until it expires', () async {
      final c = client();
      await c.cachedQuery('query A {}');
      await c.cachedQuery('query A {}');
      expect(requests, hasLength(1));
      now = now.add(cacheTtl + const Duration(milliseconds: 1));
      await c.cachedQuery('query A {}');
      expect(requests, hasLength(2));
    });

    test("doesn't cache failures", () async {
      final c = client();
      respond = (_) => json({}, 500);
      await expectLater(c.cachedQuery('query A {}'), throwsA(isA<AniListError>()));
      respond = (_) => json({
        'data': {'ok': true},
      });
      expect(await c.cachedQuery('query A {}'), {'ok': true});
    });

    test('drops viewer responses after a successful save, sending only changed fields', () async {
      respond = (req) => json({
        'data': (jsonDecode(req.body) as Json)['query'].toString().contains('SaveEntry')
            ? {
                'SaveMediaListEntry': {'id': 1, 'mediaId': 5, 'status': 'CURRENT', 'progress': 3},
              }
            : <String, Object>{},
      });
      final c = client()..token = 'tok';
      await c.cachedQuery('query A {}');
      await c.saveEntry(5, const EntryInput(progress: 3));
      await c.cachedQuery('query A {}');
      expect(requests, hasLength(3));
      expect(body(1)['variables'], {'mediaId': 5, 'progress': 3});
    });

    test('keeps public responses cached across a save', () async {
      respond = (req) => json({
        'data': (jsonDecode(req.body) as Json)['query'].toString().contains('SaveEntry')
            ? {
                'SaveMediaListEntry': {'id': 1, 'mediaId': 5, 'status': 'CURRENT', 'progress': 3},
              }
            : <String, Object>{},
      });
      final c = client()..token = 'tok';
      await c.cachedQuery('query Public {}', authToken: '');
      await c.cachedQuery('query Viewer {}');
      await c.saveEntry(5, const EntryInput(progress: 3));
      await c.cachedQuery('query Public {}', authToken: '');
      await c.cachedQuery('query Viewer {}');
      // public 1 + viewer 2 + save 1
      expect(requests, hasLength(4));
    });
  });

  test('updateViewerSettings sends only the settings being changed', () async {
    respond = (_) => json({
      'data': {
        'UpdateUser': {
          'id': 1,
          'options': {'titleLanguage': 'ENGLISH', 'displayAdultContent': false},
          'mediaListOptions': {'scoreFormat': 'POINT_10'},
        },
      },
    });
    final saved = await client().updateViewerSettings(const ViewerSettings(titleLanguage: TitleLanguage.english));
    expect(body(0)['query'], contains('mutation UpdateSettings'));
    expect(body(0)['variables'], {'titleLanguage': 'ENGLISH'});
    expect(saved.titleLanguage, TitleLanguage.english);
    expect(saved.scoreFormat, ScoreFormat.point10);
  });

  group('stale-while-revalidate', () {
    var clock = 0;
    var version = 0;
    var reads = 0;
    late List<int> refreshes;
    Future<void> settle() => Future<void>.delayed(Duration.zero);

    AniListClient swrClient({ResponseStore? store}) {
      clock = 0;
      version = 0;
      reads = 0;
      refreshes = [];
      // each read answers with its number, so copies tell apart; a save is
      // a local edit, so it moves the edit clock
      respond = (req) {
        if ((jsonDecode(req.body) as Json)['query'].toString().contains('SaveEntry')) {
          clock++;
          return json({
            'data': {
              'SaveMediaListEntry': {'id': 1, 'mediaId': 5, 'status': 'CURRENT', 'progress': 3},
            },
          });
        }
        reads++;
        return json({
          'data': {'v': ++version},
        });
      };
      final c = client(store: store)
        ..token = 'tok'
        ..editClock = () => clock;
      c.refreshed.listen((_) => refreshes.add(version));
      return c;
    }

    Future<Json> read(AniListClient c, {bool fresh = false}) =>
        c.cachedQuery('query L {}', staleWhileRevalidate: true, fresh: fresh);

    test('serves an expired list at once and swaps in the newer copy behind it', () async {
      final c = swrClient();
      expect(await read(c), {'v': 1});
      now = now.add(cacheTtl + const Duration(seconds: 1));
      // stale, at once; one refresh however many read it
      expect(await read(c), {'v': 1});
      expect(await read(c), {'v': 1});
      await settle();
      expect(reads, 2);
      expect(refreshes, [2]);
      expect(await read(c), {'v': 2});
    });

    test("keeps a list after a save, but says it's older than the edit", () async {
      final c = swrClient();
      final before = await read(c);
      await c.saveEntry(5, const EntryInput(progress: 3));
      final stale = await read(c);
      expect(identical(stale, before), isTrue);
      expect(c.requestStamp(stale), lessThan(clock));
      await settle();
      final after = await read(c);
      expect(after, {'v': 2});
      expect(c.requestStamp(after), clock);
    });

    test('waits for the network when asked for a fresh copy', () async {
      final c = swrClient();
      await read(c);
      expect(await read(c, fresh: true), {'v': 2});
    });

    test('keeps the stale copy when the refresh fails, and tries again next time', () async {
      final c = swrClient();
      await read(c);
      now = now.add(cacheTtl + const Duration(seconds: 1));
      final ok = respond;
      respond = (_) => json(<String, Object>{}, 500);
      expect(await read(c), {'v': 1});
      await settle();
      respond = ok;
      expect(await read(c), {'v': 1});
      await settle();
      expect(await read(c), {'v': 2});
    });

    test('a settings save drops it: a new score format changes every score', () async {
      final c = swrClient();
      final before = await read(c);
      final ok = respond;
      respond = (_) => json({
        'data': {
          'UpdateUser': {
            'id': 1,
            'mediaListOptions': {'scoreFormat': 'POINT_100'},
          },
        },
      });
      await c.updateViewerSettings(const ViewerSettings(scoreFormat: ScoreFormat.point100));
      respond = ok;
      // a new request, waited for: not the copy in the old format
      final after = await read(c);
      expect(identical(after, before), isFalse);
      expect(after, {'v': 2});
    });

    test('a pull drops the list, so it waits for a new copy', () async {
      final c = swrClient();
      await read(c);
      c.clearViewerCache(lists: true);
      expect(await read(c), {'v': 2});
    });

    test('a newer copy is saved on the device too, and a cached one only once', () async {
      final store = _CountingStore();
      final c = swrClient(store: store);
      Future<Fetched<Json>> list() => c.persistedQuery('list', 'query L {}', staleWhileRevalidate: true);
      await list();
      await list();
      expect(store.writes, 1);
      now = now.add(cacheTtl + const Duration(seconds: 1));
      await list();
      await settle();
      expect(store.writes, 2);
      expect(store.saved.values.single, {'v': 2});
      expect((await list()).data, {'v': 2});
      expect(store.writes, 2);
    });
  });

  group('persistedQuery', () {
    test('keeps the last good copy and returns it when offline', () async {
      final store = FakeStore();
      final c = client(store: store);
      respond = (_) => json({
        'data': {'n': 1},
      });
      final live = await c.persistedQuery('list', 'query L {}', variables: {'u': 1});
      expect(live.fromDevice, isFalse);

      c.clearCache();
      respond = (_) => throw const SocketException('offline');
      final offline = await c.persistedQuery('list', 'query L {}', variables: {'u': 1});
      expect(offline.fromDevice, isTrue);
      expect(offline.data, {'n': 1});
      expect(offline.savedAt, DateTime(2026, 10, 9, 8));
    });

    test('still fails when there is no copy, or the error is not about the network', () async {
      final store = FakeStore();
      final c = client(store: store);
      respond = (_) => throw const SocketException('offline');
      expect((await caught(c.persistedQuery('list', 'query L {}'))).kind, AniListErrorKind.network);
      store.saved['list:{}'] = {'n': 1};
      respond = (_) => json({}, 429);
      expect((await caught(c.persistedQuery('list', 'query L {}'))).kind, AniListErrorKind.rateLimit);
    });
  });

  group('custom lists', () {
    Json entry(int mediaId) => {
      'id': mediaId * 10,
      'mediaId': mediaId,
      'status': 'CURRENT',
      'progress': 1,
      'updatedAt': 0,
      'media': {'id': mediaId, 'type': 'ANIME', 'title': <String, Object>{}, 'coverImage': <String, Object>{}},
    };
    Json collection() => {
      'data': {
        'MediaListCollection': {
          'lists': [
            {
              'name': 'Rewatch',
              'status': null,
              'isCustomList': true,
              'entries': [entry(1), entry(3)],
            },
            {
              'name': 'Completed',
              'status': 'COMPLETED',
              'isCustomList': false,
              'entries': [entry(1)],
            },
            {'name': 'Empty', 'status': null, 'isCustomList': true, 'entries': <Json>[]},
          ],
        },
      },
    };

    test('keeps titles that are only on a custom list, once each', () async {
      respond = (_) => json(collection());
      final list = await client().fetchListCollection(9, MediaType.anime);
      expect(list.data.map((e) => e.entry.mediaId), [1, 3]);
    });

    test('reads a missing collection as an empty list', () async {
      respond = (_) => json({
        'data': {'MediaListCollection': null},
      });
      final c = client();
      expect((await c.fetchListCollection(9, MediaType.anime)).data, isEmpty);
      final custom = await c.fetchCustomLists(9, MediaType.anime);
      expect(custom.lists, isEmpty);
      expect(custom.hidden, isEmpty);
      respond = (_) => json({
        'data': {
          'MediaListCollection': {'lists': null},
        },
      });
      expect(await c.fetchUserList(9, MediaType.manga), isEmpty);
    });

    test('names each custom list, and the titles hidden from status lists, from the same request', () async {
      respond = (_) => json(collection());
      final c = client();
      await c.fetchListCollection(9, MediaType.anime);
      final custom = await c.fetchCustomLists(9, MediaType.anime);
      expect(custom.lists.map((l) => l.name), ['Rewatch']);
      expect(custom.lists.single.mediaIds, [1, 3]);
      expect(custom.hidden, {3});
      expect(requests, hasLength(1));
    });
  });

  group('fetchUserList', () {
    Json entry(int mediaId, String status) => {
      'id': mediaId * 10,
      'mediaId': mediaId,
      'status': status,
      'progress': 1,
      'score': 8.5,
      'updatedAt': 0,
      'media': {'id': mediaId, 'type': 'ANIME', 'title': <String, Object>{}, 'coverImage': <String, Object>{}},
    };

    test('asks for scores out of 10 without a token, each title once', () async {
      respond = (_) => json({
        'data': {
          'MediaListCollection': {
            'lists': [
              {
                'isCustomList': false,
                'entries': [entry(1, 'COMPLETED'), entry(2, 'COMPLETED')],
              },
              {
                'isCustomList': true,
                'entries': [entry(1, 'COMPLETED'), entry(4, 'PAUSED')],
              },
              {
                'isCustomList': false,
                'entries': [entry(3, 'CURRENT')],
              },
            ],
          },
        },
      });
      final c = client()..token = 'tok';
      final entries = await c.fetchUserList(2, MediaType.anime);
      // 4 is only on a custom list ("hide from status lists"): kept, after the status lists
      expect(entries.map((e) => e.entry.mediaId), [1, 2, 3, 4]);
      expect(entries.first.entry.score, 8.5);
      expect(requests.single.headers['Authorization'], isNull);
      expect(body(0)['query'], contains('score(format: POINT_10_DECIMAL)'));
    });

    test('tells a private user apart from other failures', () async {
      respond = (_) => json({
        'errors': [
          {'message': 'Private User', 'status': 404},
        ],
        'data': null,
      }, 404);
      expect(isPrivateUser(await caught(client().fetchUserList(1, MediaType.anime))), isTrue);
      respond = (_) => json({
        'errors': [
          {'message': 'Not Found.', 'status': 404},
        ],
        'data': null,
      }, 404);
      expect(isPrivateUser(await caught(client().fetchUserList(99, MediaType.anime))), isFalse);
    });
  });
}

class _CountingStore extends FakeStore {
  var writes = 0;

  @override
  Future<void> write(String key, Json data) async {
    writes++;
    await super.write(key, data);
  }
}
