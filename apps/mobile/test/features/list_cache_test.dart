import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miruyo/core/anilist/client.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/auth/session.dart';
import 'package:miruyo/core/catalog/mode.dart';
import 'package:miruyo/core/list/list_store.dart';
import 'package:miruyo/features/list/list_data.dart';

import '../helpers.dart';

class _SignedIn extends Session {
  @override
  SessionState build() => const SessionState(
    authState: AuthState.signedIn,
    user: AniListUser(id: 1, name: 'rin'),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// AniList's copy of the list: Frieren at [progress], and [more] titles.
  var progress = 7;
  var reads = 0;
  var more = <Json>[];
  Json title(int id, String name, int progress) => {
    'id': id * 10,
    'mediaId': id,
    'status': 'CURRENT',
    'progress': progress,
    'score': 0,
    'updatedAt': 1800000000,
    'media': {
      'id': id,
      'type': 'ANIME',
      'format': 'TV',
      'episodes': 24,
      'title': {'romaji': name, 'userPreferred': name},
      'coverImage': <String, Object>{},
    },
  };
  Json collection() => {
    'MediaListCollection': {
      'lists': [
        {
          'name': 'Watching',
          'status': 'CURRENT',
          'isCustomList': false,
          'entries': [title(1, 'Frieren', progress), ...more],
        },
      ],
    },
  };

  setUp(() {
    progress = 7;
    reads = 0;
    more = [];
  });

  /// My List's provider on a client whose clock the test moves.
  Future<({ProviderContainer container, ListStore store, void Function(Duration) wait})> open() async {
    var now = DateTime(2026, 11, 17, 12);
    final client = AniListClient(
      httpClient: MockClient((req) async {
        reads++;
        return http.Response(jsonEncode({'data': collection()}), 200, headers: {'content-type': 'application/json'});
      }),
      now: () => now,
    )..token = 'tok';
    final container = await testContainer(client: client, overrides: [sessionProvider.overrideWith(_SignedIn.new)]);
    addTearDown(container.dispose);
    final sub = container.listen(listCollectionProvider(Mode.anime), (_, _) {});
    addTearDown(sub.close);
    final store = container.read(listStoreProvider.notifier)..sync = true;
    await container.read(listCollectionProvider(Mode.anime).future);
    return (container: container, store: store, wait: (Duration d) => now = now.add(d));
  }

  test("rebuilding My List from a copy older than an edit doesn't undo it", () async {
    var now = DateTime(2026, 11, 17, 12);
    final client = AniListClient(
      httpClient: MockClient((req) async {
        reads++;
        return http.Response(jsonEncode({'data': collection()}), 200, headers: {'content-type': 'application/json'});
      }),
      now: () => now,
    )..token = 'tok';
    final container = await testContainer(client: client, overrides: [sessionProvider.overrideWith(_SignedIn.new)]);
    addTearDown(container.dispose);
    final sub = container.listen(listCollectionProvider(Mode.anime), (_, _) {});
    addTearDown(sub.close);
    final store = container.read(listStoreProvider.notifier)..sync = true;

    await container.read(listCollectionProvider(Mode.anime).future);
    expect(container.read(listStoreProvider)[1]?.progress, 7);

    // a +1, then My List builds again from the copy it already has
    await store.update(1, const EntryInput(progress: 8));
    container.invalidate(listCollectionProvider(Mode.anime));
    await container.read(listCollectionProvider(Mode.anime).future);
    expect(reads, 1);
    expect(container.read(listStoreProvider)[1]?.progress, 8);

    // past its TTL: the old copy at once, AniList's newer one (with the +1) behind it
    progress = 8;
    now = now.add(cacheTtl + const Duration(seconds: 1));
    container.invalidate(listCollectionProvider(Mode.anime));
    await container.read(listCollectionProvider(Mode.anime).future);
    expect(container.read(listStoreProvider)[1]?.progress, 8);
    await pumpEventQueue();
    await container.read(listCollectionProvider(Mode.anime).future);
    expect(reads, 2);
    expect(container.read(listStoreProvider)[1]?.progress, 8);
  });

  test('a newer copy reaches My List by itself, without a frame of nothing', () async {
    final (:container, store: _, :wait) = await open();
    final states = <AsyncValue<ListCollection>>[];
    container.listen(listCollectionProvider(Mode.anime), (_, next) => states.add(next));

    // a title added elsewhere; My List is built again after its minute
    more = [title(2, 'Dandadan', 3)];
    wait(cacheTtl + const Duration(seconds: 1));
    container.invalidate(listCollectionProvider(Mode.anime));
    expect((await container.read(listCollectionProvider(Mode.anime).future)).entries, hasLength(1));
    // the newer copy lands, and the provider builds again on its own
    await pumpEventQueue();
    expect(container.read(listCollectionProvider(Mode.anime)).value?.entries, hasLength(2));
    expect(reads, 2);
    // every state on the way kept the rows it had
    expect(states, isNotEmpty);
    expect(states.every((s) => s.hasValue), isTrue);
  });

  test('a title removed after a copy was requested stays removed', () async {
    final (:container, :store, wait: _) = await open();
    await store.remove(1);
    container.invalidate(listCollectionProvider(Mode.anime));
    await container.read(listCollectionProvider(Mode.anime).future);
    expect(container.read(listStoreProvider).isRemoved(1), isTrue);
  });
}
