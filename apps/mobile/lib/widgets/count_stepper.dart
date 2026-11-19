import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../core/gestures/haptics.dart';
import '../core/providers.dart';
import '../core/theme/app_theme.dart';
import '../core/theme/tokens.dart';

/// Episodes, chapters or volumes (Gestures · List editor 20). The count
/// scrubs: drag sideways on it, one step per 14px, with a chip showing the
/// change. Hold +1 or − to repeat: once on touch, then every 150ms, every
/// 70ms after 2s. It stops at 0 and at [max]. +1 is the biggest target.
class CountStepper extends ConsumerStatefulWidget {
  const CountStepper({
    super.key,
    required this.value,
    required this.onChanged,
    required this.unit,
    this.max,
    this.accent,
  });

  final int value;

  /// Called on every step; callers batch the saves.
  final ValueChanged<int> onChanged;

  /// "episode", "chapter", "volume".
  final String unit;

  /// The total, when known.
  final int? max;
  final Color? accent;

  @override
  ConsumerState<CountStepper> createState() => _CountStepperState();
}

class _CountStepperState extends ConsumerState<CountStepper> {
  static const _pxPerStep = 14.0;

  Timer? _repeat;
  DateTime? _holdStart;

  /// While scrubbing: where the drag began and the value then.
  double? _scrubStart;
  int? _scrubFrom;

  int _clamp(int v) => v.clamp(0, widget.max ?? 1 << 31);

  void _set(int next) {
    final v = _clamp(next);
    if (v == widget.value) return;
    unawaited(ref.read(hapticsProvider).play(Haptic.selection));
    widget.onChanged(v);
  }

  void _startRepeat(int direction) {
    _set(widget.value + direction);
    _holdStart = DateTime.now();
    _repeat?.cancel();
    // the first repeat waits for a hold, then speeds up after 2s
    _repeat = Timer(GestureSpec.hold, () => _tick(direction));
  }

  void _tick(int direction) {
    if (!mounted) return;
    _set(widget.value + direction);
    final held = DateTime.now().difference(_holdStart!);
    _repeat = Timer(Duration(milliseconds: held > const Duration(seconds: 2) ? 70 : 150), () => _tick(direction));
  }

  void _stopRepeat() {
    _repeat?.cancel();
    _repeat = null;
  }

  @override
  void dispose() {
    _repeat?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.accent ?? context.mode.accent;
    final delta = _scrubFrom == null ? 0 : widget.value - _scrubFrom!;
    final atMax = widget.max != null && widget.value >= widget.max!;

    Widget button({required IconData icon, required int direction, required bool enabled, required double width}) {
      final plus = direction > 0;
      return Semantics(
        button: true,
        enabled: enabled,
        label: plus ? 'Add one ${widget.unit}' : 'One less ${widget.unit}',
        excludeSemantics: true,
        child: GestureDetector(
          onTapDown: enabled ? (_) => _startRepeat(direction) : null,
          onTapUp: (_) => _stopRepeat(),
          onTapCancel: _stopRepeat,
          onLongPressEnd: (_) => _stopRepeat(),
          child: AnimatedOpacity(
            duration: Motion.overlay,
            opacity: enabled ? 1 : 0.35,
            child: Container(
              width: width,
              height: 48,
              decoration: BoxDecoration(
                color: plus ? TextTone.high : Surface.s3,
                borderRadius: BorderRadius.circular(2),
                border: plus ? null : Border.all(color: Surface.line),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 20, color: plus ? Surface.s1 : TextTone.high),
                  if (plus)
                    Text(
                      '1',
                      style: AppType.numeric.copyWith(fontSize: 14, fontWeight: FontWeight.w700, color: Surface.s1),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        button(icon: Symbols.remove_rounded, direction: -1, enabled: widget.value > 0, width: 52),
        Expanded(
          child: Semantics(
            label: '${widget.unit}s',
            value: '${widget.value}${widget.max != null ? ' of ${widget.max}' : ''}',
            increasedValue: '${_clamp(widget.value + 1)}',
            decreasedValue: '${_clamp(widget.value - 1)}',
            onIncrease: () => _set(widget.value + 1),
            onDecrease: () => _set(widget.value - 1),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onHorizontalDragStart: (d) => setState(() {
                _scrubStart = d.localPosition.dx;
                _scrubFrom = widget.value;
              }),
              onHorizontalDragUpdate: (d) {
                final steps = ((d.localPosition.dx - _scrubStart!) / _pxPerStep).round();
                _set(_scrubFrom! + steps);
                setState(() {});
              },
              onHorizontalDragEnd: (_) => setState(() => _scrubFrom = _scrubStart = null),
              onHorizontalDragCancel: () => setState(() => _scrubFrom = _scrubStart = null),
              child: SizedBox(
                height: 48,
                child: Stack(
                  alignment: Alignment.center,
                  clipBehavior: Clip.none,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text('${widget.value}', style: AppType.mono(26)),
                        Text(
                          ' / ${widget.max ?? '?'}',
                          style: AppType.body.copyWith(fontSize: 15, color: TextTone.low),
                        ),
                      ],
                    ),
                    if (_scrubFrom != null && delta != 0)
                      Positioned(
                        top: -26,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: accent, borderRadius: BorderRadius.circular(Corner.full)),
                          child: Text(
                            delta > 0 ? '+$delta' : '$delta',
                            style: AppType.numeric.copyWith(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: context.mode.onAccent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        button(icon: Symbols.add_rounded, direction: 1, enabled: !atMax, width: 88),
      ],
    );
  }
}
