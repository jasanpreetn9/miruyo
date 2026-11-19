import { describe, expect, it } from 'vitest';
import { airingChip, airingPhase } from './airing.ts';

const NOW = 1_800_000_000;
const HOUR = 3600;

describe('airingPhase', () => {
	it('is blue at rest, accent within 24h, live for 30 min after release', () => {
		expect(airingPhase(NOW + 25 * HOUR, NOW)).toBe('later');
		expect(airingPhase(NOW + 24 * HOUR, NOW)).toBe('soon');
		expect(airingPhase(NOW + 60, NOW)).toBe('soon');
		expect(airingPhase(NOW, NOW)).toBe('live');
		expect(airingPhase(NOW - 29 * 60, NOW)).toBe('live');
		expect(airingPhase(NOW - 30 * 60, NOW)).toBe('aired');
	});
});

describe('airingChip', () => {
	it('counts down live from the airing timestamp', () => {
		expect(airingChip({ ep: 9, in: 'stale', at: NOW + 2 * 86400 + 4 * HOUR }, NOW)).toEqual({
			phase: 'later',
			label: 'EP 9 · 2d 4h'
		});
		expect(airingChip({ ep: 17, in: 'stale', at: NOW + 4 * HOUR + 5 * 60 }, NOW)).toEqual({
			phase: 'soon',
			label: 'EP 17 · 4h 05m'
		});
	});

	it('reads "Airing now" just after release, then hides', () => {
		expect(airingChip({ ep: 3, in: '', at: NOW - 60 }, NOW)?.label).toBe('EP 3 · Airing now');
		expect(airingChip({ ep: 3, in: '', at: NOW - HOUR }, NOW)).toBeNull();
	});

	it('falls back to the pre-formatted countdown without a timestamp', () => {
		expect(airingChip({ ep: 14, in: '19h 12m' }, NOW)).toEqual({
			phase: 'soon',
			label: 'EP 14 · 19h 12m'
		});
		expect(airingChip({ ep: 9, in: '2d 4h' }, NOW)?.phase).toBe('later');
	});
});
