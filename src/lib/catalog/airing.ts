import { formatTimeUntil } from '#lib/anilist/humanize.ts';
import type { NextAiring } from './types.ts';

/**
 * 'later' = more than 24h out (blue), 'soon' = within 24h (accent + live dot),
 * 'live' = released in the last 30 min ("Airing now"), 'aired' = past that,
 * so the chip hides until the next refetch brings the following episode.
 */
export type AiringPhase = 'later' | 'soon' | 'live' | 'aired';

const SOON_WINDOW = 24 * 60 * 60;
const LIVE_WINDOW = 30 * 60;

export function airingPhase(airingAt: number, nowSeconds: number): AiringPhase {
	const until = airingAt - nowSeconds;
	if (until > SOON_WINDOW) return 'later';
	if (until > 0) return 'soon';
	if (-until < LIVE_WINDOW) return 'live';
	return 'aired';
}

export interface AiringChip {
	phase: AiringPhase;
	label: string;
}

/** What the countdown chip shows for `next` at `nowSeconds`, or null to hide it. */
export function airingChip(next: NextAiring, nowSeconds: number): AiringChip | null {
	if (next.at === undefined) {
		// mock catalog: only a pre-formatted countdown, no timestamp
		const soon = /^\d+h|^\d+m/.test(next.in);
		return { phase: soon ? 'soon' : 'later', label: `EP ${next.ep} · ${next.in}` };
	}
	const phase = airingPhase(next.at, nowSeconds);
	if (phase === 'aired') return null;
	if (phase === 'live') return { phase, label: `EP ${next.ep} · Airing now` };
	return { phase, label: `EP ${next.ep} · ${formatTimeUntil(next.at - nowSeconds)}` };
}
