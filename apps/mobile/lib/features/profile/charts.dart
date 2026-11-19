// The Stats charts (07, Gestures · Profile 18). Drag sideways across the
// bars or the activity grid, or tap one: the exact value reads out in the
// card header, so your finger never covers it, and stays 1.5s after you let
// go. Vertical drags scroll the page.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gestures/haptics.dart';
import '../../core/providers.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/tokens.dart';
import 'profile_data.dart';

/// A tone in the current mode's palette.
Color toneColor(BuildContext context, Tone tone) => switch (tone) {
  Tone.accent => context.mode.accent,
  Tone.accentSoft => context.mode.accent.withValues(alpha: 0.45),
  Tone.ink => TextTone.high,
  Tone.dim => TextTone.mid,
  Tone.mute => Surface.s4,
};

/// A chart's card: a title, and a line that shows the summary, or the value
/// being scrubbed.
class ChartCard extends StatefulWidget {
  const ChartCard({super.key, required this.title, required this.summary, required this.builder});

  final String title;
  final String summary;

  /// Builds the chart; it reports what's under the finger through `readout`.
  final Widget Function(BuildContext context, ValueChanged<String?> readout) builder;

  @override
  State<ChartCard> createState() => _ChartCardState();
}

class _ChartCardState extends State<ChartCard> {
  String? _readout;
  Timer? _hold;

  void _show(String? value) {
    _hold?.cancel();
    if (value != null) {
      setState(() => _readout = value);
    } else {
      // let go: the value stays a moment, then the summary comes back
      _hold = Timer(const Duration(milliseconds: 1500), () {
        if (mounted) setState(() => _readout = null);
      });
    }
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(Space.x4),
      decoration: BoxDecoration(
        color: Surface.s1,
        borderRadius: BorderRadius.circular(Corner.md),
        border: Border.all(color: Surface.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.title, style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Semantics(
            liveRegion: true,
            child: Text(
              _readout ?? widget.summary,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppType.numeric.copyWith(fontSize: 12, color: _readout != null ? TextTone.high : TextTone.mid),
            ),
          ),
          const SizedBox(height: Space.x4),
          widget.builder(context, _show),
        ],
      ),
    );
  }
}

/// Columns you can scrub: [describe] says what one stands for.
class ScrubBars extends ConsumerStatefulWidget {
  const ScrubBars({
    super.key,
    required this.bars,
    required this.describe,
    required this.onReadout,
    this.height = 96,
    this.color,
  });

  final List<Bar> bars;
  final String Function(Bar bar) describe;
  final ValueChanged<String?> onReadout;
  final double height;

  /// Every bar in one colour (a title's cover colour) instead of its tone.
  final Color? color;

  @override
  ConsumerState<ScrubBars> createState() => _ScrubBarsState();
}

class _ScrubBarsState extends ConsumerState<ScrubBars> {
  int? _active;

  void _at(double dx, double width) {
    final i = (dx / width * widget.bars.length).floor().clamp(0, widget.bars.length - 1);
    if (i == _active) return;
    setState(() => _active = i);
    unawaited(ref.read(hapticsProvider).play(Haptic.selection));
    widget.onReadout(widget.describe(widget.bars[i]));
  }

  void _release() {
    setState(() => _active = null);
    widget.onReadout(null);
  }

  @override
  Widget build(BuildContext context) {
    final max = widget.bars.fold(0, (m, b) => b.count > m ? b.count : m);
    return LayoutBuilder(
      builder: (context, box) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (d) => _at(d.localPosition.dx, box.maxWidth),
        onTapUp: (_) => _release(),
        onHorizontalDragStart: (d) => _at(d.localPosition.dx, box.maxWidth),
        onHorizontalDragUpdate: (d) => _at(d.localPosition.dx, box.maxWidth),
        onHorizontalDragEnd: (_) => _release(),
        onHorizontalDragCancel: _release,
        // every column is the chart's full height, so each bar is a tall
        // target, even an empty one (or all of them, before any scores)
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: widget.height),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, bar) in widget.bars.indexed)
                  Expanded(
                    child: Semantics(
                      label: widget.describe(bar),
                      excludeSemantics: true,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 2),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            AnimatedContainer(
                              duration: Motion.panel,
                              curve: Motion.enter,
                              // an empty bar keeps a sliver so the axis reads
                              height: max == 0 ? 3 : 3 + (widget.height - 3) * bar.count / max,
                              decoration: BoxDecoration(
                                color: _active == i
                                    ? TextTone.high
                                    : (widget.color ?? toneColor(context, bar.tone)).withValues(
                                        alpha: _active == null ? 1 : 0.4,
                                      ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              bar.label,
                              style: AppType.numeric.copyWith(
                                fontSize: 10,
                                color: _active == i ? TextTone.high : TextTone.low,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One bar split by share, with a legend underneath.
class StackedBar extends StatelessWidget {
  const StackedBar({super.key, required this.parts});

  final List<({String label, int count, Color color})> parts;

  @override
  Widget build(BuildContext context) {
    final total = parts.fold(0, (a, p) => a + p.count);
    if (total == 0) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(Corner.full),
          child: SizedBox(
            height: 10,
            child: Row(
              children: [
                for (final (i, p) in parts.indexed) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: p.count,
                    child: ColoredBox(color: p.color, child: const SizedBox.expand()),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: Space.x3),
        Wrap(
          spacing: Space.x4,
          runSpacing: 6,
          children: [
            for (final p in parts)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(color: p.color, shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    p.label,
                    style: AppType.caption.copyWith(color: TextTone.mid, fontWeight: FontWeight.w400),
                  ),
                  const SizedBox(width: 4),
                  Text('${p.count}', style: AppType.numeric.copyWith(fontSize: 12)),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

/// Top genres: a bar each, the count, and your mean score in it.
class GenreBars extends StatelessWidget {
  const GenreBars({super.key, required this.genres});

  final List<GenreRow> genres;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final g in genres)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 96,
                  child: Text(
                    g.genre,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppType.caption.copyWith(fontSize: 13, fontWeight: FontWeight.w500),
                  ),
                ),
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: g.width.clamp(0.04, 1.0),
                      child: Container(
                        height: 8,
                        decoration: BoxDecoration(
                          color: toneColor(context, g.tone),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 34,
                  child: Text('${g.count}', textAlign: TextAlign.right, style: AppType.numeric.copyWith(fontSize: 12)),
                ),
                SizedBox(
                  width: 40,
                  child: Text(
                    g.mean == null ? '—' : g.mean!.toStringAsFixed(1),
                    textAlign: TextAlign.right,
                    style: AppType.numeric.copyWith(fontSize: 12, color: TextTone.low),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// 26 weeks of daily activity, Monday at the top. Scrubbing follows the
/// finger one day at a time and stops at today.
class Heatmap extends ConsumerStatefulWidget {
  const Heatmap({super.key, required this.grid, required this.onReadout});

  final List<List<HeatCell?>> grid;
  final ValueChanged<String?> onReadout;

  @override
  ConsumerState<Heatmap> createState() => _HeatmapState();
}

class _HeatmapState extends ConsumerState<Heatmap> {
  (int, int)? _active;
  DateTime _lastTick = DateTime(0);

  static const _gap = 3.0;

  void _at(Offset p, double cell) {
    final w = (p.dx / (cell + _gap)).floor().clamp(0, widget.grid.length - 1);
    final d = (p.dy / (cell + _gap)).floor().clamp(0, 6);
    final c = widget.grid[w][d];
    if (c == null || (w, d) == _active) return;
    setState(() => _active = (w, d));
    // a tick per day, at most every 40ms
    final now = DateTime.now();
    if (now.difference(_lastTick).inMilliseconds >= 40) {
      _lastTick = now;
      unawaited(ref.read(hapticsProvider).play(Haptic.selection));
    }
    widget.onReadout('${c.date} · ${c.amount} ${c.amount == 1 ? 'update' : 'updates'}');
  }

  void _release() {
    setState(() => _active = null);
    widget.onReadout(null);
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.mode.accent;
    Color shade(int level) => switch (level) {
      0 => Surface.s3,
      1 => accent.withValues(alpha: 0.3),
      2 => accent.withValues(alpha: 0.55),
      3 => accent.withValues(alpha: 0.8),
      _ => accent,
    };
    // VoiceOver reads a summary: the cells are too small to visit one by one
    final days = widget.grid.expand((w) => w).whereType<HeatCell>().where((c) => c.amount > 0).toList();
    final busiest = days.isEmpty ? null : days.reduce((a, b) => b.amount > a.amount ? b : a);
    final summary = busiest == null
        ? 'Activity, 26 weeks: no activity'
        : 'Activity, 26 weeks: ${days.length} active ${days.length == 1 ? 'day' : 'days'}, '
              'the busiest ${busiest.date} with ${busiest.amount}';
    return LayoutBuilder(
      builder: (context, box) {
        final cell = (box.maxWidth - _gap * (widget.grid.length - 1)) / widget.grid.length;
        return Semantics(
          label: summary,
          excludeSemantics: true,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _at(d.localPosition, cell),
            onTapUp: (_) => _release(),
            onHorizontalDragStart: (d) => _at(d.localPosition, cell),
            onHorizontalDragUpdate: (d) => _at(d.localPosition, cell),
            onHorizontalDragEnd: (_) => _release(),
            onHorizontalDragCancel: _release,
            child: SizedBox(
              height: cell * 7 + _gap * 6,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final (w, column) in widget.grid.indexed) ...[
                    if (w > 0) const SizedBox(width: _gap),
                    Column(
                      children: [
                        for (final (d, c) in column.indexed) ...[
                          if (d > 0) const SizedBox(height: _gap),
                          Container(
                            width: cell,
                            height: cell,
                            decoration: BoxDecoration(
                              color: c == null ? Colors.transparent : shade(c.level),
                              borderRadius: BorderRadius.circular(2),
                              border: _active == (w, d) ? Border.all(color: TextTone.high, width: 1.5) : null,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
