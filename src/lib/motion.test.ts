import { describe, expect, it } from 'vitest';
import { cubicBezier, easeEnter } from './motion.ts';

describe('cubicBezier', () => {
	it('pins the ends', () => {
		expect(easeEnter(0)).toBe(0);
		expect(easeEnter(1)).toBe(1);
	});

	it('is linear for the linear curve', () => {
		const linear = cubicBezier(0, 0, 1, 1);
		expect(linear(0.25)).toBeCloseTo(0.25, 5);
		expect(linear(0.7)).toBeCloseTo(0.7, 5);
	});

	it('matches the CSS ease curve at known points', () => {
		const ease = cubicBezier(0.25, 0.1, 0.25, 1);
		expect(ease(0.5)).toBeCloseTo(0.8024, 3);
	});

	it('eases out fast for the enter curve', () => {
		expect(easeEnter(0.25)).toBeGreaterThan(0.6);
	});
});
