// Ported from apps/web/src/lib/state/list-actions.ts: the list changes
// people make from cards, rows and pages. Each applies at once and confirms
// with a toast that can undo it, and plays its haptic.

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../anilist/client.dart';
import '../anilist/types.dart';
import '../catalog/progress.dart';
import '../catalog/status.dart';
import '../catalog/title.dart';
import '../gestures/haptics.dart';
import '../providers.dart';
import '../ui/toast.dart';
import 'list_entry.dart';
import 'list_store.dart';

class ListActions {
  ListActions(this.ref);

  final Ref ref;

  ListStore get _list => ref.read(listStoreProvider.notifier);
  ListState get _state => ref.read(listStoreProvider);
  ToastController get _toast => ref.read(toastProvider.notifier);
  void _haptic(Haptic kind) => unawaited(ref.read(hapticsProvider).play(kind));

  void failed(Title title) => _toast.show("Couldn't save ${title.title} to AniList", tone: ToastTone.error);

  /// Undo a change. [previous] null means the change added the title, so
  /// undo takes it off again, once AniList has given the new entry an id.
  Future<void> _undo(Title title, ListEntry? previous, Future<bool> saving) async {
    _haptic(Haptic.light);
    if (previous == null) {
      await saving;
      await _list.remove(title.id, label: title.title);
      return;
    }
    await _list.update(title.id, previous.toInput(), base: previous, label: title.title);
  }

  /// "Steins;Gate · EP 9 / 24"
  String _progressMessage(Title title, int progress) =>
      '${title.title} · ${title.unit} $progress / ${title.total ?? '?'}';

  /// +1 episode/chapter, with an Undo toast. Reaching the total moves the
  /// title to Completed; a +1 on something planned starts it.
  Future<bool> plusOne(Title title, {bool beyondAired = false}) async {
    final current = _state.entryFor(title);
    final outcome = plusOneOutcome(current?.brief, title.total);
    if (outcome == null) return false;
    // past what has aired: say when it airs, and log it only if asked again
    final next = title.next;
    if (!beyondAired && next != null && outcome.progress >= next.ep) {
      _haptic(Haptic.warning);
      _toast.show(
        "EP ${next.ep} hasn't aired yet",
        action: ToastAction('Log anyway', () => unawaited(plusOne(title, beyondAired: true))),
      );
      return false;
    }
    final patch = outcome.completes
        ? EntryInput(progress: outcome.progress, status: MediaListStatus.completed)
        : outcome.starts
        ? EntryInput(progress: outcome.progress, status: MediaListStatus.current)
        : EntryInput(progress: outcome.progress);
    _haptic(Haptic.success);
    final saving = _list.update(title.id, patch, base: ListEntry.fromTitle(title), label: title.title);
    _toast.show(
      outcome.completes && current != null
          ? '${title.title} moved to Completed'
          : _progressMessage(title, outcome.progress),
      action: ToastAction('Undo', () => unawaited(_undo(title, current, saving))),
    );
    final ok = await saving;
    if (!ok) failed(title);
    return ok;
  }

  /// −1 episode/chapter, with an Undo toast. Nothing at 0 or off the list.
  Future<bool> minusOne(Title title) async {
    final current = _state.entryFor(title);
    if (current == null || current.progress <= 0) return false;
    final progress = current.progress - 1;
    _haptic(Haptic.light);
    final saving = _list.update(
      title.id,
      EntryInput(progress: progress),
      base: ListEntry.fromTitle(title),
      label: title.title,
    );
    _toast.show(
      _progressMessage(title, progress),
      action: ToastAction('Undo', () => unawaited(_undo(title, current, saving))),
    );
    final ok = await saving;
    if (!ok) failed(title);
    return ok;
  }

  /// Adds the title with [status], or moves it there: "Added X to Planning"
  /// / "Moved X to Watching", with Undo.
  Future<bool> changeStatus(Title title, MediaListStatus status) async {
    final current = _state.entryFor(title);
    if (current?.status == status) return true;
    _haptic(Haptic.success);
    final saving = _list.update(
      title.id,
      EntryInput(status: status),
      base: ListEntry.fromTitle(title),
      label: title.title,
    );
    final label = statusLabel(status, isAnime: title.isAnime);
    _toast.show(
      current != null ? 'Moved ${title.title} to $label' : 'Added ${title.title} to $label',
      action: ToastAction('Undo', () => unawaited(_undo(title, current, saving))),
    );
    final ok = await saving;
    if (!ok) failed(title);
    return ok;
  }

  /// Confirms a save made in the editor: "Added…", "Moved… to …" or
  /// "Saved…", with Undo back to [previous] (null = it wasn't on the list).
  void confirmSaved(Title title, ListEntry? previous, MediaListStatus status) {
    final label = statusLabel(status, isAnime: title.isAnime);
    final message = previous == null
        ? 'Added ${title.title} to $label'
        : previous.status != status
        ? 'Moved ${title.title} to $label'
        : 'Saved ${title.title}';
    _toast.show(message, action: ToastAction('Undo', () => unawaited(_undo(title, previous, Future.value(true)))));
  }

  /// Moves several titles to [status] (My List's Edit mode): "Moved 3 to
  /// Paused", with one Undo for all of them, up for 5s.
  Future<void> moveMany(List<Title> titles, MediaListStatus status) async {
    final previous = {for (final t in titles) t.id: _state.entryFor(t)};
    final moving = [
      for (final t in titles)
        if (previous[t.id]?.status != status) t,
    ];
    if (moving.isEmpty) return;
    _haptic(Haptic.success);
    final saves = [
      for (final t in moving)
        _list.update(
          t.id,
          EntryInput(status: status),
          base: ListEntry.fromTitle(t),
          label: t.title,
        ),
    ];
    final label = statusLabel(status, isAnime: moving.first.isAnime);
    _toast.show(
      moving.length == 1 ? 'Moved ${moving.first.title} to $label' : 'Moved ${moving.length} to $label',
      long: true,
      action: ToastAction('Undo', () {
        for (final (i, t) in moving.indexed) {
          unawaited(_undo(t, previous[t.id], saves[i]));
        }
      }),
    );
    final failed = (await Future.wait(saves)).where((ok) => !ok).length;
    if (failed > 0) {
      _toast.show(
        failed == 1 ? "Couldn't move 1 title on AniList" : "Couldn't move $failed titles on AniList",
        tone: ToastTone.error,
      );
    }
  }

  /// Takes several titles off the list: "Removed 2 from your list", with one
  /// Undo that puts them back with their progress and scores. The haptic is
  /// the caller's (HoldToConfirm plays it as it fills).
  Future<void> removeMany(List<Title> titles) async {
    final previous = {for (final t in titles) t.id: _state[t.id] ?? ListEntry.fromTitle(t)};
    final removing = [
      for (final t in titles)
        if (previous[t.id] != null) t,
    ];
    if (removing.isEmpty) return;
    final removals = [for (final t in removing) _list.remove(t.id, base: previous[t.id], label: t.title)];
    _toast.show(
      removing.length == 1
          ? 'Removed ${removing.first.title} from your list'
          : 'Removed ${removing.length} from your list',
      long: true,
      action: ToastAction('Undo', () {
        _haptic(Haptic.light);
        for (final t in removing) {
          unawaited(_list.update(t.id, previous[t.id]!.toInput(), label: t.title));
        }
      }),
    );
    final failed = (await Future.wait(removals)).where((ok) => !ok).length;
    if (failed > 0) {
      _toast.show(
        failed == 1 ? "Couldn't remove 1 title from AniList" : "Couldn't remove $failed titles from AniList",
        tone: ToastTone.error,
      );
    }
  }

  /// Saves a new Up next order: [changes] is mediaId → priority, from
  /// upNextPriorities. Quiet on success apart from a confirming toast.
  Future<void> reorderUpNext(Map<int, int> changes) async {
    _haptic(Haptic.light);
    final saves = [
      for (final MapEntry(key: id, value: priority) in changes.entries)
        _list.update(id, EntryInput(priority: priority), base: _state[id]),
    ];
    final ok = (await Future.wait(saves)).every((ok) => ok);
    _toast.show(
      ok ? 'Up next order saved to AniList' : "Couldn't save the Up next order",
      tone: ok ? ToastTone.success : ToastTone.error,
    );
  }

  /// The priority that puts [title] first in Up next, or null when it's
  /// first already: one above the highest on Planning.
  int? topPriorityFor(Title title) {
    final mine = _state.entryFor(title);
    if (mine?.status != MediaListStatus.planning) return null;
    var top = 0;
    for (final e in _state.entries.values) {
      if (e.mediaId != title.id && e.status == MediaListStatus.planning) top = math.max(top, e.priority ?? 0);
    }
    return (mine!.priority ?? 0) > top ? null : top + 1;
  }

  /// Puts a planned title first in Up next (the screen-reader path for
  /// reordering, from quick actions).
  Future<void> moveToTop(Title title) async {
    final priority = topPriorityFor(title);
    if (priority != null) await reorderUpNext({title.id: priority});
  }

  /// Takes the title off the list; Undo adds it back as it was.
  Future<bool> removeFromList(Title title, {ListEntry? base}) async {
    final previous = _state[title.id] ?? base ?? ListEntry.fromTitle(title);
    final ok = await _list.remove(title.id, base: previous, label: title.title);
    if (!ok) {
      _toast.show("Couldn't remove ${title.title} from AniList", tone: ToastTone.error);
      return false;
    }
    _haptic(Haptic.warning);
    _toast.show(
      'Removed ${title.title} from your list',
      long: true,
      action: previous == null
          ? null
          : ToastAction('Undo', () {
              _haptic(Haptic.light);
              // a new entry with the same fields (AniList gives it a new id)
              unawaited(_list.update(title.id, previous.toInput(), label: title.title));
            }),
    );
    return true;
  }
}

final listActionsProvider = Provider<ListActions>(ListActions.new);
