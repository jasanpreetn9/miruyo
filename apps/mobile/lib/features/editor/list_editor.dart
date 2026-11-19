import 'dart:async';

import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/client.dart';
import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/mode.dart';
import '../../core/catalog/score.dart';
import '../../core/catalog/status.dart';
import '../../core/catalog/title.dart';
import '../../core/gestures/haptics.dart';
import '../../core/list/guard.dart';
import '../../core/list/list_actions.dart';
import '../../core/list/list_entry.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/count_stepper.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/hold_to_confirm.dart';
import '../../widgets/score_cells.dart';
import '../list/list_data.dart' show listCollectionProvider;
import 'draft.dart';

/// Opens the list editor (04, Gestures · List editor 20) for [title]: a
/// sheet that saves to AniList as you change things, so pulling it down just
/// closes it. Only a half-typed note asks first. Signed out, it leads to
/// Log In instead.
Future<void> showListEditor(BuildContext context, WidgetRef ref, Title title) async {
  if (!canEditList(context, ref)) return;
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Surface.s2,
    barrierColor: const Color(0x9913110F),
    builder: (_) => _ListEditor(title: title),
  );
}

class _ListEditor extends ConsumerStatefulWidget {
  const _ListEditor({required this.title});

  final Title title;

  @override
  ConsumerState<_ListEditor> createState() => _ListEditorState();
}

class _ListEditorState extends ConsumerState<_ListEditor> {
  Title get title => widget.title;
  DraftTotals get _totals => DraftTotals(total: title.total, volumes: title.vol);

  /// The entry as the sheet opened, for the closing toast's Undo.
  late final ListEntry? _opened = ref.read(listStoreProvider).entryFor(title);

  /// What the card knew as the sheet opened: edits are measured from here
  /// when the full entry arrives.
  late final EntryDraft _openedDraft = EntryDraft.from(_opened);

  /// What AniList holds as of the last save.
  late EntryDraft _saved = _openedDraft;
  late EntryDraft _draft = _saved;

  /// The status and finish date before progress reached the total and
  /// moved the entry to Completed, for the inline Undo.
  ({MediaListStatus status, AniListDate completedAt})? _autoCompleted;

  late final _notes = TextEditingController(text: _draft.notes);
  Timer? _debounce;
  bool _loading = false;
  bool _deleted = false;
  bool _savedOnce = false;

  /// The custom lists AniList named with the full entry (on it or not).
  List<({String name, bool enabled})>? _entryLists;

  /// Whether the lists it's on are known: a new title is on none; one on the
  /// list waits for its full entry. Until then the chips can't be toggled, as
  /// the set saved would leave out the lists it's already on.
  late bool _listsKnown = _opened == null;

  /// The lists it was on as the full entry arrived, for the closing toast's Undo.
  List<String>? _openedLists;

  /// A save changed its custom lists: My List's collection reloads on close.
  bool _listsChanged = false;

  /// Read once, while mounted: the sheet may close before a save finishes.
  late final ProviderContainer _container;

  @override
  void initState() {
    super.initState();
    _container = ProviderScope.containerOf(context, listen: false);
    unawaited(_loadFull());
  }

  /// Opened from a card, the store only knows status and progress: fetch the
  /// rest (score, dates, notes) and take it for fields not edited yet.
  Future<void> _loadFull() async {
    final userId = ref.read(sessionProvider).user?.id;
    if (userId == null || _opened == null) return;
    setState(() => _loading = true);
    try {
      final full = await ref.read(anilistClientProvider).fetchEntry(userId, title.id);
      if (!mounted || full == null) return;
      final loaded = EntryDraft.from(ListEntry.fromSaved(full));
      setState(() {
        _entryLists = full.customLists;
        _openedLists = loaded.customLists;
        _listsKnown = true;
        // edits made (and maybe saved) before it arrived stay; the rest is AniList's
        _saved = mergeLoaded(opened: _openedDraft, draft: _saved, loaded: loaded);
        _draft = mergeLoaded(opened: _openedDraft, draft: _draft, loaded: loaded);
        if (_notes.text == _openedDraft.notes) _notes.text = _draft.notes;
      });
    } catch (_) {
      // the editor still works; it just saves only what's edited
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    if (_listsChanged) {
      // My List's custom tabs come from the list collection: load it again,
      // once, after the sheet has gone
      final container = _container;
      final mode = title.isAnime ? Mode.anime : Mode.manga;
      unawaited(Future.microtask(() => container.invalidate(listCollectionProvider(mode))));
    }
    _debounce?.cancel();
    _notes.dispose();
    super.dispose();
  }

  /// Applies an edit now and saves it shortly (steppers repeat quickly, so
  /// a burst of steps becomes one save).
  void _edit(EntryDraft next, {bool immediate = false}) {
    setState(() => _draft = next);
    _debounce?.cancel();
    if (immediate) {
      unawaited(_save());
    } else {
      _debounce = Timer(const Duration(milliseconds: 600), () => unawaited(_save()));
    }
  }

  Future<void> _save() async {
    _debounce?.cancel();
    if (_deleted) return;
    // notes are saved on their own, when the field is done
    final target = _draft.copyWith(notes: _saved.notes);
    final patch = changes(_saved, target);
    if (patch.isEmpty) return;
    final previous = _saved;
    _saved = target;
    _savedOnce = true;
    final ok = await ref
        .read(listStoreProvider.notifier)
        .update(title.id, patch, base: ListEntry.fromTitle(title), label: title.title);
    if (!ok && mounted) {
      _saved = previous;
      ref.read(listActionsProvider).failed(title);
    } else if (ok && patch.customLists != null) {
      _listsChanged = true;
    }
  }

  Future<void> _saveNotes() async {
    final notes = _notes.text.trim();
    if (notes == _saved.notes) return;
    setState(() => _draft = _draft.copyWith(notes: notes));
    _saved = _saved.copyWith(notes: notes);
    _savedOnce = true;
    await ref
        .read(listStoreProvider.notifier)
        .update(
          title.id,
          EntryInput(notes: notes),
          base: ListEntry.fromTitle(title),
          label: title.title,
        );
  }

  void _status(MediaListStatus status) {
    unawaited(ref.read(hapticsProvider).play(Haptic.selection));
    _autoCompleted = null;
    _edit(withStatus(_draft, status, _totals), immediate: true);
  }

  void _progress(int n) {
    final next = withProgress(_draft, n, _totals);
    // reaching the total completes it, as +1 does everywhere, with Undo here
    if (n > _draft.progress && offersCompletion(next, _totals)) {
      _autoCompleted = (status: _draft.status, completedAt: _draft.completedAt);
      unawaited(ref.read(hapticsProvider).play(Haptic.success));
      _edit(withStatus(next, MediaListStatus.completed, _totals));
    } else {
      // a +1 on something planned means it's started
      final started = n > _draft.progress && _draft.status == MediaListStatus.planning;
      _edit(started ? withStatus(next, MediaListStatus.current, _totals) : next);
    }
  }

  void _undoComplete() {
    final was = _autoCompleted;
    if (was == null) return;
    _autoCompleted = null;
    _edit(_draft.copyWith(status: was.status, completedAt: was.completedAt), immediate: true);
  }

  Future<void> _pickDate({required bool start}) async {
    final current = start ? _draft.startedAt : _draft.completedAt;
    final initial = current.isEmpty ? DateTime.now() : DateTime(current.year!, current.month ?? 1, current.day ?? 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1960),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    final date = AniListDate.fromDateTime(picked);
    _edit(start ? _draft.copyWith(startedAt: date) : _draft.copyWith(completedAt: date), immediate: true);
  }

  Future<void> _delete() async {
    _deleted = true;
    _debounce?.cancel();
    Navigator.of(context).pop();
    await ref.read(listActionsProvider).removeFromList(title, base: _opened);
  }

  /// Leaving: send what's pending, and ask about a half-typed note.
  Future<bool> _beforeClose() async {
    await _save();
    if (!mounted) return true;
    if (_notes.text.trim() != _saved.notes && !_deleted) {
      final keep = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Keep your note?'),
          content: const Text("You've typed a note that isn't saved yet."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Discard')),
            TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save note')),
          ],
        ),
      );
      if (keep == null) return false;
      if (keep) await _saveNotes();
    }
    if (_savedOnce && !_deleted) {
      // Undo puts its custom lists back too, when they were known
      final lists = _openedLists;
      final previous = lists == null ? _opened : _opened?.apply(EntryInput(customLists: lists));
      ref.read(listActionsProvider).confirmSaved(title, previous, _saved.status);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final format = ref.watch(sessionProvider.select((s) => s.scoreFormat));
    final mode = context.mode;
    final isAnime = title.isAnime;
    final onList = _opened != null || _savedOnce;
    final unit = isAnime ? 'episode' : 'chapter';

    Widget label(String text, [Widget? trailing]) => Padding(
      padding: const EdgeInsets.only(top: Space.x6, bottom: Space.x3),
      child: Row(
        children: [
          Text(text.toUpperCase(), style: AppType.overline.copyWith(color: TextTone.mid)),
          const Spacer(),
          ?trailing,
        ],
      ),
    );

    Widget dateRow(String name, AniListDate value, {required bool start}) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(name, style: AppType.body),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // a date the status implies but that isn't set yet: one tap fills in today
          if (value.isEmpty &&
              (start ? _draft.status != MediaListStatus.planning : _draft.status == MediaListStatus.completed))
            TextButton(
              onPressed: () => _edit(
                start ? _draft.copyWith(startedAt: today()) : _draft.copyWith(completedAt: today()),
                immediate: true,
              ),
              style: TextButton.styleFrom(foregroundColor: mode.accentText),
              child: const Text('Today'),
            ),
          Text(
            value.isEmpty ? 'Not set' : _dateLabel(value),
            style: AppType.numeric.copyWith(color: value.isEmpty ? TextTone.low : TextTone.high),
          ),
          if (!value.isEmpty)
            IconButton(
              tooltip: 'Clear $name',
              icon: const Icon(Symbols.close_rounded, size: 18, color: TextTone.mid),
              onPressed: () => _edit(
                start ? _draft.copyWith(startedAt: AniListDate.empty) : _draft.copyWith(completedAt: AniListDate.empty),
                immediate: true,
              ),
            ),
        ],
      ),
      onTap: () => _pickDate(start: start),
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await _beforeClose() && context.mounted) Navigator.of(context).pop();
      },
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: EdgeInsets.fromLTRB(Space.x5, 0, Space.x5, Space.x8 + MediaQuery.viewInsetsOf(context).bottom),
          children: [
            Row(
              children: [
                SizedBox(width: 48, height: 72, child: CoverImage(title: title, thumb: true, radius: 6)),
                const SizedBox(width: Space.x3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: AppType.title),
                      const SizedBox(height: 2),
                      Text(
                        _loading
                            ? 'Loading your entry…'
                            : (onList ? 'Saved to AniList as you go' : 'Not on your list yet'),
                        style: AppType.caption.copyWith(color: TextTone.low, fontWeight: FontWeight.w400),
                      ),
                    ],
                  ),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  child: Text(
                    'Done',
                    style: AppType.body.copyWith(fontWeight: FontWeight.w600, color: mode.accentText),
                  ),
                ),
              ],
            ),
            label('Status'),
            Wrap(
              spacing: Space.x2,
              runSpacing: Space.x2,
              children: [
                for (final s in listStatuses)
                  ChoiceChip(
                    avatar: Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: statusColor[s], shape: BoxShape.circle),
                    ),
                    label: Text(statusLabel(s, isAnime: isAnime)),
                    selected: onList && _draft.status == s,
                    onSelected: (_) => _status(s),
                    showCheckmark: false,
                    selectedColor: statusColor[s]!.withValues(alpha: 0.18),
                    backgroundColor: Surface.base,
                    side: BorderSide(color: onList && _draft.status == s ? statusColor[s]! : Surface.line),
                    labelStyle: AppType.body.copyWith(
                      fontSize: 13,
                      fontWeight: onList && _draft.status == s ? FontWeight.w600 : FontWeight.w400,
                    ),
                    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
                  ),
              ],
            ),
            label(isAnime ? 'Episodes' : 'Chapters'),
            CountStepper(value: _draft.progress, max: title.total, unit: unit, onChanged: _progress),
            if (_autoCompleted != null)
              Container(
                margin: const EdgeInsets.only(top: Space.x3),
                padding: const EdgeInsets.fromLTRB(Space.x3, Space.x1, Space.x1, Space.x1),
                decoration: BoxDecoration(
                  color: Accent.green.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(2),
                ),
                child: Row(
                  children: [
                    const Icon(Symbols.task_alt_rounded, size: 20, color: Accent.green),
                    const SizedBox(width: Space.x2),
                    Expanded(child: Text('Moved to Completed', style: AppType.body)),
                    TextButton(onPressed: _undoComplete, child: const Text('Undo')),
                  ],
                ),
              ),
            if (!isAnime) ...[
              label('Volumes'),
              CountStepper(
                value: _draft.progressVolumes,
                max: title.vol,
                unit: 'volume',
                onChanged: (v) => _edit(withVolumes(_draft, v, _totals)),
              ),
            ],
            label(
              'Score',
              // unscored: say how, instead of a bare dash
              _draft.score > 0
                  ? Text(
                      formatScore(_draft.score, format),
                      style: AppType.numeric.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                    )
                  : Text('Tap or drag', style: AppType.caption.copyWith(color: TextTone.low)),
            ),
            ScoreCells(
              score: _draft.score,
              format: format,
              accent: title.colors.accent,
              onChanged: (v) => _edit(_draft.copyWith(score: v), immediate: true),
            ),
            label('Dates'),
            dateRow('Started', _draft.startedAt, start: true),
            dateRow('Finished', _draft.completedAt, start: false),
            label(isAnime ? 'Rewatches' : 'Rereads'),
            Row(
              children: [
                IconButton.outlined(
                  tooltip: 'One fewer',
                  onPressed: _draft.repeat > 0 ? () => _edit(_draft.copyWith(repeat: _draft.repeat - 1)) : null,
                  icon: const Icon(Symbols.remove_rounded),
                ),
                Expanded(
                  child: Text(
                    '${_draft.repeat}',
                    textAlign: TextAlign.center,
                    style: AppType.numeric.copyWith(fontSize: 18),
                  ),
                ),
                IconButton.outlined(
                  tooltip: 'One more',
                  onPressed: () => _edit(_draft.copyWith(repeat: _draft.repeat + 1)),
                  icon: const Icon(Symbols.add_rounded),
                ),
              ],
            ),
            label('Notes'),
            Focus(
              onFocusChange: (focused) {
                if (!focused) unawaited(_saveNotes());
              },
              child: TextField(
                controller: _notes,
                minLines: 2,
                maxLines: 6,
                textCapitalization: TextCapitalization.sentences,
                style: AppType.body,
                decoration: InputDecoration(
                  hintText: 'Only you can see these',
                  hintStyle: AppType.body.copyWith(color: TextTone.low),
                  filled: false,
                  border: UnderlineInputBorder(borderSide: const BorderSide(color: Surface.line)),
                  enabledBorder: UnderlineInputBorder(borderSide: const BorderSide(color: Surface.line)),
                ),
              ),
            ),
            if (customListNames(
                  ref.watch(sessionProvider.select((s) => s.user?.customLists(isAnime: isAnime) ?? const <String>[])),
                  _entryLists,
                )
                case final lists when lists.isNotEmpty) ...[
              const SizedBox(height: Space.x4),
              label('Custom lists'),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final name in lists)
                    FilterChip(
                      label: Text(name),
                      selected: _draft.customLists.contains(name),
                      onSelected: _listsKnown
                          ? (_) {
                              unawaited(ref.read(hapticsProvider).play(Haptic.selection));
                              _edit(withCustomList(_draft, name, lists), immediate: true);
                            }
                          : null,
                      showCheckmark: true,
                      checkmarkColor: Surface.base,
                      selectedColor: TextTone.high,
                      backgroundColor: Surface.base,
                      side: BorderSide(color: _draft.customLists.contains(name) ? TextTone.high : Surface.line),
                      labelStyle: AppType.body.copyWith(
                        fontSize: 13,
                        color: _draft.customLists.contains(name) ? Surface.base : TextTone.high,
                      ),
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
                      materialTapTargetSize: MaterialTapTargetSize.padded,
                    ),
                ],
              ),
            ],
            const SizedBox(height: Space.x2),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: Text('Private', style: AppType.body),
              subtitle: Text(
                'Hidden from your public AniList profile',
                style: AppType.caption.copyWith(color: TextTone.low, fontWeight: FontWeight.w400),
              ),
              value: _draft.private,
              activeTrackColor: mode.accent,
              onChanged: (v) => _edit(_draft.copyWith(private: v), immediate: true),
            ),
            if (onList) ...[
              const SizedBox(height: Space.x6),
              HoldToConfirm(
                label: 'Remove from list',
                icon: Symbols.delete_rounded,
                confirmTitle: 'Remove ${title.title} from your list?',
                onConfirmed: _delete,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

/// "Oct 9, 2026"; AniList dates can be partial.
String _dateLabel(AniListDate d) => [
  if (d.month != null) _months[d.month! - 1],
  if (d.day != null) '${d.day},',
  if (d.year != null) '${d.year}',
].join(' ');
