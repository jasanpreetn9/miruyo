import { describe, expect, it } from 'vitest';
import { makeCollectionEntry, makeManga, makeMedia } from '#lib/anilist/fixtures.ts';
import { buildListView, relativeTime } from './list.ts';

const NOW = 1_800_000_000;
const HOUR = 3600;
const DAY = 86400;

describe('relativeTime', () => {
	it('reads like the design', () => {
		expect(relativeTime(NOW - 10, NOW)).toBe('Just now');
		expect(relativeTime(NOW - 12 * 60, NOW)).toBe('12m ago');
		expect(relativeTime(NOW - 2 * HOUR, NOW)).toBe('2h ago');
		expect(relativeTime(NOW - 30 * HOUR, NOW)).toBe('Yesterday');
		expect(relativeTime(NOW - 3 * DAY, NOW)).toBe('3d ago');
	});

	it('shows a date this year and just the year before that', () => {
		// NOW is 2027-01-15 UTC
		expect(relativeTime(Date.UTC(2027, 0, 2) / 1000, NOW, 'UTC')).toBe('Jan 2');
		expect(relativeTime(Date.UTC(2025, 7, 30) / 1000, NOW, 'UTC')).toBe('2025');
	});
});

describe('buildListView', () => {
	const watching = makeCollectionEntry(
		makeMedia({
			id: 1,
			title: { romaji: 'Frieren', english: null, native: null, userPreferred: 'Frieren' },
			nextAiringEpisode: { episode: 9, airingAt: NOW + 2 * DAY + 4 * HOUR, timeUntilAiring: 0 }
		}),
		{ progress: 6, updatedAt: NOW - HOUR, score: 9.5 }
	);
	const caughtUp = makeCollectionEntry(
		makeMedia({
			id: 2,
			title: {
				romaji: 'Apothecary',
				english: 'The Apothecary Diaries',
				native: null,
				userPreferred: 'Apothecary'
			},
			format: 'MOVIE',
			nextAiringEpisode: { episode: 13, airingAt: NOW + 19 * HOUR, timeUntilAiring: 0 }
		}),
		{ progress: 12, updatedAt: NOW - 3 * DAY, score: 8 }
	);
	const done = makeCollectionEntry(makeMedia({ id: 3 }), { status: 'COMPLETED', progress: 24 });
	const planned = makeCollectionEntry(makeMedia({ id: 4 }), { status: 'PLANNING', progress: 0 });
	const entries = [caughtUp, watching, done, planned];

	it('counts every tab and shows the current one, newest first', () => {
		const view = buildListView(entries, { tab: 'CURRENT', isAnime: true, now: NOW });
		expect(view.tabs.map((t) => [t.label, t.count])).toEqual([
			['Watching', 2],
			['Completed', 1],
			['Planning', 1],
			['Paused', 0],
			['Dropped', 0],
			['Rewatching', 0]
		]);
		expect(view.rows.map((r) => r.title.id)).toEqual([1, 2]);
		expect(view.rows[0].updated).toBe('1h ago');
	});

	it('gives watching rows airing context', () => {
		const [behind, upToDate] = buildListView(entries, {
			tab: 'CURRENT',
			isAnime: true,
			now: NOW
		}).rows;
		expect(behind).toMatchObject({ note: '2 new · EP 9 in 2d 4h', noteColor: '#4ED98A' });
		expect(upToDate).toMatchObject({
			note: 'Caught up · EP 13 in 19h 00m',
			noteColor: 'var(--color-muted)'
		});
	});

	it('filters by text (either title) and format, and sorts', () => {
		const base = { tab: 'CURRENT' as const, isAnime: true, now: NOW };
		expect(
			buildListView(entries, { ...base, filter: 'diaries' }).rows.map((r) => r.title.id)
		).toEqual([2]);
		expect(
			buildListView(entries, { ...base, format: 'Movie' }).rows.map((r) => r.title.id)
		).toEqual([2]);
		expect(buildListView(entries, { ...base, sort: 'title' }).rows.map((r) => r.title.id)).toEqual([
			2, 1
		]);
		expect(buildListView(entries, { ...base, sort: 'airing' }).rows.map((r) => r.title.id)).toEqual(
			[2, 1]
		);
		expect(buildListView(entries, { ...base, sort: 'score' }).rows.map((r) => r.title.id)).toEqual([
			1, 2
		]);
		expect(buildListView(entries, base).formats).toEqual(['Movie', 'TV']);
	});

	it('applies local edits: a completed row moves tabs, a removed one disappears', () => {
		const view = buildListView(entries, {
			tab: 'COMPLETED',
			isAnime: true,
			now: NOW,
			live: (id) => (id === 1 ? { status: 'COMPLETED', progress: 24 } : undefined),
			removed: (id) => id === 3
		});
		expect(view.rows.map((r) => r.title.id)).toEqual([1]);
		expect(view.tabs.find((t) => t.status === 'CURRENT')?.count).toBe(1);
	});

	it('summarizes anime by episodes and days, manga by chapters and mean score', () => {
		const anime = buildListView([watching, caughtUp], { tab: 'CURRENT', isAnime: true, now: NOW });
		// (6 + 12) × 24 min = 432 min = 0.3 days
		expect(anime.summary).toBe('2 titles · 18 episodes · 0.3 days watched');

		const manga = buildListView(
			[
				makeCollectionEntry(makeManga({ id: 5 }), { progress: 100, score: 9 }),
				makeCollectionEntry(makeManga({ id: 6 }), { progress: 20, score: 8 })
			],
			{ tab: 'CURRENT', isAnime: false, now: NOW }
		);
		expect(manga.summary).toBe('2 titles · 120 chapters · mean score 8.5');
		expect(manga.tabs[0].label).toBe('Reading');
	});

	it('a custom list holds its titles whatever their status, each saying which', () => {
		const view = buildListView(entries, {
			tab: 'CURRENT',
			only: new Set([3, 4]),
			isAnime: true,
			now: NOW
		});
		expect(view.rows.map((r) => r.title.id).sort()).toEqual([3, 4]);
		expect(view.rows.find((r) => r.title.id === 4)?.note).toMatch(/^Planning · /);
	});

	it('titles hidden from status lists stay off the status tabs', () => {
		const view = buildListView(entries, {
			tab: 'CURRENT',
			hidden: new Set([1]),
			isAnime: true,
			now: NOW
		});
		expect(view.rows.map((r) => r.title.id)).toEqual([2]);
		expect(view.tabs[0]).toMatchObject({ label: 'Watching', count: 1 });
		// still on its custom list
		const custom = buildListView(entries, {
			tab: 'CURRENT',
			only: new Set([1]),
			hidden: new Set([1]),
			isAnime: true,
			now: NOW
		});
		expect(custom.rows.map((r) => r.title.id)).toEqual([1]);
	});
});
