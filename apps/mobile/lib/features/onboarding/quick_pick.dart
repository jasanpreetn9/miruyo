// The quick-pick (Home 1d, Gestures · Onboarding 19): a grid of popular
// titles to mark as seen, for an empty list. Tap one, or drag across the
// posters to pick several: the first poster you touch decides whether the
// drag adds or removes. Hold one to read about it. Picks go on the list as
// Completed.

import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/auth/session.dart';
import '../../core/catalog/title.dart';
import '../../core/gestures/haptics.dart';
import '../../core/list/list_store.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui/toast.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/peek.dart';

/// Puts [titles] on the list as Completed. Resolves to how many failed.
Future<int> addQuickPicks(WidgetRef ref, List<Title> titles) async {
  final list = ref.read(listStoreProvider.notifier);
  final results = await Future.wait([for (final t in titles) list.setStatus(t.id, MediaListStatus.completed)]);
  final failed = results.where((ok) => !ok).length;
  if (failed == 0) {
    unawaited(ref.read(hapticsProvider).play(Haptic.success));
    final n = titles.length;
    ref.read(toastProvider.notifier).show('Added $n ${n == 1 ? 'title' : 'titles'} to Completed');
  }
  return failed;
}

/// Three across, no scrolling of its own. [picked] is owned by the caller so
/// it survives going back a step.
class QuickPickGrid extends ConsumerStatefulWidget {
  const QuickPickGrid({super.key, required this.titles, required this.picked, required this.onChanged});

  final List<Title> titles;
  final Set<int> picked;
  final ValueChanged<Set<int>> onChanged;

  static const columns = 3;
  static const gap = Space.x2;

  @override
  ConsumerState<QuickPickGrid> createState() => _QuickPickGridState();
}

class _QuickPickGridState extends ConsumerState<QuickPickGrid> {
  /// While painting: whether the drag adds or removes, and the posters it
  /// has already passed.
  bool? _adding;
  final _painted = <int>{};

  int? _indexAt(Offset p, double width) {
    final cell = (width - QuickPickGrid.gap * (QuickPickGrid.columns - 1)) / QuickPickGrid.columns;
    final col = (p.dx / (cell + QuickPickGrid.gap)).floor();
    final row = (p.dy / (cell * 1.5 + QuickPickGrid.gap)).floor();
    if (col < 0 || col >= QuickPickGrid.columns || row < 0) return null;
    final i = row * QuickPickGrid.columns + col;
    return i < widget.titles.length ? i : null;
  }

  /// The selection while a drag paints: several posters can change before
  /// the parent rebuilds, so each builds on the last rather than on
  /// [QuickPickGrid.picked].
  Set<int>? _working;

  void _set(int index, bool on) {
    final id = widget.titles[index].id;
    final current = _working ?? widget.picked;
    if (current.contains(id) == on) return;
    unawaited(ref.read(hapticsProvider).play(Haptic.selection));
    final next = on ? {...current, id} : ({...current}..remove(id));
    if (_working != null) _working = next;
    widget.onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.mode.accent;
    return LayoutBuilder(
      builder: (context, box) {
        final width = box.maxWidth;
        // hold a poster (still, 450ms) to read about it before picking
        return RawGestureDetector(
          gestures: {
            LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
              () => LongPressGestureRecognizer(duration: GestureSpec.hold, debugOwner: this),
              (r) => r.onLongPressStart = (d) {
                final i = _indexAt(d.localPosition, width);
                if (i == null) return;
                unawaited(ref.read(hapticsProvider).play(Haptic.medium));
                unawaited(showPeek(context, widget.titles[i]));
              },
            ),
          },
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) {
              final i = _indexAt(d.localPosition, width);
              if (i != null) _set(i, !widget.picked.contains(widget.titles[i].id));
            },
            // painting owns drags that start on the grid, from where the finger
            // first touched, so the poster it started on counts
            dragStartBehavior: DragStartBehavior.down,
            onPanStart: (d) {
              final i = _indexAt(d.localPosition, width);
              if (i == null) return;
              _adding = !widget.picked.contains(widget.titles[i].id);
              _working = widget.picked;
              _painted
                ..clear()
                ..add(i);
              _set(i, _adding!);
            },
            onPanUpdate: (d) {
              final i = _indexAt(d.localPosition, width);
              if (_adding == null || i == null || !_painted.add(i)) return;
              _set(i, _adding!);
            },
            onPanEnd: (_) {
              _adding = null;
              _working = null;
            },
            child: GridView.count(
              crossAxisCount: QuickPickGrid.columns,
              crossAxisSpacing: QuickPickGrid.gap,
              mainAxisSpacing: QuickPickGrid.gap,
              childAspectRatio: 2 / 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                for (final t in widget.titles) _Tile(title: t, picked: widget.picked.contains(t.id), accent: accent),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.title, required this.picked, required this.accent});

  final Title title;
  final bool picked;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: picked,
      label: title.title,
      excludeSemantics: true,
      child: AnimatedScale(
        duration: Motion.press,
        scale: picked ? 0.94 : 1,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CoverImage(title: title),
            AnimatedContainer(
              duration: Motion.press,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(Corner.sm),
                color: picked ? accent.withValues(alpha: 0.25) : Colors.transparent,
                border: Border.all(color: picked ? accent : Colors.transparent, width: 3),
              ),
            ),
            if (picked)
              Positioned(
                top: 6,
                right: 6,
                child: Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
                  child: Icon(Symbols.check_rounded, size: 16, weight: 700, color: context.mode.onAccent),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The step's heading, hint and buttons, around the grid: used by the
/// first-run setup and by Home's empty-list card.
class QuickPick extends ConsumerStatefulWidget {
  const QuickPick({
    super.key,
    required this.titles,
    required this.picked,
    required this.onPicked,
    required this.onDone,
    required this.onSkip,
    this.heading = 'Seen any of these?',
  });

  final List<Title> titles;
  final Set<int> picked;
  final ValueChanged<Set<int>> onPicked;

  /// After the picks were saved.
  final VoidCallback onDone;
  final VoidCallback onSkip;
  final String heading;

  @override
  ConsumerState<QuickPick> createState() => _QuickPickState();
}

class _QuickPickState extends ConsumerState<QuickPick> {
  bool _saving = false;
  String? _error;

  Future<void> _add() async {
    final picks = [
      for (final t in widget.titles)
        if (widget.picked.contains(t.id)) t,
    ];
    if (picks.isEmpty || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final failed = await addQuickPicks(ref, picks);
    if (!mounted) return;
    setState(() {
      _saving = false;
      _error = failed > 0 ? "Couldn't add $failed of them: AniList didn't respond. Try again." : null;
    });
    if (failed == 0) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final n = widget.picked.length;
    final isAnime = ref.watch(modeProvider).isAnime;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(widget.heading, style: AppType.heading.copyWith(fontSize: 26)),
        const SizedBox(height: Space.x2),
        Text(
          "Tap anything you've ${isAnime ? 'seen' : 'read'}, or drag across posters to pick several at once. "
          'They go on your list as Completed.',
          style: AppType.body.copyWith(color: TextTone.mid),
        ),
        const SizedBox(height: Space.x4),
        QuickPickGrid(titles: widget.titles, picked: widget.picked, onChanged: widget.onPicked),
        if (_error != null) ...[
          const SizedBox(height: Space.x3),
          Text(_error!, style: AppType.body.copyWith(color: Accent.danger)),
        ],
        const SizedBox(height: Space.x4),
        FilledButton(
          onPressed: n == 0 || _saving ? null : _add,
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: TextTone.high,
            foregroundColor: Surface.base,
            disabledBackgroundColor: Surface.s3,
            disabledForegroundColor: TextTone.low,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(2)),
            textStyle: AppType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600),
          ),
          child: Text(
            _saving
                ? 'Adding…'
                : n == 0
                ? 'Pick a few'
                : 'Add $n to Completed',
          ),
        ),
        TextButton(
          onPressed: _saving ? null : widget.onSkip,
          style: TextButton.styleFrom(foregroundColor: TextTone.mid, minimumSize: const Size.fromHeight(44)),
          child: const Text('Skip for now'),
        ),
      ],
    );
  }
}
