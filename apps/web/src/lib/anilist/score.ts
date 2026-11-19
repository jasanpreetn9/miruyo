import type { ScoreFormat } from './types.ts';

/**
 * AniList stores scores in each viewer's own format (mediaListOptions.scoreFormat),
 * and SaveMediaListEntry's `score` argument takes them in that same format.
 * 0 always means "not scored".
 */
export interface ScoreScale {
	max: number;
	/** How far one stepper nudge moves the score. */
	step: number;
	/** Smallest difference AniList keeps. */
	precision: number;
}

/** The design's default: 10-point with half points. */
export const DEFAULT_SCORE_FORMAT: ScoreFormat = 'POINT_10_DECIMAL';

const SCALES: Record<ScoreFormat, ScoreScale> = {
	POINT_100: { max: 100, step: 1, precision: 1 },
	POINT_10_DECIMAL: { max: 10, step: 0.5, precision: 0.1 },
	POINT_10: { max: 10, step: 1, precision: 1 },
	POINT_5: { max: 5, step: 1, precision: 1 },
	POINT_3: { max: 3, step: 1, precision: 1 }
};

export function scoreScale(format: ScoreFormat = DEFAULT_SCORE_FORMAT): ScoreScale {
	return SCALES[format] ?? SCALES[DEFAULT_SCORE_FORMAT];
}

function roundTo(value: number, precision: number): number {
	// round via the inverse so 0.1-precision values don't pick up float noise
	const inv = Math.round(1 / precision);
	return Math.round(value * inv) / inv;
}

/** Clamps to 0..max and rounds to what AniList keeps for this format. */
export function clampScore(score: number, format?: ScoreFormat): number {
	const { max, precision } = scoreScale(format);
	if (!Number.isFinite(score)) return 0;
	return roundTo(Math.min(max, Math.max(0, score)), precision);
}

/** One stepper press up (+1) or down (-1), snapping to the step grid. */
export function nudgeScore(score: number, direction: 1 | -1, format?: ScoreFormat): number {
	const { step } = scoreScale(format);
	const snapped = direction > 0 ? Math.floor(score / step) * step : Math.ceil(score / step) * step;
	return clampScore(snapped + direction * step, format);
}

const SMILEYS = ['', '☹', '😐', '☺'];

export function formatScore(score: number, format?: ScoreFormat): string {
	if (!score) return '—';
	const resolved = format ?? DEFAULT_SCORE_FORMAT;
	if (resolved === 'POINT_3') return SMILEYS[clampScore(score, resolved)] || '—';
	if (resolved === 'POINT_10_DECIMAL') return clampScore(score, resolved).toFixed(1);
	return String(clampScore(score, resolved));
}
