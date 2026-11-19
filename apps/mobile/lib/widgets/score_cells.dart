import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/anilist/types.dart';
import '../core/catalog/score.dart';
import '../core/gestures/haptics.dart';
import '../core/providers.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// The score (Gestures · List editor 20): a row of cells. Drag across them
/// and the score follows your finger; the left half of a cell gives the half
/// point. A tap sets the cell; tapping it again takes off the half (where the
/// format has halves), and tapping the set score again clears it. The row
/// follows the viewer's AniList score format: ten cells for 10 and 100
/// points (100-point cells are tens, halves are fives), five for 5, three
/// faces for 3.
class ScoreCells extends ConsumerStatefulWidget {
  const ScoreCells({super.key, required this.score, required this.format, required this.onChanged, this.accent});

  /// In the viewer's format; 0 = not scored.
  final double score;
  final ScoreFormat format;
  final ValueChanged<double> onChanged;
  final Color? accent;

  @override
  ConsumerState<ScoreCells> createState() => _ScoreCellsState();
}

class _ScoreCellsState extends ConsumerState<ScoreCells> {
  /// The score while a drag is in progress; null at rest.
  double? _dragging;

  int get _cells => switch (widget.format) {
    ScoreFormat.point5 => 5,
    ScoreFormat.point3 => 3,
    _ => 10,
  };

  /// What one cell is worth in the format.
  double get _unit => widget.format == ScoreFormat.point100 ? 10 : 1;

  bool get _halves => widget.format == ScoreFormat.point10Decimal || widget.format == ScoreFormat.point100;

  /// The score under [dx] across a row [width] wide.
  double _scoreAt(double dx, double width) {
    final cellWidth = width / _cells;
    final i = (dx / cellWidth).floor().clamp(0, _cells - 1);
    final within = dx - i * cellWidth;
    final half = _halves && within < cellWidth / 2;
    return (i + 1) * _unit - (half ? _unit / 2 : 0);
  }

  void _drag(double dx, double width) {
    final next = _scoreAt(dx.clamp(0, width - 0.01), width);
    if (next != (_dragging ?? widget.score)) unawaited(ref.read(hapticsProvider).play(Haptic.selection));
    setState(() => _dragging = next);
  }

  void _tap(double dx, double width) {
    final cellWidth = width / _cells;
    final i = (dx / cellWidth).floor().clamp(0, _cells - 1);
    final whole = (i + 1) * _unit;
    final current = widget.score;
    // tap a cell to set it; tap it again for the half below; again to clear
    final next = current == whole && _halves
        ? whole - _unit / 2
        : current == whole || current == whole - _unit / 2
        ? 0.0
        : whole;
    unawaited(ref.read(hapticsProvider).play(Haptic.selection));
    widget.onChanged(clampScore(next, widget.format));
  }

  void _adjust(int direction) {
    widget.onChanged(nudgeScore(widget.score, direction, widget.format));
  }

  @override
  Widget build(BuildContext context) {
    final shown = _dragging ?? widget.score;
    final accent = widget.accent ?? context.mode.accent;
    final faces = widget.format == ScoreFormat.point3;

    return Semantics(
      label: 'Score',
      value: formatScore(shown, widget.format),
      increasedValue: formatScore(nudgeScore(shown, 1, widget.format), widget.format),
      decreasedValue: formatScore(nudgeScore(shown, -1, widget.format), widget.format),
      onIncrease: () => _adjust(1),
      onDecrease: () => _adjust(-1),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapUp: (d) => _tap(d.localPosition.dx, width),
            // owns sideways drags that start on it; 4px decides
            onHorizontalDragStart: (d) => _drag(d.localPosition.dx, width),
            onHorizontalDragUpdate: (d) => _drag(d.localPosition.dx, width),
            onHorizontalDragEnd: (_) {
              final value = _dragging;
              setState(() => _dragging = null);
              if (value != null && value != widget.score) widget.onChanged(clampScore(value, widget.format));
            },
            onHorizontalDragCancel: () => setState(() => _dragging = null),
            child: SizedBox(
              height: Space.minTarget,
              child: Row(
                children: [
                  for (var i = 0; i < _cells; i++) ...[
                    if (i > 0) const SizedBox(width: 3),
                    Expanded(
                      child: faces
                          ? _Face(index: i, selected: shown >= i + 1, accent: accent)
                          : _Cell(
                              fill: ((shown - i * _unit) / _unit).clamp(0.0, 1.0),
                              accent: accent,
                              label: '${((i + 1) * _unit).round()}',
                            ),
                    ),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({required this.fill, required this.accent, required this.label});

  /// 0, .5 or 1.
  final double fill;
  final Color accent;

  /// The score the cell stands for, faint, so the row reads as a scale.
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 30,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: Surface.s3, borderRadius: BorderRadius.circular(2)),
      child: Stack(
        fit: StackFit.expand,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: FractionallySizedBox(
              widthFactor: fill,
              child: ColoredBox(color: accent, child: const SizedBox.expand()),
            ),
          ),
          Center(
            child: ExcludeSemantics(
              child: Text(
                label,
                style: AppType.numeric.copyWith(
                  fontSize: 11,
                  color: fill >= 1 ? Surface.base.withValues(alpha: 0.6) : TextTone.low,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Face extends StatelessWidget {
  const _Face({required this.index, required this.selected, required this.accent});

  final int index;
  final bool selected;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    const faces = ['☹', '😐', '☺'];
    return Container(
      height: 36,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? accent.withValues(alpha: 0.2) : Surface.s3,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(color: selected ? accent : Colors.transparent),
      ),
      child: Text(faces[index], style: const TextStyle(fontSize: 18)),
    );
  }
}
