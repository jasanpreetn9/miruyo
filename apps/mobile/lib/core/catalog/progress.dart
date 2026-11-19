// Ported from apps/web/src/lib/catalog/progress.ts.

import '../anilist/types.dart';
import 'status.dart';
import 'title.dart';

class PlusOne {
  const PlusOne({required this.progress, required this.completes, required this.starts});

  final int progress;

  /// True when this +1 reaches the total: the entry moves to Completed.
  final bool completes;

  /// True for a +1 on a Planning entry: you've started it, so it moves to Watching.
  final bool starts;
}

/// What a +1 does. Reaching the last episode/chapter of something in
/// progress completes it (with an Undo toast, everywhere in the app); with no
/// known total it just keeps counting. null = nothing to do (already at the end).
PlusOne? plusOneOutcome(({MediaListStatus status, int progress})? current, int? total) {
  final progress = current?.progress ?? 0;
  if (total != null && total > 0 && progress >= total) return null;
  final next = progress + 1;
  final starts = current?.status == MediaListStatus.planning;
  final completes =
      total != null && total > 0 && next >= total && current != null && (isInProgress(current.status) || starts);
  return PlusOne(progress: next, completes: completes, starts: starts && !completes);
}

/// Episodes (or chapters) out so far, when that's known: the one before the
/// next to air, or the total once it's finished. Null for manga still
/// running and anything AniList has no schedule for.
int? airedCount(Title t) {
  final next = t.next;
  if (next != null) return next.ep - 1;
  if (t.status == 'Finished') return t.total;
  return null;
}

/// New episodes out for [t] at [progress], when the schedule says.
int? newEpisodesFor(Title t, int progress) {
  final aired = airedCount(t);
  return aired == null ? null : (aired - progress).clamp(0, 1 << 20);
}
