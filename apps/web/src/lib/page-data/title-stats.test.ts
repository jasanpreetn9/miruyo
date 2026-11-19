import { describe, expect, it } from 'vitest';
import type { TitleRanking, TitleStatsResponse } from '#lib/anilist/types.ts';
import { buildTitleStats } from './title-stats.ts';

const ranking = (r: Partial<TitleRanking> & Pick<TitleRanking, 'id'>): TitleRanking => ({
	rank: 1,
	type: 'RATED',
	format: 'TV',
	year: null,
	season: null,
	allTime: false,
	context: '',
	...r
});

const media = (m: Partial<TitleStatsResponse['Media']> = {}): TitleStatsResponse['Media'] => ({
	id: 1,
	averageScore: 91,
	favourites: 12_345,
	stats: { scoreDistribution: [], statusDistribution: [] },
	rankings: [],
	...m
});

describe('buildTitleStats', () => {
	it('puts all-time rankings first, then the year, then the season, rated before popular', () => {
		const { rankings } = buildTitleStats(
			media({
				rankings: [
					ranking({ id: 1, type: 'POPULAR', season: 'FALL', year: 2023 }),
					ranking({ id: 2, type: 'POPULAR', year: 2023 }),
					ranking({ id: 3, type: 'RATED', season: 'FALL', year: 2023 }),
					ranking({ id: 4, type: 'POPULAR', allTime: true, rank: 50 }),
					ranking({ id: 5, type: 'RATED', year: 2023 }),
					ranking({ id: 6, type: 'RATED', allTime: true })
				]
			}),
			{ isAnime: true }
		);
		expect(rankings.map((r) => r.key)).toEqual([6, 4, 5, 2, 3, 1]);
		expect(rankings.map((r) => `${r.label} · ${r.when} · ${r.format}`)).toEqual([
			'Highest rated · All time · TV',
			'Most popular · All time · TV',
			'Highest rated · 2023 · TV',
			'Most popular · 2023 · TV',
			'Highest rated · Fall 2023 · TV',
			'Most popular · Fall 2023 · TV'
		]);
	});

	it('links each ranking to the same list in Browse', () => {
		const { rankings } = buildTitleStats(
			media({
				rankings: [
					ranking({ id: 1, allTime: true, format: 'MOVIE' }),
					ranking({ id: 2, type: 'POPULAR', allTime: true }),
					ranking({ id: 3, season: 'FALL', year: 2023 })
				]
			}),
			{ isAnime: true }
		);
		expect(rankings.map((r) => r.href)).toEqual([
			'/browse?sort=score&format=MOVIE',
			'/browse?format=TV',
			'/browse?sort=score&format=TV&season=FALL&year=2023'
		]);
		expect(rankings[0].format).toBe('Movie');
	});

	it("doesn't link a manga's yearly ranking, since Browse has no year for manga", () => {
		const { rankings } = buildTitleStats(
			media({
				rankings: [
					ranking({ id: 1, allTime: true, format: 'MANGA' }),
					ranking({ id: 2, year: 2020, format: 'MANGA' })
				]
			}),
			{ isAnime: false }
		);
		expect(rankings.map((r) => r.href)).toEqual(['/browse?sort=score&format=MANGA', null]);
	});

	it('counts each list in list order, with its share of everyone', () => {
		const view = buildTitleStats(
			media({
				stats: {
					scoreDistribution: [],
					statusDistribution: [
						{ status: 'PLANNING', amount: 1_000 },
						{ status: 'DROPPED', amount: 0 },
						{ status: 'CURRENT', amount: 3_000 },
						{ status: 'COMPLETED', amount: 6_000 }
					]
				}
			}),
			{ isAnime: false }
		);
		expect(view.statuses).toEqual([
			{ status: 'CURRENT', label: 'Reading', count: 3_000, shown: '3k', percent: 30 },
			{ status: 'COMPLETED', label: 'Completed', count: 6_000, shown: '6k', percent: 60 },
			{ status: 'PLANNING', label: 'Planning', count: 1_000, shown: '1k', percent: 10 }
		]);
		expect(view.members).toBe('10k');
	});

	it('draws ten score bars against the tallest, keeping small ones visible', () => {
		const view = buildTitleStats(
			media({
				stats: {
					statusDistribution: [],
					scoreDistribution: [
						{ score: 100, amount: 10_000 },
						{ score: 90, amount: 5_000 },
						{ score: 10, amount: 1 }
					]
				}
			}),
			{ isAnime: true }
		);
		expect(view.scores.map((b) => b.score)).toEqual([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
		expect(view.scores.map((b) => b.height)).toEqual([2, 0, 0, 0, 0, 0, 0, 0, 50, 100]);
		expect(view.scored).toBe('15k');
		expect(view.average).toBe('9.1');
		expect(view.favourites).toBe('12k');
	});

	it('copes with a title nobody has rated or listed yet', () => {
		const view = buildTitleStats(
			media({ averageScore: null, favourites: 0, stats: null, rankings: null }),
			{ isAnime: true }
		);
		expect(view.rankings).toEqual([]);
		expect(view.statuses).toEqual([]);
		expect(view.scores.every((b) => b.count === 0 && b.height === 0)).toBe(true);
		expect(view.average).toBeNull();
		expect(view.favourites).toBeNull();
	});
});
