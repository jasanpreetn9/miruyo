import 'package:flutter/material.dart';

/// A halftone screen (design/mockups): a grid of fine dots in [color],
/// fading out toward the right, behind a feature (the pick, a title's
/// banner). [spacing] is the grid; [fade] is how much of the width the dots
/// fade across, from full at the left.
class Halftone extends StatelessWidget {
  const Halftone({
    super.key,
    required this.color,
    this.spacing = 6,
    this.radius = 0.9,
    this.fade = 0.85,
    this.opacity = 0.45,
  });

  final Color color;
  final double spacing;
  final double radius;
  final double fade;
  final double opacity;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: RepaintBoundary(
      child: CustomPaint(painter: _HalftonePainter(color, spacing, radius, fade, opacity), size: Size.infinite),
    ),
  );
}

class _HalftonePainter extends CustomPainter {
  _HalftonePainter(this.color, this.spacing, this.radius, this.fade, this.opacity);

  final Color color;
  final double spacing;
  final double radius;
  final double fade;
  final double opacity;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = true;
    final reach = size.width * fade;
    for (var x = spacing / 2; x < reach; x += spacing) {
      final a = opacity * (1 - x / reach);
      if (a <= 0.01) continue;
      paint.color = color.withValues(alpha: a);
      for (var y = spacing / 2; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_HalftonePainter old) =>
      old.color != color ||
      old.spacing != spacing ||
      old.radius != radius ||
      old.fade != fade ||
      old.opacity != opacity;
}
