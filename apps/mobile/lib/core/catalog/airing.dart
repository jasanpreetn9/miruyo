// Ported from apps/web/src/lib/catalog/airing.ts.

import 'humanize.dart';

/// later = more than 24h out (blue), soon = within 24h (accent + live dot),
/// live = released in the last 30 min ("Airing now"), aired = past that,
/// so the chip hides until the next refetch brings the following episode.
enum AiringPhase { later, soon, live, aired }

const _soonWindow = 24 * 60 * 60;
const _liveWindow = 30 * 60;

AiringPhase airingPhase(int airingAt, int nowSeconds) {
  final until = airingAt - nowSeconds;
  if (until > _soonWindow) return AiringPhase.later;
  if (until > 0) return AiringPhase.soon;
  if (-until < _liveWindow) return AiringPhase.live;
  return AiringPhase.aired;
}

class AiringChip {
  const AiringChip(this.phase, this.label);

  final AiringPhase phase;
  final String label;
}

/// What the countdown chip shows for episode [ep] airing at [airingAt]
/// (unix seconds), or null to hide it.
AiringChip? airingChip({required int ep, required int airingAt, required int nowSeconds}) {
  final phase = airingPhase(airingAt, nowSeconds);
  return switch (phase) {
    AiringPhase.aired => null,
    AiringPhase.live => AiringChip(phase, 'EP $ep · Airing now'),
    _ => AiringChip(phase, 'EP $ep · ${formatTimeUntil(airingAt - nowSeconds)}'),
  };
}
