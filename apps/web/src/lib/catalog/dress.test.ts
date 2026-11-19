import { describe, expect, it } from 'vitest';
import { dressTitle, type RawTitle } from './dress.ts';

function raw(overrides: Partial<RawTitle> = {}): RawTitle {
	return {
		id: 1,
		title: 'Sousou no Frieren',
		type: 'ANIME',
		format: 'TV',
		eps: 28,
		score: 9.1,
		color: '#d9a75e',
		genres: ['Fantasy'],
		status: 'Releasing',
		...overrides
	};
}

describe('dressTitle', () => {
	it('uses a mid-luminance cover colour as the accent unchanged', () => {
		expect(dressTitle(raw()).accent).toBe('#d9a75e');
	});

	it('lifts very dark colours toward white and darkens very light ones', () => {
		expect(dressTitle(raw({ color: '#000000' })).accent).toContain('#ffffff');
		expect(dressTitle(raw({ color: '#ffffff' })).accent).toContain('#000');
	});

	it('derives anime units and labels', () => {
		const t = dressTitle(raw());
		expect(t.isAnime).toBe(true);
		expect(t.unit).toBe('EP');
		expect(t.total).toBe(28);
		expect(t.countLabel).toBe('28 eps');
	});

	it('derives manga units and labels, including ongoing series', () => {
		const t = dressTitle(raw({ type: 'MANGA', eps: undefined, ch: null }));
		expect(t.isAnime).toBe(false);
		expect(t.unit).toBe('CH');
		expect(t.total).toBeNull();
		expect(t.countLabel).toBe('Ongoing');
	});

	it('shows an unknown episode count as ?', () => {
		expect(dressTitle(raw({ eps: null })).countLabel).toBe('? eps');
	});

	it('truncates long titles for `short`', () => {
		const long = 'x'.repeat(40);
		const t = dressTitle(raw({ title: long }));
		expect(t.short).toBe('x'.repeat(32) + '…');
		expect(dressTitle(raw()).short).toBe('Sousou no Frieren');
	});

	it('computes list progress percentage and total', () => {
		const t = dressTitle(raw({ me: { s: 'CURRENT', p: 7 } }));
		expect(t.me?.pct).toBe('25%');
		expect(t.me?.of).toBe('28');
	});

	it('estimates progress against an open-ended total when unknown', () => {
		const t = dressTitle(raw({ eps: null, me: { s: 'CURRENT', p: 6 } }));
		// max(6 + 12, 24) = 24
		expect(t.me?.pct).toBe('25%');
		expect(t.me?.of).toBe('?');
	});

	it('does not mutate the input progress object', () => {
		const input = raw({ me: { s: 'CURRENT', p: 7 } });
		dressTitle(input);
		expect(input.me).toEqual({ s: 'CURRENT', p: 7 });
	});
});
