import { describe, expect, it } from 'vitest';
import { makeCollectionEntry, makeManga, makeMedia } from '#lib/anilist/fixtures.ts';
import type { AniListDate } from '#lib/anilist/types.ts';
import { buildHeatmap, buildStats, parseRange, rangeLabel, toTenPoint } from './stats.ts';

// Wed 7 Oct 2026, local time
const NOW = new Date(2026, 9, 7, 12);
const date = (year: number, month: number, day = 1): AniListDate => ({ year, month, day });

describe('toTenPoint', () => {
	it('puts every score format on the 10-point axis', () => {
		expect(toTenPoint(85, 'POINT_100')).toBe(8.5);
		expect(toTenPoint(8.5, 'POINT_10_DECIMAL')).toBe(8.5);
		expect(toTenPoint(4, 'POINT_5')).toBe(8);
		expect(toTenPoint(0, 'POINT_100')).toBe(0);
	});
});

describe('ranges', () => {
	it('reads from the URL, defaulting to all time', () => {
		expect(parseRange('year')).toBe('year');
		expect(parseRange('nope')).toBe('all');
		expect(parseRange(null)).toBe('all');
		expect(rangeLabel('year', NOW)).toBe('2026');
	});
});

describe('buildStats', () => {
	const frieren = makeCollectionEntry(
		makeMedia({ id: 1, episodes: 28, duration: 24, genres: ['Adventure', 'Drama'] }),
		{
			status: 'COMPLETED',
			progress: 28,
			repeat: 1,
			score: 9.5,
			startedAt: date(2026, 1),
			completedAt: date(2026, 9, 20)
		}
	);
	const movie = makeCollectionEntry(
		makeMedia({ id: 2, format: 'MOVIE', episodes: 1, duration: 120, genres: ['Drama'] }),
		{
			status: 'COMPLETED',
			progress: 1,
			score: 6,
			startedAt: date(2020, 5),
			completedAt: date(2020, 5)
		}
	);
	const watching = makeCollectionEntry(makeMedia({ id: 3, genres: ['Action'] }), {
		status: 'CURRENT',
		progress: 5
	});
	const entries = [frieren, movie, watching];

	it('counts episodes with rewatches in full, and days watched', () => {
		const stats = buildStats(entries, { isAnime: true, range: 'all', now: NOW });
		const [total, episodes, days, mean] = stats.cards;
		expect(total).toMatchObject({ label: 'Total anime', value: '3' });
		expect(total.detail).toBe('+1 finished this season');
		expect(total.positive).toBe(true);
		// 28 + 28 (rewatch) + 1 + 5
		expect(episodes.value).toBe('62');
		// (56×24 + 120 + 5×24) / 1440
		expect(days.value).toBe('1.1');
		expect(mean.value).toBe('7.8');
		expect(mean.detail).toBe('AniList mean 8.5');
	});

	it('buckets scores on the 10-point axis and accents 7 and up', () => {
		const stats = buildStats(entries, { isAnime: true, range: 'all', now: NOW });
		expect(stats.scores.map((b) => b.count)).toEqual([0, 0, 0, 0, 0, 1, 0, 0, 0, 1]);
		expect(stats.scores[5].tone).toBe('mute');
		expect(stats.scores[9].tone).toBe('accent');
		expect(stats.scored).toBe(2);
		expect(stats.deviation).toBeCloseTo(1.75);
	});

	it('groups formats, statuses and genres', () => {
		const stats = buildStats(entries, { isAnime: true, range: 'all', now: NOW });
		expect(stats.formats.map((f) => [f.label, f.count])).toEqual([
			['TV', 2],
			['Movie', 1]
		]);
		expect(stats.statuses.map((s) => [s.label, s.count])).toEqual([
			['Completed', 2],
			['Watching', 1]
		]);
		expect(stats.genres[0]).toMatchObject({ genre: 'Drama', count: 2, mean: 7.75, width: 1 });
		expect(stats.genres.find((g) => g.genre === 'Action')?.mean).toBeNull();
	});

	it('folds formats past the fourth into Other', () => {
		const formats = ['TV', 'MOVIE', 'OVA', 'ONA', 'SPECIAL'];
		const many = formats.map((format, i) => makeCollectionEntry(makeMedia({ id: 10 + i, format })));
		const stats = buildStats(many, { isAnime: true, range: 'all', now: NOW });
		expect(stats.formats.map((f) => f.label)).toEqual(['TV', 'Movie', 'OVA', 'Other']);
		expect(stats.formats[3].count).toBe(2);
	});

	it('limits a range to titles started or finished in it', () => {
		const year = buildStats(entries, { isAnime: true, range: 'year', now: NOW });
		// the 2020 movie drops out; the undated entry counts by its last update
		expect(year.total).toBe(2);
		expect(year.formats.map((f) => f.label)).toEqual(['TV']);
	});

	it('counts titles finished per month for the last 12 months', () => {
		const stats = buildStats(entries, { isAnime: true, range: 'all', now: NOW });
		expect(stats.months).toHaveLength(12);
		expect(stats.months[0].name).toBe('November 2025');
		expect(stats.months[11]).toMatchObject({ label: 'O', tone: 'mute', count: 0 });
		expect(stats.months[10]).toMatchObject({ name: 'September 2026', count: 1, tone: 'accent' });
	});

	it('swaps units for manga', () => {
		const manga = makeCollectionEntry(makeManga({ id: 20, chapters: 100, volumes: 10 }), {
			status: 'COMPLETED',
			progress: 100,
			progressVolumes: 10,
			repeat: 1
		});
		const stats = buildStats([manga], { isAnime: false, range: 'all', now: NOW });
		expect(stats.cards.map((c) => [c.label, c.value])).toEqual([
			['Total manga', '1'],
			['Chapters read', '200'],
			['Volumes read', '20'],
			['Mean score', '—']
		]);
		expect(stats.statuses[0].label).toBe('Completed');
	});
});

describe('buildHeatmap', () => {
	const day = (y: number, m: number, d: number) => new Date(y, m, d).getTime() / 1000;

	it('lays out 26 weeks of Monday → Sunday, ending this week', () => {
		const grid = buildHeatmap([], NOW);
		expect(grid).toHaveLength(26);
		expect(grid.every((w) => w.length === 7)).toBe(true);
		// Wed 7 Oct: Thu–Sun of this week haven't happened yet
		expect(grid[25].map((c) => c === null)).toEqual([false, false, false, true, true, true, true]);
		expect(grid[25][2]?.date).toBe('Oct 7');
		expect(grid[0][0]?.date).toBe('Apr 13');
	});

	it('levels active days by quartile, so one big day does not flatten the rest', () => {
		const history = [1, 2, 3, 4, 500].map((amount, i) => ({
			date: day(2026, 9, 1 + i),
			amount,
			level: 1
		}));
		const grid = buildHeatmap(history, NOW);
		const levels = grid
			.flat()
			.filter((c) => c?.amount)
			.map((c) => c?.level);
		expect(levels).toEqual([1, 1, 2, 3, 4]);
	});
});
