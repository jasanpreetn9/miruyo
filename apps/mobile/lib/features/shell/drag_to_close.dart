// Detail is a card: scrolled to the top, dragging down anywhere shrinks
// it with the page behind showing through; letting go past 140px, or a
// flick after 40px, closes it. The drag is taken from the scroll view's own
// physics, so it only starts at the top and a drag back up scrolls again.

import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/gestures/haptics.dart';
import '../../core/providers.dart';
import '../../core/theme/tokens.dart';

/// Close past this much travel.
const closeAt = 140.0;

/// Or on a flick this fast (px/s) after [flickAfter].
const closeFlick = 800.0;
const flickAfter = 40.0;

/// Fully shrunk (to [_minScale]) at this much travel.
const _full = 400.0;
const _minScale = 0.82;

/// Wraps a page whose scroll view uses [physics]; [onClose] pops it. It
/// paints the page's background itself, so the Scaffold's should be clear.
class DragToClose extends ConsumerStatefulWidget {
  const DragToClose({super.key, required this.builder, required this.onClose});

  final Widget Function(BuildContext context, ScrollPhysics physics) builder;
  final VoidCallback onClose;

  @override
  ConsumerState<DragToClose> createState() => _DragToCloseState();
}

class _DragToCloseState extends ConsumerState<DragToClose> with SingleTickerProviderStateMixin {
  final _pull = ValueNotifier<double>(0);
  late final _physics = _PullPhysics(this);
  late final AnimationController _settle = AnimationController.unbounded(vsync: this)
    ..addListener(() => _pull.value = _settle.value);
  bool _closing = false;

  @override
  void dispose() {
    _settle.dispose();
    _pull.dispose();
    super.dispose();
  }

  AnimationController? get _route => switch (ModalRoute.of(context)) {
    // ignore: invalid_use_of_protected_member
    final TransitionRoute<dynamic> r => r.controller,
    _ => null,
  };

  void _move(double pull) {
    if (_closing) return;
    final was = _pull.value;
    if (was == 0 && pull > 0) {
      _settle.stop();
      // a hair short of fully in: the route stops being opaque, so the page
      // behind is painted and shows through (no visible slide at this value)
      final route = _route;
      if (route != null && route.value == 1) route.value = 0.9999;
    }
    if (was < closeAt && pull >= closeAt) unawaited(ref.read(hapticsProvider).play(Haptic.light));
    _pull.value = math.max(0, pull);
    if (_pull.value == 0) _restoreRoute();
  }

  void _restoreRoute() {
    final route = _route;
    if (route != null && route.value < 1 && route.status != AnimationStatus.reverse) route.value = 1;
  }

  /// [velocity] in px/s, positive downwards.
  void _release(double velocity) {
    final pull = _pull.value;
    if (pull >= closeAt || (pull >= flickAfter && velocity >= closeFlick)) {
      _closing = true;
      widget.onClose();
      return;
    }
    _settle.value = pull;
    unawaited(
      _settle
          .animateWith(SpringSimulation(const SpringDescription(mass: 1, stiffness: 400, damping: 40), pull, 0, 0))
          .then((_) {
            if (mounted && _pull.value.abs() < 0.5) {
              _pull.value = 0;
              _restoreRoute();
            }
          }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final page = widget.builder(context, _physics);
    final reduce = MediaQuery.disableAnimationsOf(context);
    return ValueListenableBuilder<double>(
      valueListenable: _pull,
      child: page,
      // the same tree at rest and while pulling, so the scroll view (and the
      // drag it's running) survives the pull starting
      builder: (context, pull, child) {
        final pulling = pull > 0;
        final t = (pull / _full).clamp(0.0, 1.0);
        return Stack(
          fit: StackFit.expand,
          children: [
            // the page behind dims less as this one shrinks away
            ColoredBox(color: pulling ? Colors.black.withValues(alpha: 0.6 * (1 - t)) : Colors.transparent),
            Transform.translate(
              offset: Offset(0, pull),
              child: Transform.scale(
                scale: reduce ? 1 : lerpDouble(1, _minScale, t)!,
                alignment: Alignment.topCenter,
                child: ClipRRect(
                  clipBehavior: pulling ? Clip.antiAlias : Clip.none,
                  borderRadius: BorderRadius.circular(lerpDouble(14, 40, t)!),
                  child: ColoredBox(color: Surface.base, child: child),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// At the top of the scroll view, a drag down pulls the page instead of
/// scrolling (and a drag back up gives the pull back before scrolling).
class _PullPhysics extends ScrollPhysics {
  const _PullPhysics(this.owner, {super.parent});

  final _DragToCloseState owner;

  @override
  _PullPhysics applyTo(ScrollPhysics? ancestor) => _PullPhysics(owner, parent: buildParent(ancestor));

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    final pull = owner._pull.value;
    // offset > 0 is the finger moving down
    if (position.pixels <= position.minScrollExtent && (offset > 0 || pull > 0)) {
      final next = pull + offset;
      owner._move(next);
      if (next >= 0) return 0;
      return super.applyPhysicsToUserOffset(position, next);
    }
    return super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  Simulation? createBallisticSimulation(ScrollMetrics position, double velocity) {
    if (owner._pull.value > 0) {
      // scroll velocity is negative when the finger flicks down
      owner._release(-velocity);
      return null;
    }
    return super.createBallisticSimulation(position, velocity);
  }
}
