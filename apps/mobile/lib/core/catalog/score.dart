// Ported from apps/web/src/lib/anilist/score.ts.
//
// AniList stores scores in each viewer's own format (mediaListOptions.scoreFormat),
// and SaveMediaListEntry's `score` argument takes them in that same format.
// 0 always means "not scored".

import '../anilist/types.dart';

class ScoreScale {
  const ScoreScale({required this.max, required this.step, required this.precision});

  final double max;

  /// How far one stepper nudge moves the score.
  final double step;

  /// Smallest difference AniList keeps.
  final double precision;
}

/// The design's default: 10-point with half points.
const defaultScoreFormat = ScoreFormat.point10Decimal;

const _scales = {
  ScoreFormat.point100: ScoreScale(max: 100, step: 1, precision: 1),
  ScoreFormat.point10Decimal: ScoreScale(max: 10, step: 0.5, precision: 0.1),
  ScoreFormat.point10: ScoreScale(max: 10, step: 1, precision: 1),
  ScoreFormat.point5: ScoreScale(max: 5, step: 1, precision: 1),
  ScoreFormat.point3: ScoreScale(max: 3, step: 1, precision: 1),
};

ScoreScale scoreScale([ScoreFormat? format]) => _scales[format ?? defaultScoreFormat]!;

double _roundTo(double value, double precision) {
  // round via the inverse so 0.1-precision values don't pick up float noise
  final inv = (1 / precision).round();
  return (value * inv).round() / inv;
}

/// Clamps to 0..max and rounds to what AniList keeps for this format.
double clampScore(double score, [ScoreFormat? format]) {
  final scale = scoreScale(format);
  if (!score.isFinite) return 0;
  return _roundTo(score.clamp(0, scale.max).toDouble(), scale.precision);
}

/// One stepper press up (+1) or down (−1), snapping to the step grid.
double nudgeScore(double score, int direction, [ScoreFormat? format]) {
  final step = scoreScale(format).step;
  final snapped = direction > 0 ? (score / step).floor() * step : (score / step).ceil() * step;
  return clampScore(snapped + direction * step, format);
}

const _smileys = ['', '☹', '😐', '☺'];

String formatScore(double score, [ScoreFormat? format]) {
  if (score == 0) return '—';
  final resolved = format ?? defaultScoreFormat;
  final clamped = clampScore(score, resolved);
  if (resolved == ScoreFormat.point3) {
    final face = _smileys[clamped.toInt()];
    return face.isEmpty ? '—' : face;
  }
  if (resolved == ScoreFormat.point10Decimal) return clamped.toStringAsFixed(1);
  return clamped.toInt().toString();
}
