// Ported from the web's list.test.ts, plus the offline queue.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:miruyo/core/anilist/client.dart';
import 'package:miruyo/core/anilist/types.dart';
import 'package:miruyo/core/catalog/cover_color.dart';
import 'package:miruyo/core/catalog/title.dart';
import 'package:miruyo/core/gestures/haptics.dart';
import 'package:miruyo/core/list/list_actions.dart';
import 'package:miruyo/core/list/list_entry.dart';
import 'package:miruyo/core/list/list_store.dart';
import 'package:miruyo/core/providers.dart';
import 'package:miruyo/core/ui/toast.dart';

import '../../helpers.dart';

const base = ListEntry(id: 7, mediaId: 1, status: MediaListStatus.current, progress: 5);

void main() {
  late FakeEditApi api;
  late MemoryEditStore store;
  late ProviderContainer container;

  Future<ListStore> make({bool online = true}) async {
    api = FakeEditApi();
    store = MemoryEditStore();
    container = await testContainer(api: api, store: store, online: online);
    addTearDown(container.dispose);
    final list = container.read(listStoreProvider.notifier)..sync = true;
    await Future<void>.delayed(Duration.zero);
    return list;
  }

  ListState state() => container.read(listStoreProvider);

  test('applies an edit immediately and keeps what AniList returns', () async {
    final list = await make();
    final pending = list.increment(1, 24, base: base);
    expect(state()[1]?.progress, 6);
    expect(await pending, isTrue);
    expect((state()[1]?.id, state()[1]?.progress), (99, 6));
  });

  test('only sends the changed fields', () async {
    final list = await make();
    await list.setStatus(1, MediaListStatus.paused, base: base);
    expect(api.saves.single.$1, 1);
    expect(api.saves.single.$2, {'status': 'PAUSED'});
  });

  test('rolls back when AniList refuses the save', () async {
    final list = await make();
    api.saveResults.add(refused);
    expect(await list.increment(1, 24, base: base), isFalse);
    expect(state()[1]?.progress, 5);
  });

  test('removes a brand-new entry again when its first save is refused', () async {
    final list = await make();
    api.saveResults.add(refused);
    await list.setStatus(2, MediaListStatus.planning);
    expect(state()[2], isNull);
  });

  test("doesn't roll back over a newer edit", () async {
    final list = await make();
    final first = Completer<AniListSavedEntry>();
    api.saveResults.add(first);
    final a = list.increment(1, 24, base: base); // 6, slow and doomed
    await list.increment(1, 24); // 7, succeeds
    first.completeError(refused);
    await a;
    expect(state()[1]?.progress, 7);
  });

  test('caps +1 at the total and never auto-completes', () async {
    final list = await make();
    await list.increment(1, 6, base: base);
    expect((state()[1]?.progress, state()[1]?.status), (6, MediaListStatus.current));
    expect(await list.increment(1, 6), isFalse);
  });

  test('keeps counting when the total is unknown', () async {
    final list = await make();
    await list.increment(1, null, base: base.apply(const EntryInput(progress: 500)));
    expect(state()[1]?.progress, 501);
  });

  test("doesn't let a stale query overwrite an edit that's still saving", () async {
    final list = await make();
    final slow = Completer<AniListSavedEntry>();
    api.saveResults.add(slow);
    final pending = list.increment(1, 24, base: base);
    list.seed([base]);
    expect(state()[1]?.progress, 6);
    slow.complete(saved(1, const EntryInput(progress: 6)));
    await pending;
    list.seed([base.apply(const EntryInput(progress: 9))]);
    expect(state()[1]?.progress, 9);
  });

  test("doesn't let a query that started before an edit overwrite it after it saved", () async {
    final list = await make();
    list.seed([base]);
    final since = list.stamp(); // a Home fetch starts here
    await list.increment(1, 24, base: base); // +1 saves and finishes first
    list.seed([base], since: since); // …then the older response arrives
    expect(state()[1]?.progress, 6);
    list.seed([base.apply(const EntryInput(progress: 8))], since: list.stamp());
    expect(state()[1]?.progress, 8);
  });

  test("doesn't let a save from before a sign-out overwrite a newer edit", () async {
    final list = await make();
    final slow = Completer<AniListSavedEntry>();
    api.saveResults.add(slow);
    final stale = list.increment(1, 24, base: base); // progress 6, pending
    list.clear(); // signed out
    await list.update(1, const EntryInput(progress: 2), base: base.apply(const EntryInput(progress: 1)));
    slow.complete(saved(1, const EntryInput(progress: 6)));
    await stale;
    expect(state()[1]?.progress, 2);
  });

  test('keeps a removed title off the list instead of falling back to its fetched entry', () async {
    final list = await make();
    final title = Title(
      id: 1,
      title: 'Frieren',
      type: MediaType.anime,
      format: 'TV',
      score: 9,
      colors: CoverColors.fromHex(null),
      genres: const [],
      status: 'Releasing',
      me: const MyProgress(status: MediaListStatus.current, progress: 5),
    );
    list.seed([base]);
    await list.remove(1);
    expect(state().entryFor(title), isNull);
    expect(state().isRemoved(1), isTrue);

    // adding it back starts fresh, not from the removed entry
    await list.setStatus(1, MediaListStatus.planning, base: ListEntry.fromTitle(title));
    expect(state().isRemoved(1), isFalse);
    expect(state().entryFor(title)?.status, MediaListStatus.planning);
  });

  test('restores a removed title when the delete is refused', () async {
    final list = await make();
    api.deleteResults.add(refused);
    list.seed([base]);
    expect(await list.remove(1), isFalse);
    expect(state().isRemoved(1), isFalse);
    expect(state()[1]?.id, 7);
  });

  test('stays local while signed out', () async {
    final list = await make();
    list.sync = false;
    await list.increment(1, 24, base: base);
    expect(state()[1]?.progress, 6);
    expect(api.saves, isEmpty);
  });

  group('offline', () {
    test('queues an edit made offline and keeps it', () async {
      final list = await make(online: false);
      expect(await list.increment(1, 24, base: base), isTrue);
      expect(state()[1]?.progress, 6);
      expect(api.saves, isEmpty);
      expect(state().queued, {1});
      expect(store.edits.single.input.toJson(), {'progress': 6});
    });

    test('queues instead of rolling back when AniList cannot be reached', () async {
      final list = await make();
      api.saveResults.add(offline);
      expect(await list.increment(1, 24, base: base), isTrue);
      expect(state()[1]?.progress, 6);
      expect(state().queued, {1});
    });

    test('later edits to a queued title queue behind it, merged', () async {
      final list = await make();
      api.saveResults.add(offline);
      await list.increment(1, 24, base: base);
      await list.increment(1, 24);
      expect(api.saves, hasLength(1)); // only the first try reached the API
      expect(store.edits.single.input.toJson(), {'progress': 7});
    });

    test('flush sends the queue and takes in what AniList saved', () async {
      final list = await make(online: false);
      await list.increment(1, 24, base: base);
      await list.increment(1, 24);
      list.sync = true;
      await list.flush();
      expect(api.saves.single.$1, 1);
      expect(api.saves.single.$2, {'progress': 7});
      expect(state().queued, isEmpty);
      expect((state()[1]?.id, state()[1]?.progress), (99, 7));
    });

    test('removing offline queues a delete by entry id', () async {
      final list = await make(online: false);
      list.seed([base]);
      expect(await list.remove(1), isTrue);
      expect(store.edits.single.entryId, 7);
      await list.flush();
      expect(api.deletes, [7]);
    });

    test('a refused queued edit is forgotten, so the next fetch shows AniList', () async {
      final list = await make(online: false);
      await list.increment(1, 24, base: base);
      api.saveResults.add(refused);
      final result = await list.flush();
      expect(result.rejected, hasLength(1));
      expect(state()[1], isNull);
      expect(state().queued, isEmpty);
    });
  });

  group('ListActions', () {
    final frieren = Title(
      id: 1,
      title: 'Frieren',
      type: MediaType.anime,
      format: 'TV',
      eps: 28,
      score: 9,
      colors: CoverColors.fromHex(null),
      genres: const [],
      status: 'Releasing',
      me: const MyProgress(status: MediaListStatus.current, progress: 27),
    );

    test('+1 to the total completes, with a toast, Undo and a Success haptic', () async {
      await make();
      final haptics = container.read(hapticsProvider) as RecordingHaptics;
      await container.read(listActionsProvider).plusOne(frieren);
      expect(state()[1]?.status, MediaListStatus.completed);
      final toast = container.read(toastProvider).single;
      expect(toast.message, 'Frieren moved to Completed');
      expect(haptics.played, [Haptic.success]);

      toast.action!.run();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);
      expect((state()[1]?.status, state()[1]?.progress), (MediaListStatus.current, 27));
    });

    test('+1 past what has aired asks first; Log anyway logs it', () async {
      await make();
      container.read(listStoreProvider.notifier).seed([
        const ListEntry(id: 7, mediaId: 2, status: MediaListStatus.current, progress: 4),
      ]);
      final airing = Title(
        id: 2,
        title: 'Dandadan',
        type: MediaType.anime,
        format: 'TV',
        eps: 12,
        score: 8,
        colors: CoverColors.fromHex(null),
        genres: const [],
        status: 'Releasing',
        // episode 5 is next: 4 are out, and 4 are watched
        next: NextAiring(ep: 5, airingAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600),
      );
      final haptics = container.read(hapticsProvider) as RecordingHaptics;
      expect(await container.read(listActionsProvider).plusOne(airing), isFalse);
      expect(state()[2]?.progress, 4);
      final toast = container.read(toastProvider).single;
      expect(toast.message, "EP 5 hasn't aired yet");
      expect(haptics.played, [Haptic.warning]);

      toast.action!.run();
      await Future<void>.delayed(Duration.zero);
      expect(state()[2]?.progress, 5);
    });

    test('removing keeps Undo up for the longer removal window', () async {
      await make();
      container.read(listStoreProvider.notifier).seed([
        const ListEntry(id: 7, mediaId: 1, status: MediaListStatus.current, progress: 27),
      ]);
      await container.read(listActionsProvider).removeFromList(frieren);
      final toast = container.read(toastProvider).single;
      expect(toast.message, 'Removed Frieren from your list');
      expect(toast.duration, const Duration(seconds: 5));
    });
  });
}
