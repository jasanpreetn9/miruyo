// Fakes shared by the tests: an in-memory edit store and a scriptable API.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:miruyo/core/anilist/client.dart';
import 'package:miruyo/core/anilist/errors.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/gestures/haptics.dart';
import 'package:miruyo/core/notifications/episode_alerts.dart';
import 'package:miruyo/core/providers.dart';
import 'package:miruyo/core/storage/database.dart';
import 'package:miruyo/core/sync/edit_queue.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MemoryEditStore implements EditStore {
  final edits = <PendingEdit>[];
  var _nextId = 0;

  @override
  Future<List<PendingEdit>> all() async => List.of(edits);

  @override
  Future<void> add(PendingEdit e) async => edits.add(
    PendingEdit(
      id: ++_nextId,
      mediaId: e.mediaId,
      op: e.op,
      input: e.input,
      entryId: e.entryId,
      label: e.label,
      attempts: e.attempts,
    ),
  );

  @override
  Future<void> update(PendingEdit e) async {
    final i = edits.indexWhere((x) => x.id == e.id);
    edits[i] = e;
  }

  @override
  Future<void> remove(int id) async => edits.removeWhere((e) => e.id == id);
}

AniListSavedEntry saved(int mediaId, EntryInput input, {int id = 99}) => AniListSavedEntry(
  id: id,
  mediaId: mediaId,
  status: input.status ?? MediaListStatus.current,
  progress: input.progress ?? 0,
);

const offline = AniListError('offline', AniListErrorKind.network);
const refused = AniListError('nope', AniListErrorKind.api, status: 400);

/// An [EditApi] whose answers each test scripts. By default every call
/// succeeds; push onto [saveResults] / [deleteResults] to change the next one.
class FakeEditApi implements EditApi {
  final saves = <(int, Json)>[];
  final deletes = <int>[];

  /// Each is an error to throw, a Completer to wait on, or null for success.
  final saveResults = <Object?>[];
  final deleteResults = <Object?>[];

  @override
  Future<AniListSavedEntry> saveEntry(int mediaId, EntryInput input) async {
    saves.add((mediaId, input.toJson()));
    final next = saveResults.isEmpty ? null : saveResults.removeAt(0);
    if (next is AniListError) throw next;
    if (next is Completer<AniListSavedEntry>) return next.future;
    return saved(mediaId, input);
  }

  @override
  Future<bool> deleteEntry(int entryId) async {
    deletes.add(entryId);
    final next = deleteResults.isEmpty ? null : deleteResults.removeAt(0);
    if (next is AniListError) throw next;
    return true;
  }
}

/// Records what would be scheduled, instead of touching the phone.
class FakeAlertScheduler implements AlertScheduler {
  FakeAlertScheduler({this.allowed = true});

  bool allowed;
  List<EpisodeAlert> scheduled = [];
  var permissionAsks = 0;

  @override
  Future<void> start() async {}

  @override
  Future<bool> requestPermission() async {
    permissionAsks++;
    return allowed;
  }

  @override
  Future<void> replaceAll(List<EpisodeAlert> alerts) async => scheduled = alerts;

  @override
  Future<void> cancelAll() async => scheduled = [];
}

/// A container with fakes for every service that would touch the device.
Future<ProviderContainer> testContainer({
  FakeEditApi? api,
  MemoryEditStore? store,
  bool online = true,
  Haptics? haptics,
  AniListClient? client,
  FakeAlertScheduler? alerts,
  List overrides = const [],
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      prefsProvider.overrideWithValue(prefs),
      databaseProvider.overrideWith((ref) {
        final db = AppDatabase.memory();
        ref.onDispose(db.close);
        return db;
      }),
      // no test reaches AniList: every request answers with empty data
      anilistClientProvider.overrideWithValue(
        client ?? AniListClient(httpClient: MockClient((_) async => http.Response('{"data":{}}', 200))),
      ),
      editApiProvider.overrideWithValue(api ?? FakeEditApi()),
      editQueueProvider.overrideWithValue(EditQueue(store ?? MemoryEditStore())),
      isOnlineProvider.overrideWithValue(online),
      hapticsProvider.overrideWithValue(haptics ?? RecordingHaptics()),
      alertSchedulerProvider.overrideWithValue(alerts ?? FakeAlertScheduler()),
      ...overrides,
    ],
  );
  return container;
}
