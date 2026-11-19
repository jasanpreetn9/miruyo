import 'package:flutter/material.dart';

import '../core/theme/tokens.dart';

/// A shimmering block shaped like what's loading. Skeletons, never spinners,
/// for content. Under reduced motion it holds still.
class Skeleton extends StatefulWidget {
  const Skeleton({super.key, this.width, this.height, this.radius = Corner.sm});

  final double? width;
  final double? height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: Motion.shimmer);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value * 2 - 0.5;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(-1 + t * 2, 0),
              end: Alignment(1 + t * 2, 0),
              colors: const [Surface.s1, Surface.s2, Surface.s1],
              stops: const [0.3, 0.5, 0.7],
            ),
          ),
        );
      },
    );
  }
}
