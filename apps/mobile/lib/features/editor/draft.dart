// The list editor's entry, ported from apps/web/src/lib/editor/draft.ts.
// On mobile the editor saves as you go, so `changes` is what each save sends.

import '../../core/anilist/client.dart';
import '../../core/anilist/types.dart';
import '../../core/list/list_entry.dart';

class EntryDraft {
  const EntryDraft({
    required this.status,
    this.progress = 0,
    this.progressVolumes = 0,
    this.score = 0,
    this.startedAt = AniListDate.empty,
    this.completedAt = AniListDate.empty,
    this.repeat = 0,
    this.notes = '',
    this.private = false,
    this.customLists = const [],
  });

  /// The draft for an entry, or for a title not on the list yet (Planning).
  factory EntryDraft.from(ListEntry? entry) => EntryDraft(
    status: entry?.status ?? MediaListStatus.planning,
    progress: entry?.progress ?? 0,
    progressVolumes: entry?.progressVolumes ?? 0,
    score: entry?.score ?? 0,
    startedAt: entry?.startedAt ?? AniListDate.empty,
    completedAt: entry?.completedAt ?? AniListDate.empty,
    repeat: entry?.repeat ?? 0,
    notes: entry?.notes ?? '',
    private: entry?.private ?? false,
    customLists: entry?.customLists ?? const [],
  );

  final MediaListStatus status;
  final int progress;
  final int progressVolumes;

  /// In the viewer's score format; 0 = not scored.
  final double score;
  final AniListDate startedAt;
  final AniListDate completedAt;
  final int repeat;
  final String notes;
  final bool private;

  /// The custom lists it's on, by name, in the account's order.
  final List<String> customLists;

  EntryDraft copyWith({
    MediaListStatus? status,
    int? progress,
    int? progressVolumes,
    double? score,
    AniListDate? startedAt,
    AniListDate? completedAt,
    int? repeat,
    String? notes,
    bool? private,
    List<String>? customLists,
  }) => EntryDraft(
    status: status ?? this.status,
    progress: progress ?? this.progress,
    progressVolumes: progressVolumes ?? this.progressVolumes,
    score: score ?? this.score,
    startedAt: startedAt ?? this.startedAt,
    completedAt: completedAt ?? this.completedAt,
    repeat: repeat ?? this.repeat,
    notes: notes ?? this.notes,
    private: private ?? this.private,
    customLists: customLists ?? this.customLists,
  );
}

/// Puts the entry on a custom list, or takes it off, keeping [order] (the
/// account's order of its lists).
EntryDraft withCustomList(EntryDraft d, String name, List<String> order) {
  final on = {...d.customLists};
  if (!on.remove(name)) on.add(name);
  return d.copyWith(
    customLists: [
      for (final n in order)
        if (on.contains(n)) n,
    ],
  );
}

/// Every custom list of the title's type, in the account's order: its own
/// settings (empty lists too), then any the entry names that aren't there.
List<String> customListNames(List<String> account, List<({String name, bool enabled})>? entry) => [
  ...account,
  for (final l in entry ?? const <({String name, bool enabled})>[])
    if (!account.contains(l.name)) l.name,
];

String _listKey(List<String> names) => ([...names]..sort()).join('\n');

/// The full entry arrived after the sheet opened from a card: [draft]
/// keeps each field edited since [opened] (what the card knew), and takes
/// [loaded]'s value for the rest. Without this, the next save would send
/// the card's blanks (no score, no dates, no custom lists) as changes.
EntryDraft mergeLoaded({required EntryDraft opened, required EntryDraft draft, required EntryDraft loaded}) =>
    EntryDraft(
      status: draft.status != opened.status ? draft.status : loaded.status,
      progress: draft.progress != opened.progress ? draft.progress : loaded.progress,
      progressVolumes: draft.progressVolumes != opened.progressVolumes ? draft.progressVolumes : loaded.progressVolumes,
      score: draft.score != opened.score ? draft.score : loaded.score,
      startedAt: draft.startedAt != opened.startedAt ? draft.startedAt : loaded.startedAt,
      completedAt: draft.completedAt != opened.completedAt ? draft.completedAt : loaded.completedAt,
      repeat: draft.repeat != opened.repeat ? draft.repeat : loaded.repeat,
      notes: draft.notes != opened.notes ? draft.notes : loaded.notes,
      private: draft.private != opened.private ? draft.private : loaded.private,
      customLists: _listKey(draft.customLists) != _listKey(opened.customLists) ? draft.customLists : loaded.customLists,
    );

/// What the editor needs to know about the title itself.
class DraftTotals {
  const DraftTotals({this.total, this.volumes});

  /// Episodes (anime) or chapters (manga); null when unknown or ongoing.
  final int? total;

  /// Manga volumes; null when unknown.
  final int? volumes;
}

AniListDate today([DateTime? now]) => AniListDate.fromDateTime(now ?? DateTime.now());

/// Picking a status, with the design's smart defaults: starting fills the
/// start date with today; completing fills progress to the total and the
/// finish date. No start date is guessed on completing: it began earlier,
/// on a day we don't know.
EntryDraft withStatus(EntryDraft d, MediaListStatus status, DraftTotals totals, {AniListDate? on}) {
  final day = on ?? today();
  var next = d.copyWith(status: status);
  if (status == MediaListStatus.current && next.startedAt.isEmpty) next = next.copyWith(startedAt: day);
  if (status == MediaListStatus.completed) {
    if (totals.total != null && totals.total! > 0) next = next.copyWith(progress: totals.total);
    if (totals.volumes != null && totals.volumes! > 0) next = next.copyWith(progressVolumes: totals.volumes);
    if (next.completedAt.isEmpty) next = next.copyWith(completedAt: day);
  }
  return next;
}

/// Progress, clamped to 0…total; never changes the status on its own.
EntryDraft withProgress(EntryDraft d, int progress, DraftTotals totals) =>
    d.copyWith(progress: progress.clamp(0, totals.total ?? 1 << 31));

EntryDraft withVolumes(EntryDraft d, int volumes, DraftTotals totals) =>
    d.copyWith(progressVolumes: volumes.clamp(0, totals.volumes ?? 1 << 31));

/// The last episode/chapter is reached but the entry isn't Completed yet.
bool offersCompletion(EntryDraft d, DraftTotals totals) =>
    totals.total != null && totals.total! > 0 && d.progress >= totals.total! && d.status != MediaListStatus.completed;

/// Only the fields that differ, in SaveMediaListEntry's terms.
EntryInput changes(EntryDraft initial, EntryDraft d) => EntryInput(
  status: d.status != initial.status ? d.status : null,
  progress: d.progress != initial.progress ? d.progress : null,
  progressVolumes: d.progressVolumes != initial.progressVolumes ? d.progressVolumes : null,
  score: d.score != initial.score ? d.score : null,
  startedAt: d.startedAt != initial.startedAt ? d.startedAt : null,
  completedAt: d.completedAt != initial.completedAt ? d.completedAt : null,
  repeat: d.repeat != initial.repeat ? d.repeat : null,
  notes: d.notes != initial.notes ? d.notes : null,
  private: d.private != initial.private ? d.private : null,
  customLists: _listKey(d.customLists) != _listKey(initial.customLists) ? d.customLists : null,
);

bool isDirty(EntryDraft initial, EntryDraft d) => !changes(initial, d).isEmpty;
