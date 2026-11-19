import { describe, expect, it } from 'vitest';
import { isInProgress, LIST_STATUSES, STATUS_COLOR, statusLabel } from './status.ts';

describe('statusLabel', () => {
	it('uses watch verbs for anime', () => {
		expect(statusLabel('CURRENT', true)).toBe('Watching');
		expect(statusLabel('REPEATING', true)).toBe('Rewatching');
	});

	it('swaps to read verbs for manga', () => {
		expect(statusLabel('CURRENT', false)).toBe('Reading');
		expect(statusLabel('REPEATING', false)).toBe('Rereading');
		expect(statusLabel('PAUSED', false)).toBe('Paused');
	});

	it('has a label and colour for every status', () => {
		for (const s of LIST_STATUSES) {
			expect(statusLabel(s, true)).toBeTruthy();
			expect(STATUS_COLOR[s]).toMatch(/^#/);
		}
	});
});

describe('isInProgress', () => {
	it('is true only while progress can still move', () => {
		expect(LIST_STATUSES.filter(isInProgress)).toEqual(['CURRENT', 'PAUSED', 'REPEATING']);
	});
});
