import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/season.dart';
import '../../core/gestures/haptics.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/toast.dart';
import 'browse_controller.dart';
import 'browse_params.dart';

/// Opens the filters as a draft: nothing changes until
/// Apply, which says how many titles match. Dragging the sheet away
/// discards the draft, and the toast offers Restore.
Future<void> showFilterSheet(BuildContext context, WidgetRef ref) async {
  final current = ref.read(browseProvider).state;
  final applied = await showModalBottomSheet<BrowseState>(
    context: context,
    // over the tab bar, not inside the tab
    useRootNavigator: true,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: Surface.s2,
    barrierColor: const Color(0x9913110F),
    builder: (_) => _FilterSheet(initial: current),
  );
  if (applied != null) {
    ref.read(browseProvider.notifier).apply(applied);
  } else if (_lastDraft != null && _lastDraft != current) {
    final draft = _lastDraft!;
    ref
        .read(toastProvider.notifier)
        .show(
          'Filters not applied',
          action: ToastAction('Restore', () => ref.read(browseProvider.notifier).apply(draft)),
        );
  }
  _lastDraft = null;
}

/// The draft as it was when the sheet closed, for Restore.
BrowseState? _lastDraft;

class _FilterSheet extends ConsumerStatefulWidget {
  const _FilterSheet({required this.initial});

  final BrowseState initial;

  @override
  ConsumerState<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends ConsumerState<_FilterSheet> {
  late BrowseState _draft = widget.initial;
  final _tagQuery = TextEditingController();

  /// The draft the Apply count was last asked for (debounced 300ms).
  late BrowseState _counted = widget.initial;
  Timer? _debounce;

  @override
  void dispose() {
    _tagQuery.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _set(BrowseState next) {
    setState(() => _draft = next);
    _lastDraft = next;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _counted = _draft);
    });
  }

  List<String> _toggle(List<String> list, String value) =>
      list.contains(value) ? ([...list]..remove(value)) : [...list, value];

  @override
  Widget build(BuildContext context) {
    final isAnime = ref.watch(modeProvider).isAnime;
    final signedIn = ref.watch(sessionProvider.select((s) => s.signedIn));
    final genres = ref.watch(genresProvider).value ?? const [];
    final tags = ref.watch(tagsProvider).value ?? const <String>[];
    final count = ref.watch(matchCountProvider(_counted));
    final mode = context.mode;
    final thisYear = DateTime.now().year;

    Widget chip(String label, bool selected, VoidCallback onTap) => FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) {
        unawaited(ref.read(hapticsProvider).play(Haptic.selection));
        onTap();
      },
      showCheckmark: false,
      labelStyle: AppType.body.copyWith(
        fontSize: 13,
        color: selected ? mode.onAccent : TextTone.high,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
      ),
      selectedColor: TextTone.high,
      backgroundColor: Surface.base,
      side: BorderSide(color: selected ? Colors.transparent : Surface.line),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
    );

    Widget section(String title, Widget child, {String? hint}) => Padding(
      padding: const EdgeInsets.only(bottom: Space.x6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title.toUpperCase(), style: AppType.overline.copyWith(color: TextTone.mid)),
              ),
              if (hint != null) Text(hint, style: AppType.caption.copyWith(color: TextTone.low)),
            ],
          ),
          const SizedBox(height: Space.x3),
          child,
        ],
      ),
    );

    /// A genre or tag left out: struck through, with a block icon, on no fill.
    Widget excluded(String label, VoidCallback onTap) => Semantics(
      container: true,
      label: 'Not $label',
      button: true,
      excludeSemantics: true,
      child: ActionChip(
        avatar: const Icon(Symbols.block_rounded, size: 16, color: TextTone.mid),
        label: Text(label),
        onPressed: () {
          unawaited(ref.read(hapticsProvider).play(Haptic.selection));
          onTap();
        },
        labelStyle: AppType.body.copyWith(
          fontSize: 13,
          color: TextTone.mid,
          decoration: TextDecoration.lineThrough,
          decorationColor: TextTone.mid,
        ),
        backgroundColor: Surface.base,
        side: const BorderSide(color: TextTone.low),
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(2))),
      ),
    );

    Widget wrap(List<Widget> children) => Wrap(spacing: Space.x2, runSpacing: Space.x2, children: children);

    final matches = count.value;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      // the keyboard (searching tags) pushes the sheet's content up
      builder: (context, scroll) => Padding(
        padding: EdgeInsets.only(bottom: keyboard),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(Space.x5, 0, Space.x3, Space.x2),
              child: Row(
                children: [
                  Expanded(child: Text('Filters', style: AppType.section)),
                  TextButton(
                    onPressed: _draft.hasFilters ? () => _set(_draft.withoutFilters()) : null,
                    child: const Text('Reset'),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(Space.x5, Space.x2, Space.x5, Space.x6),
                children: [
                  section(
                    'Sort',
                    wrap([
                      for (final s in BrowseSort.values)
                        chip(s.label, _draft.sort == s, () => _set(_draft.copyWith(sort: s))),
                    ]),
                  ),
                  section(
                    'Format',
                    wrap([
                      for (final f in formatsFor(isAnime: isAnime))
                        chip(
                          f.label,
                          _draft.formats.contains(f.key),
                          () => _set(_draft.copyWith(formats: _toggle(_draft.formats, f.key))),
                        ),
                    ]),
                  ),
                  section(
                    isAnime ? 'Airing status' : 'Publishing status',
                    wrap([
                      for (final s in statuses)
                        chip(
                          s.label,
                          _draft.status == s.key,
                          () => _set(_draft.copyWith(status: _draft.status == s.key ? '' : s.key)),
                        ),
                    ]),
                  ),
                  if (isAnime)
                    section(
                      'Season',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          wrap([
                            for (final s in MediaSeason.values)
                              chip(
                                s.api[0] + s.api.substring(1).toLowerCase(),
                                _draft.season == s,
                                () => _set(
                                  _draft.season == s ? _draft.copyWith(clearSeason: true) : _draft.copyWith(season: s),
                                ),
                              ),
                          ]),
                          const SizedBox(height: Space.x3),
                          SizedBox(
                            height: 40,
                            child: ListView(
                              scrollDirection: Axis.horizontal,
                              children: [
                                for (var y = thisYear + 1; y >= thisYear - 30; y--)
                                  Padding(
                                    padding: const EdgeInsets.only(right: Space.x2),
                                    child: chip(
                                      '$y',
                                      _draft.year == y,
                                      () => _set(
                                        _draft.year == y ? _draft.copyWith(clearYear: true) : _draft.copyWith(year: y),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    section(
                      'Country of origin',
                      wrap([
                        for (final c in countries)
                          chip(
                            c.long,
                            _draft.country == c.key,
                            () => _set(_draft.copyWith(country: _draft.country == c.key ? '' : c.key)),
                          ),
                      ]),
                    ),
                  section(
                    'Score',
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _draft.scoreMin == 0 && _draft.scoreMax == maxScore
                              ? 'Any score'
                              : '${_draft.scoreMin.toStringAsFixed(1)} – ${_draft.scoreMax.toStringAsFixed(1)}',
                          style: AppType.numeric,
                        ),
                        RangeSlider(
                          values: RangeValues(_draft.scoreMin, _draft.scoreMax),
                          max: maxScore,
                          divisions: 20,
                          activeColor: mode.accent,
                          inactiveColor: Surface.s4,
                          labels: RangeLabels(_draft.scoreMin.toStringAsFixed(1), _draft.scoreMax.toStringAsFixed(1)),
                          onChanged: (v) {
                            // the thumbs stay at least 0.5 apart
                            if (v.end - v.start < 0.5) return;
                            if (v.start != _draft.scoreMin || v.end != _draft.scoreMax) {
                              unawaited(ref.read(hapticsProvider).play(Haptic.selection));
                            }
                            _set(_draft.copyWith(scoreMin: v.start, scoreMax: v.end));
                          },
                        ),
                      ],
                    ),
                  ),
                  if (signedIn)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text('Hide titles on my list', style: AppType.body),
                      value: _draft.hideOnList,
                      activeTrackColor: mode.accent,
                      onChanged: (v) => _set(_draft.copyWith(hideOnList: v)),
                    ),
                  // a genre goes in on the first tap, out on the second, and back to neither on the third
                  if (genres.isNotEmpty)
                    section(
                      'Genres',
                      hint: 'Tap twice to exclude',
                      wrap([
                        for (final g in genres)
                          if (_draft.notGenres.contains(g))
                            excluded(g, () => _set(_draft.copyWith(notGenres: _toggle(_draft.notGenres, g))))
                          else
                            chip(
                              g,
                              _draft.genres.contains(g),
                              () => _set(
                                _draft.genres.contains(g)
                                    ? _draft.copyWith(
                                        genres: _toggle(_draft.genres, g),
                                        notGenres: [..._draft.notGenres, g],
                                      )
                                    : _draft.copyWith(genres: [..._draft.genres, g]),
                              ),
                            ),
                      ]),
                    ),
                  if (tags.isNotEmpty)
                    section(
                      'Tags',
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _tagQuery,
                            // scrolled up far enough that the matches show above the keyboard
                            scrollPadding: const EdgeInsets.only(top: 20, bottom: 160),
                            onChanged: (_) => setState(() {}),
                            textInputAction: TextInputAction.done,
                            onSubmitted: (q) {
                              final first = matchTags(tags, q, [..._draft.tags, ..._draft.notTags]).firstOrNull;
                              if (first == null) return;
                              _tagQuery.clear();
                              _set(_draft.copyWith(tags: [..._draft.tags, first]));
                            },
                            style: AppType.body,
                            decoration: InputDecoration(
                              hintText: 'Search ${tags.length > 100 ? '${tags.length ~/ 100 * 100}+ ' : ''}tags…',
                              prefixIcon: const Icon(Symbols.sell_rounded, size: 20),
                              isDense: true,
                            ),
                          ),
                          if (matchTags(tags, _tagQuery.text, [..._draft.tags, ..._draft.notTags]) case final hits
                              when hits.isNotEmpty) ...[
                            const SizedBox(height: Space.x3),
                            // tap a match to add it; its block button leaves it out instead
                            wrap([
                              for (final t in hits)
                                InputChip(
                                  label: Text(t),
                                  labelStyle: AppType.body.copyWith(fontSize: 13),
                                  backgroundColor: Surface.base,
                                  side: const BorderSide(color: Surface.line),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(2)),
                                  ),
                                  onPressed: () {
                                    unawaited(ref.read(hapticsProvider).play(Haptic.selection));
                                    _tagQuery.clear();
                                    _set(_draft.copyWith(tags: [..._draft.tags, t]));
                                  },
                                  deleteIcon: const Icon(Symbols.block_rounded, size: 16),
                                  deleteButtonTooltipMessage: 'Exclude tag $t',
                                  onDeleted: () {
                                    unawaited(ref.read(hapticsProvider).play(Haptic.selection));
                                    _tagQuery.clear();
                                    _set(_draft.copyWith(notTags: [..._draft.notTags, t]));
                                  },
                                ),
                            ]),
                          ] else if (_tagQuery.text.trim().isNotEmpty) ...[
                            const SizedBox(height: Space.x2),
                            Text('No tag matches that', style: AppType.caption.copyWith(color: TextTone.mid)),
                          ],
                          if (_draft.tags.isNotEmpty) ...[
                            const SizedBox(height: Space.x3),
                            wrap([
                              for (final t in _draft.tags)
                                InputChip(
                                  label: Text(t),
                                  labelStyle: AppType.body.copyWith(fontSize: 13),
                                  backgroundColor: Surface.s3,
                                  side: BorderSide.none,
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(2)),
                                  ),
                                  deleteIcon: const Icon(Symbols.close_rounded, size: 16),
                                  deleteButtonTooltipMessage: 'Remove tag $t',
                                  onDeleted: () => _set(_draft.copyWith(tags: [..._draft.tags]..remove(t))),
                                ),
                            ]),
                          ],
                          if (_draft.notTags.isNotEmpty) ...[
                            const SizedBox(height: Space.x3),
                            wrap([
                              for (final t in _draft.notTags)
                                InputChip(
                                  avatar: const Icon(Symbols.block_rounded, size: 16, color: TextTone.mid),
                                  label: Text(t),
                                  labelStyle: AppType.body.copyWith(
                                    fontSize: 13,
                                    color: TextTone.mid,
                                    decoration: TextDecoration.lineThrough,
                                    decorationColor: TextTone.mid,
                                  ),
                                  backgroundColor: Surface.base,
                                  side: const BorderSide(color: TextTone.low),
                                  shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.all(Radius.circular(2)),
                                  ),
                                  deleteIcon: const Icon(Symbols.close_rounded, size: 16),
                                  deleteButtonTooltipMessage: 'Stop excluding $t',
                                  onDeleted: () => _set(_draft.copyWith(notTags: [..._draft.notTags]..remove(t))),
                                ),
                            ]),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // Apply waits until the keyboard is down, leaving room for the matches
            if (keyboard == 0)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(Space.x5, Space.x2, Space.x5, Space.x3),
                  child: FilledButton(
                    onPressed: () {
                      _lastDraft = null;
                      Navigator.of(context).pop(_draft);
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      backgroundColor: TextTone.high,
                      foregroundColor: Surface.base,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
                      textStyle: AppType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Symbols.check_rounded, size: 20),
                        const SizedBox(width: Space.x2),
                        Text(
                          matches == null || count.isLoading || _counted != _draft
                              ? 'Apply'
                              : 'Show ${formatMatchCount(matches)} ${matches == 1 ? 'result' : 'results'}',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The current season's year, for the year strip's default position.
int get currentSeasonYear => currentSeason().year;
