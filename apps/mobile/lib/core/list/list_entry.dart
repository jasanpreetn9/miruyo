// Ported from apps/web/src/lib/state/list.svelte.ts (ListEntry,
// entryFromTitle, fromSaved) and list-actions.ts (fieldsOf).

import '../anilist/client.dart';
import '../anilist/types.dart';
import '../catalog/title.dart';

/// One title on the viewer's list, in AniList's own terms.
class ListEntry {
  const ListEntry({
    required this.mediaId,
    required this.status,
    required this.progress,
    this.id,
    this.progressVolumes,
    this.score,
    this.repeat,
    this.notes,
    this.private,
    this.priority,
    this.startedAt,
    this.completedAt,
    this.customLists,
  });

  factory ListEntry.fromSaved(AniListSavedEntry s) => ListEntry(
    id: s.id,
    mediaId: s.mediaId,
    status: s.status,
    progress: s.progress,
    progressVolumes: s.progressVolumes,
    score: s.score,
    repeat: s.repeat,
    notes: s.notes,
    private: s.private,
    priority: s.priority,
    startedAt: s.startedAt,
    completedAt: s.completedAt,
    // null stays null: not known isn't the same as on none
    customLists: switch (s.customLists) {
      final lists? => [
        for (final l in lists)
          if (l.enabled) l.name,
      ],
      null => null,
    },
  );

  /// The entry a title arrived with, or null when it isn't on the list.
  static ListEntry? fromTitle(Title title) {
    final me = title.me;
    if (me == null) return null;
    return ListEntry(
      mediaId: title.id,
      status: me.status,
      progress: me.progress,
      progressVolumes: me.volumes,
      score: me.score,
    );
  }

  /// AniList's list-entry id; null until AniList has returned one.
  final int? id;
  final int mediaId;
  final MediaListStatus status;
  final int progress;
  final int? progressVolumes;
  final double? score;
  final int? repeat;
  final String? notes;
  final bool? private;

  /// Up next order on Planning: higher comes first.
  final int? priority;
  final AniListDate? startedAt;
  final AniListDate? completedAt;

  /// The custom lists it's on, by name; null when not known yet.
  final List<String>? customLists;

  ({MediaListStatus status, int progress}) get brief => (status: status, progress: progress);

  /// This entry with [patch]'s fields applied.
  ListEntry apply(EntryInput patch, {int? id}) => ListEntry(
    id: id ?? this.id,
    mediaId: mediaId,
    status: patch.status ?? status,
    progress: patch.progress ?? progress,
    progressVolumes: patch.progressVolumes ?? progressVolumes,
    score: patch.score ?? score,
    repeat: patch.repeat ?? repeat,
    notes: patch.notes ?? notes,
    private: patch.private ?? private,
    priority: patch.priority ?? priority,
    startedAt: patch.startedAt ?? startedAt,
    completedAt: patch.completedAt ?? completedAt,
    customLists: patch.customLists ?? customLists,
  );

  ListEntry withId(int id) => apply(const EntryInput(), id: id);

  /// The saveable fields, to put the entry back as it was (Undo).
  EntryInput toInput() => EntryInput(
    status: status,
    progress: progress,
    progressVolumes: progressVolumes,
    score: score,
    repeat: repeat,
    notes: notes,
    private: private,
    priority: priority,
    startedAt: startedAt,
    completedAt: completedAt,
    customLists: customLists,
  );
}
