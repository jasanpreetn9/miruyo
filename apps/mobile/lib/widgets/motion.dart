// Small pieces of motion shared across the app, so content arrives instead
// of popping in. All of them step aside under Reduce Motion.

import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';

/// Fades its child in and lifts it 12px into place the first time it's
/// built: content replacing a skeleton, a card scrolled into view.
/// [delay] staggers a few siblings.
class Appear extends StatefulWidget {
  const Appear({super.key, required this.child, this.delay = Duration.zero});

  final Widget child;
  final Duration delay;

  /// A stagger for item [index] of a list: the first few follow each other,
  /// the rest (scrolled in later) arrive at once.
  static Duration stagger(int index) => Duration(milliseconds: 35 * index.clamp(0, 8));

  @override
  State<Appear> createState() => _AppearState();
}

class _AppearState extends State<Appear> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: Motion.panel);
  late final _curve = CurvedAnimation(parent: _controller, curve: Motion.enter);
  bool _still = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller.isAnimating || _controller.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _still = true;
      _controller.value = 1;
    } else if (widget.delay == Duration.zero) {
      _controller.forward();
    } else {
      Future<void>.delayed(widget.delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_still) return widget.child;
    return FadeTransition(
      opacity: _curve,
      child: AnimatedBuilder(
        animation: _curve,
        builder: (context, child) => Transform.translate(offset: Offset(0, 12 * (1 - _curve.value)), child: child),
        child: widget.child,
      ),
    );
  }
}

/// A 0–1 share that eases to its new value (a progress bar after +1)
/// rather than jumping.
class EasedShare extends StatelessWidget {
  const EasedShare({super.key, required this.share, required this.builder});

  final double share;
  final Widget Function(BuildContext context, double share) builder;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: share),
      duration: MediaQuery.disableAnimationsOf(context) ? Duration.zero : Motion.panel,
      curve: Motion.enter,
      builder: (context, value, _) => builder(context, value),
    );
  }
}

/// A [FractionallySizedBox] whose width eases to a new [widthFactor]: for
/// progress bars, so a +1 grows the bar instead of snapping it.
class EasedFractionallySizedBox extends StatelessWidget {
  const EasedFractionallySizedBox({
    super.key,
    required this.widthFactor,
    required this.child,
    this.alignment = Alignment.centerLeft,
  });

  final double widthFactor;
  final AlignmentGeometry alignment;
  final Widget child;

  @override
  Widget build(BuildContext context) => EasedShare(
    share: widthFactor,
    builder: (context, value) =>
        FractionallySizedBox(alignment: alignment, widthFactor: value.clamp(0.0, 1.0), child: child),
  );
}

/// A number that ticks: when [value] changes (a +1), the new one comes up
/// from below as the old one leaves. It doesn't on first build, and under
/// Reduce Motion it simply changes.
class Tick extends StatelessWidget {
  const Tick({super.key, required this.value, this.style});

  final Object value;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final text = Text('$value', style: style, key: ValueKey(value));
    if (MediaQuery.disableAnimationsOf(context)) return text;
    return ClipRect(
      child: AnimatedSwitcher(
        duration: Motion.lift,
        switchInCurve: Motion.enter,
        switchOutCurve: Motion.exit,
        layoutBuilder: (current, previous) => Stack(alignment: Alignment.center, children: [...previous, ?current]),
        transitionBuilder: (child, animation) {
          final incoming = child.key == ValueKey(value);
          return FadeTransition(
            opacity: animation,
            child: SlideTransition(
              position: Tween(begin: Offset(0, incoming ? 0.6 : -0.6), end: Offset.zero).animate(animation),
              child: child,
            ),
          );
        },
        child: text,
      ),
    );
  }
}
