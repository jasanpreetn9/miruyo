// Ported from apps/web/src/lib/state/list.svelte.ts (ListStore), with one
// addition: an edit AniList can't take right now (offline, rate limit) is
// kept and queued instead of rolled back, and sent once it can.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../anilist/client.dart';
import '../anilist/errors.dart';
import '../anilist/types.dart';
import '../catalog/title.dart';
import '../providers.dart';
import '../sync/edit_queue.dart';
import 'list_entry.dart';

/// Every list entry the app knows about, keyed by media id, so a change made
/// on one card shows on every other card for the same title.
class ListState {
  const ListState({this.entries = const {}, this.removed = const {}, this.saving = const {}, this.queued = const {}});

  final Map<int, ListEntry> entries;

  /// Titles taken off the list this session. Kept separately so [entryFor]
  /// doesn't fall back to the (stale) entry the title was fetched with.
  final Set<int> removed;

  /// Titles with a save in flight.
  final Set<int> saving;

  /// Titles with an edit waiting to reach AniList.
  final Set<int> queued;

  ListEntry? operator [](int mediaId) => entries[mediaId];

  bool isRemoved(int mediaId) => removed.contains(mediaId);

  /// This store's entry for the title, else the one it was fetched with.
  ListEntry? entryFor(Title title) {
    if (removed.contains(title.id)) return null;
    return entries[title.id] ?? ListEntry.fromTitle(title);
  }

  ListState copyWith({Map<int, ListEntry>? entries, Set<int>? removed, Set<int>? saving, Set<int>? queued}) =>
      ListState(
        entries: entries ?? this.entries,
        removed: removed ?? this.removed,
        saving: saving ?? this.saving,
        queued: queued ?? this.queued,
      );
}

class ListStore extends Notifier<ListState> {
  /// Only save to AniList while signed in; signed out, edits stay local.
  bool sync = false;

  /// A clock that ticks on every local edit and is never reset, so versions
  /// stay unique across clear(): a save that resolves after a sign-out
  /// can't be mistaken for a newer edit.
  var _clock = 0;
  final _versions = <int, int>{};
  final _inFlight = <int, int>{};

  EditApi get _api => ref.read(editApiProvider);
  EditQueue get _queue => ref.read(editQueueProvider);

  @override
  ListState build() {
    Future.microtask(refreshQueued);
    // back online: send what's waiting
    ref.listen(isOnlineProvider, (was, now) {
      if (now && was == false) unawaited(flush());
    });
    return const ListState();
  }

  /// Call before starting a list query; pass the result to [seed].
  int stamp() => _clock;

  int _bump(int mediaId) => _versions[mediaId] = ++_clock;

  bool isSaving(int mediaId) => (_inFlight[mediaId] ?? 0) > 0;

  void _setSaving(int mediaId, int delta) {
    final n = (_inFlight[mediaId] ?? 0) + delta;
    _inFlight[mediaId] = n;
    state = state.copyWith(saving: n > 0 ? {...state.saving, mediaId} : ({...state.saving}..remove(mediaId)));
  }

  void _put(int mediaId, ListEntry entry) {
    state = state.copyWith(entries: {...state.entries, mediaId: entry}, removed: {...state.removed}..remove(mediaId));
  }

  void _drop(int mediaId, {bool removed = false}) {
    state = state.copyWith(
      entries: {...state.entries}..remove(mediaId),
      removed: removed ? {...state.removed, mediaId} : ({...state.removed}..remove(mediaId)),
    );
  }

  /// Takes in fresh entries from a query. [since] is the [stamp] taken when
  /// the query started: titles edited after that keep their local values,
  /// since the response predates the edit. Titles with a save in flight or
  /// an edit queued are always kept.
  void seed(Iterable<ListEntry> entries, {int? since}) {
    final next = {...state.entries};
    final removed = {...state.removed};
    for (final e in entries) {
      if (isSaving(e.mediaId) || state.queued.contains(e.mediaId)) continue;
      if ((_versions[e.mediaId] ?? 0) > (since ?? _clock)) continue;
      removed.remove(e.mediaId);
      final current = next[e.mediaId];
      next[e.mediaId] = current == null ? e : _mergeSeed(current, e);
    }
    state = state.copyWith(entries: next, removed: removed);
  }

  /// A partial entry (feed queries only carry status and progress) on top of
  /// the fuller one already held.
  ListEntry _mergeSeed(ListEntry current, ListEntry fresh) => ListEntry(
    id: fresh.id ?? current.id,
    mediaId: fresh.mediaId,
    status: fresh.status,
    progress: fresh.progress,
    progressVolumes: fresh.progressVolumes ?? current.progressVolumes,
    score: fresh.score ?? current.score,
    repeat: fresh.repeat ?? current.repeat,
    notes: fresh.notes ?? current.notes,
    private: fresh.private ?? current.private,
    priority: fresh.priority ?? current.priority,
    startedAt: fresh.startedAt ?? current.startedAt,
    completedAt: fresh.completedAt ?? current.completedAt,
  );

  /// Applies [patch] now and saves it. [base] is the entry to start from
  /// when the store has none yet (usually ListEntry.fromTitle). Resolves to
  /// whether the change stuck (queued counts: it will reach AniList).
  Future<bool> update(int mediaId, EntryInput patch, {ListEntry? base, String label = ''}) async {
    final wasRemoved = state.isRemoved(mediaId);
    final previous = wasRemoved ? null : (state.entries[mediaId] ?? base);
    final version = _bump(mediaId);

    _put(
      mediaId,
      (previous ?? ListEntry(mediaId: mediaId, status: MediaListStatus.planning, progress: 0)).apply(patch),
    );

    if (!sync) return true;

    // keep edits to one title in order: once one is queued, the rest queue behind it
    if (!ref.read(isOnlineProvider) || state.queued.contains(mediaId)) {
      await _queue.enqueueSave(mediaId, patch, label: label);
      await refreshQueued();
      return true;
    }

    _setSaving(mediaId, 1);
    try {
      final saved = await _api.saveEntry(mediaId, patch);
      if (_versions[mediaId] == version) {
        _put(mediaId, ListEntry.fromSaved(saved));
      } else if (state.entries[mediaId] case final current?) {
        // a newer edit is on its way; just keep the id AniList assigned
        _put(mediaId, current.withId(saved.id));
      }
      return true;
    } on AniListError catch (err) {
      if (err.isTransient) {
        await _queue.enqueueSave(mediaId, patch, label: label);
        await refreshQueued();
        return true;
      }
      // roll back, unless a later edit has already superseded this one
      if (_versions[mediaId] == version) {
        if (previous != null) {
          _put(mediaId, previous);
        } else {
          _drop(mediaId, removed: wasRemoved);
        }
      }
      return false;
    } finally {
      _setSaving(mediaId, -1);
    }
  }

  /// +1 episode/chapter, capped at [total] when known. Never changes the
  /// status: ListActions.plusOne decides that.
  Future<bool> increment(int mediaId, int? total, {ListEntry? base}) {
    final current = state.isRemoved(mediaId) ? null : (state.entries[mediaId] ?? base);
    final progress = current?.progress ?? 0;
    final next = total != null && total > 0 ? (progress + 1).clamp(0, total) : progress + 1;
    if (next == progress) return Future.value(false);
    return update(mediaId, EntryInput(progress: next), base: base);
  }

  Future<bool> setStatus(int mediaId, MediaListStatus status, {ListEntry? base}) =>
      update(mediaId, EntryInput(status: status), base: base);

  /// Takes the title off the list. Resolves to whether that stuck.
  Future<bool> remove(int mediaId, {ListEntry? base, String label = ''}) async {
    if (state.isRemoved(mediaId)) return true;
    final previous = state.entries[mediaId] ?? base;
    if (previous == null) return true;
    final version = _bump(mediaId);
    void restore() {
      if (_versions[mediaId] == version) _put(mediaId, previous);
    }

    _drop(mediaId, removed: true);
    if (!sync) return true;

    // offline, or the entry only exists in queued saves so far
    if (!ref.read(isOnlineProvider) || state.queued.contains(mediaId)) {
      await _queue.enqueueDelete(mediaId, previous.id, label: label);
      await refreshQueued();
      return true;
    }
    if (previous.id == null) {
      restore();
      return false;
    }

    _setSaving(mediaId, 1);
    try {
      await _api.deleteEntry(previous.id!);
      return true;
    } on AniListError catch (err) {
      if (err.isTransient) {
        await _queue.enqueueDelete(mediaId, previous.id, label: label);
        await refreshQueued();
        return true;
      }
      restore();
      return false;
    } finally {
      _setSaving(mediaId, -1);
    }
  }

  /// Sends queued edits. Called when the device comes back online, on
  /// sign-in, on app resume and from the offline banner's Retry.
  Future<FlushResult> flush() async {
    if (!sync) return const FlushResult();
    final result = await _queue.flush(_api);
    final pending = {for (final e in await _queue.pending()) e.mediaId};
    // the last thing AniList saved for each title is what it now holds
    final latest = {for (final s in result.saved) s.mediaId: s};
    for (final saved in latest.values) {
      if (!pending.contains(saved.mediaId)) _put(saved.mediaId, ListEntry.fromSaved(saved));
    }
    // refused edits: forget the local change, so the next fetch shows AniList's truth
    for (final (edit, _) in result.rejected) {
      if (!pending.contains(edit.mediaId)) _drop(edit.mediaId);
    }
    state = state.copyWith(queued: pending);
    if (result.saved.isNotEmpty || result.deleted.isNotEmpty) {
      ref.read(anilistClientProvider).clearViewerCache();
    }
    return result;
  }

  /// Re-reads which titles have queued edits.
  Future<void> refreshQueued() async {
    final pending = {for (final e in await _queue.pending()) e.mediaId};
    state = state.copyWith(queued: pending);
  }

  /// Forgets every entry (sign-out). The clock keeps running and in-flight
  /// counts are kept, so saves still pending from before can't overwrite
  /// anything made after.
  void clear() {
    _versions.clear();
    state = state.copyWith(entries: const {}, removed: const {});
  }
}

final listStoreProvider = NotifierProvider<ListStore, ListState>(ListStore.new);
