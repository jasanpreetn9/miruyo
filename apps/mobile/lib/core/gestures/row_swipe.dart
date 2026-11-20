import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../providers.dart';
import '../theme/app_theme.dart';
import '../theme/tokens.dart';
import 'haptics.dart';

/// What a swipe would do if released now.
enum SwipeAction { none, positive, negative, more }

/// The row grammar. Right is the
/// positive action (+1, Planning, a reminder); a short left (72–159px) is the
/// negative one (−1); a long left (≥160px) opens quick actions. The track
/// colour previews the result. A swipe arms at 72px, or as a flick faster
/// than 0.6px/ms once it's moved 32px. Each haptic fires once per crossing;
/// dragging back under a threshold disarms silently. Holding the row
/// (450ms, <8px) opens the same quick actions. Swipes starting in the 20px
/// nearest the left edge are left to the OS back gesture.
class RowSwipe extends ConsumerStatefulWidget {
  const RowSwipe({
    super.key,
    required this.child,
    this.onPositive,
    this.onNegative,
    this.onMore,
    this.positiveLabel = '+1',
    this.positiveIcon = Symbols.add_rounded,
    this.negativeLabel = '−1',
    this.negativeIcon = Symbols.remove_rounded,
    this.positiveHaptic = Haptic.success,
    this.borderRadius = Corner.md,
    this.swapped = false,
    this.demo,
  });

  final Widget child;

  /// Swipe right. Null: right swipes don't arm, and stretch at 0.3×.
  final VoidCallback? onPositive;

  /// Short swipe left. Null: a short left does nothing.
  final VoidCallback? onNegative;

  /// Long swipe left, or a hold.
  final VoidCallback? onMore;
  final String positiveLabel;
  final IconData positiveIcon;
  final String negativeLabel;
  final IconData negativeIcon;
  final Haptic positiveHaptic;
  final double borderRadius;

  /// The left swipe is the positive one and the right the correction (My
  /// List). Only the track colours follow: they go with the action, not the
  /// direction, so a correction is never in the accent.
  final bool swapped;

  /// Drives the row's offset to demonstrate the swipes (the coach mark).
  /// Nothing commits; a touch takes over.
  final ValueListenable<double>? demo;

  @override
  ConsumerState<RowSwipe> createState() => _RowSwipeState();
}

class _RowSwipeState extends ConsumerState<RowSwipe> with SingleTickerProviderStateMixin {
  late final AnimationController _spring = AnimationController.unbounded(vsync: this)
    ..addListener(() => setState(() => _dx = _spring.value));
  double _dx = 0;
  bool _ignored = false;
  SwipeAction _armed = SwipeAction.none;

  Timer? _hold;
  Offset? _downAt;
  bool _lifted = false;

  void _haptic(Haptic h) => unawaited(ref.read(hapticsProvider).play(h));

  SwipeAction _actionAt(double dx) {
    if (dx >= GestureSpec.rowArm && widget.onPositive != null) return SwipeAction.positive;
    if (dx <= -GestureSpec.rowMore && widget.onMore != null) return SwipeAction.more;
    if (dx <= -GestureSpec.rowArm && widget.onNegative != null) return SwipeAction.negative;
    return SwipeAction.none;
  }

  /// Movement past what can arm stretches at the rubber-band rate.
  double _resist(double raw) {
    final canRight = widget.onPositive != null;
    final canLeft = widget.onNegative != null || widget.onMore != null;
    if (raw > 0 && !canRight) return raw * GestureSpec.rubberBand;
    if (raw < 0 && !canLeft) return raw * GestureSpec.rubberBand;
    const limit = 220.0;
    final a = raw.abs();
    return a <= limit ? raw : raw.sign * (limit + (a - limit) * GestureSpec.rubberBand);
  }

  void _start(DragStartDetails d) {
    // the left-edge strip belongs to the OS back gesture
    _ignored = d.globalPosition.dx < GestureSpec.edgeStrip;
    if (_ignored) return;
    _spring.stop();
  }

  void _update(DragUpdateDetails d) {
    if (_ignored) return;
    _rawDx += d.delta.dx;
    final next = _resist(_rawDx);
    final action = _actionAt(next);
    if (action != _armed) {
      // arming plays once per crossing; disarming is silent
      if (action == SwipeAction.more) {
        _haptic(Haptic.medium);
      } else if (action != SwipeAction.none && _armed == SwipeAction.none) {
        _haptic(Haptic.light);
      }
      _armed = action;
    }
    setState(() => _dx = next);
  }

  /// The finger's travel; [_dx] is where the row is drawn after resistance.
  double _rawDx = 0;

  void _end(DragEndDetails d) {
    if (_ignored) return;
    final v = (d.primaryVelocity ?? 0) / 1000; // px/ms
    var action = _armed;
    // a flick commits once it's moved 32px
    if (action == SwipeAction.none &&
        _rawDx.abs() >= GestureSpec.rowFlickMin &&
        v.abs() > GestureSpec.rowFlickVelocity) {
      action = v > 0
          ? (widget.onPositive != null ? SwipeAction.positive : SwipeAction.none)
          : (widget.onNegative != null ? SwipeAction.negative : SwipeAction.none);
    }
    _commit(action);
    _rawDx = 0;
    _armed = SwipeAction.none;
    _springBack();
  }

  void _commit(SwipeAction action) {
    switch (action) {
      case SwipeAction.positive:
        widget.onPositive?.call();
      case SwipeAction.negative:
        widget.onNegative?.call();
      case SwipeAction.more:
        widget.onMore?.call();
      case SwipeAction.none:
        break;
    }
  }

  void _springBack() {
    if (MediaQuery.disableAnimationsOf(context)) {
      setState(() => _dx = 0);
      return;
    }
    _spring.value = _dx;
    unawaited(_spring.animateTo(0, duration: Motion.lift, curve: Motion.enter));
  }

  // ── hold for quick actions ──

  /// A finger is on the row (the demonstration stops while it is).
  bool _touching = false;

  void _down(PointerDownEvent e) {
    _touching = true;
    if (widget.onMore == null) return;
    _downAt = e.position;
    _hold = Timer(GestureSpec.hold, () {
      // a drag can be accepted at touch-down; only real movement cancels the hold
      if (!mounted || _rawDx.abs() > GestureSpec.holdSlop) return;
      setState(() => _lifted = true);
      _haptic(Haptic.medium);
      widget.onMore!();
      Future<void>.delayed(Motion.lift, () {
        if (mounted) setState(() => _lifted = false);
      });
    });
  }

  void _move(PointerMoveEvent e) {
    if (_downAt != null && (e.position - _downAt!).distance > GestureSpec.holdSlop) _cancelHold();
  }

  void _cancelHold() {
    _hold?.cancel();
    _hold = null;
    _downAt = null;
  }

  @override
  void initState() {
    super.initState();
    widget.demo?.addListener(_onDemo);
  }

  @override
  void didUpdateWidget(RowSwipe old) {
    super.didUpdateWidget(old);
    if (old.demo != widget.demo) {
      old.demo?.removeListener(_onDemo);
      widget.demo?.addListener(_onDemo);
      if (widget.demo == null && !_touching) setState(() => _dx = 0);
    }
  }

  void _onDemo() {
    // a finger on the row wins over the demonstration
    if (_touching || _spring.isAnimating || !mounted) return;
    setState(() => _dx = widget.demo!.value);
  }

  @override
  void dispose() {
    widget.demo?.removeListener(_onDemo);
    _hold?.cancel();
    _spring.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final action = _actionAt(_dx);
    final positive = _dx > 0;
    final mode = context.mode;
    // −1 is a correction: neutral grey, never the accent
    final accentTrack = mode.accent, accentFg = mode.onAccent;
    const neutralTrack = Surface.s4, neutralFg = TextTone.high;
    final (Color track, Color fg, IconData icon, String label) = switch (action) {
      SwipeAction.positive => (
        widget.swapped ? neutralTrack : accentTrack,
        widget.swapped ? neutralFg : accentFg,
        widget.positiveIcon,
        widget.positiveLabel,
      ),
      SwipeAction.negative => (
        widget.swapped ? accentTrack : neutralTrack,
        widget.swapped ? accentFg : neutralFg,
        widget.negativeIcon,
        widget.negativeLabel,
      ),
      SwipeAction.more => (Accent.sora, Accent.soraInk, Symbols.more_horiz_rounded, 'More'),
      SwipeAction.none => (
        Surface.s3,
        TextTone.mid,
        positive ? widget.positiveIcon : widget.negativeIcon,
        positive ? widget.positiveLabel : widget.negativeLabel,
      ),
    };

    return Semantics(
      customSemanticsActions: {
        if (widget.onPositive != null) CustomSemanticsAction(label: widget.positiveLabel): widget.onPositive!,
        if (widget.onNegative != null) CustomSemanticsAction(label: widget.negativeLabel): widget.onNegative!,
        if (widget.onMore != null) const CustomSemanticsAction(label: 'More actions'): widget.onMore!,
      },
      child: Listener(
        onPointerDown: _down,
        onPointerMove: _move,
        onPointerUp: (_) {
          _touching = false;
          _cancelHold();
        },
        onPointerCancel: (_) {
          _touching = false;
          _cancelHold();
        },
        // the hold claims the touch when it fires, so letting go afterwards
        // isn't also a tap on the row (which would open the title)
        child: RawGestureDetector(
          gestures: {
            if (widget.onMore != null)
              LongPressGestureRecognizer: GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
                () => LongPressGestureRecognizer(duration: GestureSpec.hold, debugOwner: this),
                (r) => r.onLongPress = () {},
              ),
          },
          child: GestureDetector(
            // thresholds count from the touch, not from where the drag is
            // recognised, so 72px means 72px of finger travel
            dragStartBehavior: DragStartBehavior.down,
            onHorizontalDragStart: _start,
            onHorizontalDragUpdate: _update,
            onHorizontalDragEnd: _end,
            onHorizontalDragCancel: () {
              _rawDx = 0;
              _armed = SwipeAction.none;
              _springBack();
            },
            child: Stack(
              children: [
                if (_dx != 0)
                  Positioned.fill(
                    // a poster in a grid is narrow: the icon stacks over a smaller label
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final narrow = box.maxWidth < 200;
                        final text = Text(
                          label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppType.numeric.copyWith(
                            fontSize: narrow ? 11 : 14,
                            fontWeight: FontWeight.w700,
                            color: fg,
                          ),
                        );
                        return AnimatedContainer(
                          duration: Motion.press,
                          decoration: BoxDecoration(
                            color: track,
                            borderRadius: BorderRadius.circular(widget.borderRadius),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: narrow ? Space.x2 : Space.x5),
                          alignment: positive ? Alignment.centerLeft : Alignment.centerRight,
                          child: narrow
                              ? Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: positive ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                                  children: [
                                    Icon(icon, size: 22, color: fg),
                                    const SizedBox(height: 2),
                                    text,
                                  ],
                                )
                              : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(icon, size: 22, color: fg),
                                    const SizedBox(width: Space.x1),
                                    Flexible(child: text),
                                  ],
                                ),
                        );
                      },
                    ),
                  ),
                AnimatedScale(
                  scale: _lifted ? Motion.pressScale : 1,
                  duration: Motion.lift,
                  child: Transform.translate(offset: Offset(_dx, 0), child: widget.child),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
