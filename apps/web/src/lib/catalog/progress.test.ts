import { describe, expect, it } from 'vitest';
import { plusOneOutcome, progressWord } from './progress.ts';

describe('plusOneOutcome', () => {
	it('counts up', () => {
		expect(plusOneOutcome({ status: 'CURRENT', progress: 5 }, 24)).toEqual({
			progress: 6,
			completes: false,
			starts: false
		});
	});

	it('completes on reaching the total while in progress', () => {
		for (const status of ['CURRENT', 'REPEATING', 'PAUSED'] as const) {
			expect(plusOneOutcome({ status, progress: 23 }, 24)).toEqual({
				progress: 24,
				completes: true,
				starts: false
			});
		}
	});

	it('keeps counting without a known total', () => {
		expect(plusOneOutcome({ status: 'CURRENT', progress: 1120 }, null)).toEqual({
			progress: 1121,
			completes: false,
			starts: false
		});
	});

	it('starts a Planning entry (or completes a one-episode one)', () => {
		expect(plusOneOutcome({ status: 'PLANNING', progress: 0 }, 24)).toEqual({
			progress: 1,
			completes: false,
			starts: true
		});
		expect(plusOneOutcome({ status: 'PLANNING', progress: 0 }, 1)).toMatchObject({
			completes: true,
			starts: false
		});
	});

	it("doesn't complete what's dropped, or go past the total", () => {
		expect(plusOneOutcome({ status: 'DROPPED', progress: 23 }, 24)?.completes).toBe(false);
		expect(plusOneOutcome({ status: 'CURRENT', progress: 24 }, 24)).toBeNull();
		expect(plusOneOutcome(null, 1)).toEqual({ progress: 1, completes: false, starts: false });
	});
});

describe('progressWord', () => {
	const airing = { next: { ep: 10, in: '2d' }, status: 'Releasing', total: 24 };
	const finished = { status: 'Finished', total: 24 };

	it('says what is new while airing', () => {
		expect(progressWord(airing, 7)).toBe('2 new');
		expect(progressWord(airing, 9)).toBe('Caught up');
	});

	it('says what is left once finished', () => {
		expect(progressWord(finished, 8)).toBe('16 left');
		expect(progressWord(finished, 24)).toBe('Caught up');
	});

	it('says nothing without a schedule', () => {
		expect(progressWord({ status: 'Releasing', total: null }, 3)).toBeNull();
	});
});
