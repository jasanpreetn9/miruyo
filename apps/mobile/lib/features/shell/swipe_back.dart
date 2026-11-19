// Swipe back from anywhere on the page, as iOS's own apps do (since iOS 26),
// not only from the 20pt strip at the screen's edge that Flutter's Cupertino
// route listens to. The page follows the finger; letting go past halfway,
// or flicking right, goes back. Drags that start on something that scrolls
// or swipes sideways (rails, rows) stay theirs: the inner gesture wins.

import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/cupertino.dart';
import 'package:flutter/gestures.dart';

/// A page with the full-width back swipe.
class SwipeBackPage<T> extends Page<T> {
  const SwipeBackPage({required this.child, super.key, super.name, super.arguments, super.restorationId});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => _SwipeBackRoute<T>(this);
}

class _SwipeBackRoute<T> extends PageRoute<T> with CupertinoRouteTransitionMixin<T> {
  _SwipeBackRoute(SwipeBackPage<T> page) : super(settings: page);

  SwipeBackPage<T> get _page => settings as SwipeBackPage<T>;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  String? get title => null;

  @override
  bool get maintainState => true;

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final transition = super.buildTransitions(context, animation, secondaryAnimation, child);
    return _BackSwipe(route: this, child: transition);
  }
}

class _BackSwipe extends StatefulWidget {
  const _BackSwipe({required this.route, required this.child});

  final _SwipeBackRoute<dynamic> route;
  final Widget child;

  @override
  State<_BackSwipe> createState() => _BackSwipeState();
}

class _BackSwipeState extends State<_BackSwipe> {
  bool _dragging = false;

  _SwipeBackRoute<dynamic> get _route => widget.route;

  // ignore: invalid_use_of_protected_member
  AnimationController get _controller => _route.controller!;

  bool get _enabled => !_route.isFirst && _route.popGestureEnabled && !_route.navigator!.userGestureInProgress;

  void _start(DragStartDetails _) {
    if (!_enabled) return;
    _dragging = true;
    _route.navigator!.didStartUserGesture();
  }

  void _update(DragUpdateDetails d) {
    if (!_dragging) return;
    // a drag back to the left stops at the page's resting place
    _controller.value = (_controller.value - d.primaryDelta! / context.size!.width).clamp(0.0, 1.0);
  }

  void _end(DragEndDetails d) {
    if (!_dragging) return;
    _dragging = false;
    final velocity = d.primaryVelocity! / context.size!.width;
    // a flick decides; otherwise where it was let go
    final stay = velocity.abs() >= 1 ? velocity <= 0 : _controller.value > 0.5;
    const curve = Curves.fastLinearToSlowEaseIn;
    final navigator = _route.navigator!;
    if (stay) {
      final ms = math.min(lerpDouble(800, 0, _controller.value)!.floor(), 300);
      _controller.animateTo(
        1,
        duration: Duration(milliseconds: ms),
        curve: curve,
      );
    } else {
      navigator.pop();
      if (_controller.isAnimating) {
        final ms = lerpDouble(0, 800, _controller.value)!.floor();
        _controller.animateBack(
          0,
          duration: Duration(milliseconds: ms),
          curve: curve,
        );
      }
    }
    if (_controller.isAnimating) {
      late AnimationStatusListener done;
      done = (status) {
        navigator.didStopUserGesture();
        _controller.removeStatusListener(done);
      };
      _controller.addStatusListener(done);
    } else {
      navigator.didStopUserGesture();
    }
  }

  void _cancel() {
    if (!_dragging) return;
    _end(DragEndDetails(primaryVelocity: 0, velocity: Velocity.zero));
  }

  @override
  Widget build(BuildContext context) {
    return RawGestureDetector(
      // behind the page's own gestures: anything inside that drags sideways wins
      behavior: HitTestBehavior.translucent,
      gestures: {
        HorizontalDragGestureRecognizer: GestureRecognizerFactoryWithHandlers<HorizontalDragGestureRecognizer>(
          () => HorizontalDragGestureRecognizer(debugOwner: this),
          (r) => r
            ..onStart = _start
            ..onUpdate = _update
            ..onEnd = _end
            ..onCancel = _cancel,
        ),
      },
      child: widget.child,
    );
  }
}
