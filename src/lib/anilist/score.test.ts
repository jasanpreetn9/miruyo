import { describe, expect, it } from 'vitest';
import { clampScore, formatScore, nudgeScore, scoreScale } from './score.ts';

describe('scoreScale', () => {
	it('defaults to 10-point with half-point steps', () => {
		expect(scoreScale()).toEqual({ max: 10, step: 0.5, precision: 0.1 });
		expect(scoreScale('POINT_100').max).toBe(100);
	});
});

describe('clampScore', () => {
	it('clamps to the format range and its precision', () => {
		expect(clampScore(11)).toBe(10);
		expect(clampScore(-2)).toBe(0);
		expect(clampScore(7.34)).toBe(7.3);
		expect(clampScore(7.6, 'POINT_10')).toBe(8);
		expect(clampScore(Number.NaN)).toBe(0);
	});
});

describe('nudgeScore', () => {
	it('steps by half points on the decimal scale', () => {
		expect(nudgeScore(7, 1)).toBe(7.5);
		expect(nudgeScore(7.5, -1)).toBe(7);
	});

	it('snaps off-grid scores onto the step grid', () => {
		expect(nudgeScore(7.3, 1)).toBe(7.5);
		expect(nudgeScore(7.3, -1)).toBe(7);
	});

	it('stays within range', () => {
		expect(nudgeScore(10, 1)).toBe(10);
		expect(nudgeScore(0, -1)).toBe(0);
		expect(nudgeScore(100, 1, 'POINT_100')).toBe(100);
	});
});

describe('formatScore', () => {
	it('formats per scale and shows a dash when unscored', () => {
		expect(formatScore(0)).toBe('—');
		expect(formatScore(8)).toBe('8.0');
		expect(formatScore(85, 'POINT_100')).toBe('85');
		expect(formatScore(3, 'POINT_3')).toBe('☺');
	});
});
