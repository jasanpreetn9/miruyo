import { describe, expect, it } from 'vitest';
import {
	formatTimeUntil,
	humanizeFormat,
	humanizeSeason,
	humanizeStatus,
	stripHtml,
	toListStatus
} from './humanize.ts';

describe('humanizeFormat', () => {
	it('maps known AniList formats', () => {
		expect(humanizeFormat('TV_SHORT')).toBe('TV Short');
		expect(humanizeFormat('ONE_SHOT')).toBe('One-shot');
	});
	it('passes unknown formats through and handles null', () => {
		expect(humanizeFormat('SOMETHING_NEW')).toBe('SOMETHING_NEW');
		expect(humanizeFormat(null)).toBe('Unknown');
	});
});

describe('humanizeStatus', () => {
	it('maps known statuses', () => {
		expect(humanizeStatus('NOT_YET_RELEASED')).toBe('Not yet released');
		expect(humanizeStatus(null)).toBe('Unknown');
	});
});

describe('humanizeSeason', () => {
	it('title-cases the season', () => {
		expect(humanizeSeason('WINTER')).toBe('Winter');
	});
});

describe('toListStatus', () => {
	it('keeps known list statuses, defaulting to CURRENT', () => {
		expect(toListStatus('PLANNING')).toBe('PLANNING');
		expect(toListStatus('REPEATING')).toBe('REPEATING');
		expect(toListStatus('???')).toBe('CURRENT');
	});
});

describe('formatTimeUntil', () => {
	it.each([
		[0, 'now'],
		[-5, 'now'],
		[59, '0m'],
		[12 * 60, '12m'],
		[5 * 3600 + 5 * 60, '5h 05m'],
		[19 * 3600 + 12 * 60, '19h 12m'],
		[86400, '1d'],
		[2 * 86400 + 4 * 3600, '2d 4h']
	])('%i seconds → %s', (seconds, expected) => {
		expect(formatTimeUntil(seconds)).toBe(expected);
	});
});

describe('stripHtml', () => {
	it('removes tags and keeps line breaks as whitespace', () => {
		expect(stripHtml('One<br>Two <i>three</i>')).toBe('One\nTwo three');
		expect(stripHtml('A<br />B')).toBe('A\nB');
	});
	it('decodes named and numeric entities', () => {
		expect(stripHtml('Tom &amp; Jerry &#039;s &#x2014; &hellip;')).toBe("Tom & Jerry 's — …");
	});
	it('leaves out-of-range numeric entities alone instead of throwing', () => {
		expect(stripHtml('a &#99999999; b &#x110000;')).toBe('a &#99999999; b &#x110000;');
	});
	it('leaves unknown entities alone', () => {
		expect(stripHtml('&bogus;')).toBe('&bogus;');
	});
	it('trims surrounding whitespace', () => {
		expect(stripHtml('  <p>x</p>  ')).toBe('x');
	});
});
