import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' hide Title;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/anilist/types.dart';
import '../../core/catalog/status.dart';
import '../../core/gestures/row_swipe.dart';
import '../../core/list/guard.dart';
import '../../core/list/list_actions.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import '../../widgets/cover_image.dart';
import '../../widgets/motion.dart';
import '../editor/list_editor.dart';
import '../editor/quick_actions.dart';
import 'list_data.dart';

/// A row's height, and the step between rows (row + gap).
const listRowHeight = 84.0;
const listRowExtent = listRowHeight + Space.x2;

/// The hold that lifts the selection in Edit: shorter than the 450ms quick
/// actions hold, which Edit pauses.
const carryHold = Duration(milliseconds: 300);

/// One My List row. Normally: tap for details, the cover for the
/// editor, and swipes (no +1 button): here the row grammar's directions
/// are swapped (right −1, short left +1), with a long left or a hold for
/// quick actions. In Edit: a selection circle,
/// tap to toggle, a 300ms hold to carry, and on Up next a drag handle.
class ListRowTile extends ConsumerWidget {
  const ListRowTile({
    super.key,
    required this.row,
    this.editing = false,
    this.selected = false,
    this.dimmed = false,
    this.onToggle,
    this.onPaint,
    this.carry,
    this.handle,
    this.demo,
  });

  final ListRow row;
  final bool editing;
  final bool selected;

  /// Selected rows dim while they're being carried.
  final bool dimmed;
  final VoidCallback? onToggle;

  /// Drags on the circle paint the selection: start, move, end.
  final PaintCallbacks? onPaint;

  /// The 300ms hold that lifts the selection.
  final CarryCallbacks? carry;

  /// The Up next drag handle, given only on Planning in Edit.
  final Widget? handle;

  /// The coach mark's demonstration of the swipes, on the first row.
  final ValueListenable<double>? demo;

  // eases in as it's built: loaded in place of a skeleton, or scrolled to
  @override
  Widget build(BuildContext context, WidgetRef ref) => Appear(child: _build(context, ref));

  Widget _build(BuildContext context, WidgetRef ref) {
    final title = row.title;
    final total = title.total;
    final done = row.status == MediaListStatus.completed || (total != null && total > 0 && row.progress >= total);
    final actions = ref.read(listActionsProvider);
    final accent = context.mode;

    void act(void Function() run) {
      if (canEditList(context, ref)) run();
    }

    final body = AnimatedOpacity(
      duration: Motion.overlay,
      opacity: dimmed ? 0.35 : 1,
      child: AnimatedContainer(
        duration: Motion.press,
        height: listRowHeight,
        padding: const EdgeInsets.fromLTRB(0, 6, 10, 6),
        // a ruled row, not a card; a selected row (editing) lifts and is outlined
        decoration: BoxDecoration(
          color: editing && selected ? Surface.s2 : Colors.transparent,
          border: editing && selected
              ? Border.all(color: accent.accent.withValues(alpha: 0.45))
              : const Border(bottom: BorderSide(color: Surface.line)),
        ),
        child: Row(
          children: [
            _Circle(editing: editing, selected: selected, onPaint: onPaint, accent: accent.accent),
            // the cover opens the list editor (the row itself opens the title)
            Semantics(
              button: !editing,
              label: editing ? null : 'Edit ${title.title}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: editing ? null : () => unawaited(showListEditor(context, ref, title)),
                child: SizedBox(
                  width: 48,
                  height: 72,
                  child: CoverImage(title: title, thumb: true, radius: 6, showMissing: false),
                ),
              ),
            ),
            const SizedBox(width: Space.x3),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.body.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          row.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.caption.copyWith(color: row.noteColor),
                        ),
                      ),
                      if (row.status != MediaListStatus.planning) ...[
                        const SizedBox(width: Space.x2),
                        Text(
                          '${title.isAnime ? '' : 'CH '}${row.progress} / ${total ?? '?'}',
                          style: AppType.numeric.copyWith(fontSize: 11, color: TextTone.mid),
                        ),
                      ],
                    ],
                  ),
                  // an unknown total has nothing to measure against, so no bar
                  if (row.status != MediaListStatus.planning &&
                      (row.status == MediaListStatus.completed || (total != null && total > 0))) ...[
                    const SizedBox(height: 6),
                    _Bar(
                      value: row.progress,
                      total: total,
                      full: row.status == MediaListStatus.completed,
                      // the status colour, as on Home and the posters
                      color: statusColor[row.status]!,
                    ),
                  ],
                ],
              ),
            ),
            ?handle,
          ],
        ),
      ),
    );

    if (editing) {
      return Semantics(
        selected: selected,
        button: true,
        label: title.title,
        hint: selected ? 'Double tap to deselect' : 'Double tap to select',
        child: RawGestureDetector(
          behavior: HitTestBehavior.opaque,
          gestures: {
            TapGestureRecognizer: GestureRecognizerFactoryWithHandlers<TapGestureRecognizer>(
              TapGestureRecognizer.new,
              (r) => r.onTap = onToggle,
            ),
            if (carry != null)
              LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(duration: carryHold, postAcceptSlopTolerance: null),
                (r) => r
                  ..onLongPressStart = ((d) => carry!.start(d.globalPosition))
                  ..onLongPressMoveUpdate = ((d) => carry!.move(d.globalPosition))
                  ..onLongPressEnd = ((_) => carry!.end())
                  ..onLongPressCancel = carry!.cancel,
              ),
          },
          child: body,
        ),
      );
    }

    // My List swaps the row grammar: right is −1, a short left +1
    return RowSwipe(
      onPositive: row.progress > 0 ? () => act(() => unawaited(actions.minusOne(title))) : null,
      positiveLabel: '−1',
      positiveIcon: Symbols.remove_rounded,
      onNegative: done ? null : () => act(() => unawaited(actions.plusOne(title))),
      negativeLabel: '+1',
      negativeIcon: Symbols.add_rounded,
      swapped: true,
      demo: demo,
      onMore: () => unawaited(showQuickActions(context, ref, title)),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(Corner.md),
          onTap: () => context.push('/title/${title.id}'),
          child: body,
        ),
      ),
    );
  }
}

class PaintCallbacks {
  const PaintCallbacks({required this.start, required this.move, required this.end});

  final VoidCallback start;
  final ValueChanged<Offset> move;
  final VoidCallback end;
}

class CarryCallbacks {
  const CarryCallbacks({required this.start, required this.move, required this.end, required this.cancel});

  final ValueChanged<Offset> start;
  final ValueChanged<Offset> move;
  final VoidCallback end;
  final VoidCallback cancel;
}

/// The selection circle: slides in from the left in Edit. Its 36px column
/// owns vertical drags, for painting down the list.
class _Circle extends StatelessWidget {
  const _Circle({required this.editing, required this.selected, required this.onPaint, required this.accent});

  final bool editing;
  final bool selected;
  final PaintCallbacks? onPaint;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragDown: onPaint == null ? null : (_) => onPaint!.start(),
      onVerticalDragUpdate: onPaint == null ? null : (d) => onPaint!.move(d.globalPosition),
      onVerticalDragEnd: onPaint == null ? null : (_) => onPaint!.end(),
      onVerticalDragCancel: onPaint?.end,
      child: AnimatedContainer(
        duration: Motion.lift,
        curve: Motion.enter,
        width: editing ? 44 : 10,
        height: listRowHeight,
        alignment: Alignment.center,
        child: AnimatedOpacity(
          duration: Motion.overlay,
          opacity: editing ? 1 : 0,
          child: AnimatedContainer(
            duration: Motion.press,
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: selected ? accent : Colors.transparent,
              border: selected ? null : Border.all(color: const Color(0x47FFFFFF), width: 2),
            ),
            child: selected ? const Icon(Symbols.check_rounded, size: 17, weight: 700, color: Accent.beniInk) : null,
          ),
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.total, required this.full, required this.color});

  final int value;
  final int? total;
  final bool full;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final known = full || (total != null && total! > 0);
    // an unknown total (ongoing) fades out instead of implying it's nearly done
    final share = full ? 1.0 : (known ? (value / total!).clamp(0.0, 1.0) : 0.7);
    final fill = full ? Accent.green : color;
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Surface.s3),
            EasedFractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: share,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: known ? fill : null,
                  gradient: known
                      ? null
                      : LinearGradient(colors: [fill, fill, fill.withValues(alpha: 0)], stops: const [0, 0.7, 1]),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
