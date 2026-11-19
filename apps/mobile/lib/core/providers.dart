// App-wide services. Each is a provider so tests can override it.

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'anilist/client.dart';
import 'gestures/haptics.dart';
import 'storage/database.dart';
import 'storage/prefs.dart';
import 'sync/edit_queue.dart';

/// Opened in main() before the app starts, so reads are synchronous.
final prefsProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('override prefsProvider in main()'),
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase.open();
  ref.onDispose(db.close);
  return db;
});

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final anilistClientProvider = Provider<AniListClient>(
  (ref) => AniListClient(store: DriftResponseStore(ref.watch(databaseProvider))),
);

final editQueueProvider = Provider<EditQueue>((ref) => EditQueue(DriftEditStore(ref.watch(databaseProvider))));

final editApiProvider = Provider<EditApi>((ref) => ClientEditApi(ref.watch(anilistClientProvider)));

final hapticsProvider = Provider<Haptics>((ref) => const Haptics());

/// Whether the device has a network. Only a hint: AniList can still fail
/// to answer while online, and that's handled where requests are made.
final onlineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  bool online(List<ConnectivityResult> r) => r.any((c) => c != ConnectivityResult.none);
  yield online(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(online).distinct();
});

/// [onlineProvider]'s latest value, assuming online until it's known.
final isOnlineProvider = Provider<bool>((ref) => ref.watch(onlineProvider).value ?? true);

extension CacheFor on Ref {
  /// Keeps an autoDispose provider's data for [duration] after its last
  /// listener goes, so switching tabs or modes and coming back doesn't
  /// refetch. AniList's limit is 90 requests a minute, sometimes 30.
  void cacheFor(Duration duration) {
    final link = keepAlive();
    final timer = Timer(duration, link.close);
    onDispose(timer.cancel);
  }
}

/// How long a screen's AniList data outlives the screen.
const screenCache = Duration(minutes: 5);
