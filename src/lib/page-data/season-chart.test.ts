import { describe, expect, it } from 'vitest';
import { makeMedia } from '#lib/anilist/fixtures.ts';
import type { SeasonMedia } from '#lib/anilist/types.ts';
import {
	buildCard,
	buildSeasonChart,
	longDuration,
	parseSeasonParams,
	scoreFace,
	seasonHref,
	seasonWindow,
	SERVER_LEFTOVERS,
	SERVER_TITLES,
	serverChart,
	shiftSeason
} from './season-chart.ts';

// Wed 7 Oct 2026, noon local
const NOW = new Date(2026, 9, 7, 12);
const NOW_S = Math.floor(NOW.getTime() / 1000);
const FALL_2026 = { season: 'FALL' as const, year: 2026 };

function seasonMedia(overrides: Partial<SeasonMedia> = {}): SeasonMedia {
	return {
		...makeMedia({ id: 1, nextAiringEpisode: null }),
		source: 'MANGA',
		startDate: { year: 2026, month: 10, day: 3 },
		rankings: [],
		relations: { edges: [] },
		...overrides
	};
}

describe('seasons', () => {
	it('steps across years', () => {
		expect(shiftSeason(FALL_2026, 1)).toEqual({ season: 'WINTER', year: 2027 });
		expect(shiftSeason({ season: 'WINTER', year: 2027 }, -1)).toEqual(FALL_2026);
		expect(seasonWindow(FALL_2026).map((s) => `${s.season} ${s.year}`)).toEqual([
			'SUMMER 2026',
			'FALL 2026',
			'WINTER 2027',
			'SPRING 2027'
		]);
	});

	it('reads the season from the URL, defaulting to now', () => {
		expect(parseSeasonParams(new URLSearchParams('season=spring&year=2027'), NOW)).toEqual({
			season: 'SPRING',
			year: 2027
		});
		expect(parseSeasonParams(new URLSearchParams('season=nope'), NOW)).toEqual(FALL_2026);
		// no chart that far out: its airing week would overflow AniList's 32-bit timestamps
		expect(parseSeasonParams(new URLSearchParams('season=winter&year=2367'), NOW)).toEqual(
			FALL_2026
		);
		expect(parseSeasonParams(new URLSearchParams('season=fall&year=2028'), NOW)).toEqual({
			season: 'FALL',
			year: 2028
		});
		expect(parseSeasonParams(new URLSearchParams('season=winter&year=2029'), NOW)).toEqual(
			FALL_2026
		);
		expect(parseSeasonParams(new URLSearchParams('season=winter&year=1939'), NOW)).toEqual(
			FALL_2026
		);
		expect(parseSeasonParams(new URLSearchParams('season=winter&year=1940'), NOW)).toEqual({
			season: 'WINTER',
			year: 1940
		});
		expect(seasonHref(FALL_2026, NOW)).toBe('/seasonal');
		expect(seasonHref({ season: 'WINTER', year: 2027 }, NOW)).toBe(
			'/seasonal?season=winter&year=2027'
		);
	});
});

describe('card text', () => {
	it('counts down like AniChart', () => {
		expect(longDuration(18 * 3600 + 31 * 60)).toBe('18 hours, 31 mins');
		expect(longDuration(86400 + 6 * 3600 + 59)).toBe('1 day, 6 hours');
		expect(longDuration(2 * 86400)).toBe('2 days');
		expect(longDuration(35 * 60)).toBe('35 mins');
	});

	it('faces follow AniChart’s colours', () => {
		expect([85, 76, 75, 71, 60, 54, null].map((s) => scoreFace(s))).toEqual([
			'good',
			'good',
			'good',
			'ok',
			'ok',
			'bad',
			null
		]);
	});
});

describe('buildSeasonChart', () => {
	const airing = seasonMedia({
		id: 1,
		episodes: 12,
		averageScore: 85,
		nextAiringEpisode: { episode: 2, airingAt: NOW_S + 18 * 3600 + 31 * 60, timeUntilAiring: 0 },
		rankings: [
			{ rank: 9, type: 'POPULAR', season: null, year: null, allTime: false },
			{ rank: 1, type: 'POPULAR', season: 'FALL', year: 2026, allTime: false }
		],
		relations: {
			edges: [
				{
					relationType: 'PREQUEL',
					node: {
						id: 9,
						type: 'ANIME',
						title: { romaji: 'Kusuriya 2', english: 'Apothecary 2', userPreferred: 'Kusuriya 2' }
					}
				}
			]
		}
	});
	const movie = seasonMedia({
		id: 2,
		format: 'MOVIE',
		status: 'NOT_YET_RELEASED',
		startDate: { year: 2026, month: 11, day: 20 },
		source: 'LIGHT_NOVEL',
		averageScore: null
	});
	const ona = seasonMedia({ id: 3, format: 'ONA', source: 'ORIGINAL', averageScore: 54 });
	const leftover = seasonMedia({
		id: 4,
		rankings: [{ rank: 3, type: 'POPULAR', season: 'SUMMER', year: 2026, allTime: false }],
		nextAiringEpisode: { episode: 15, airingAt: NOW_S + 3600, timeUntilAiring: 0 }
	});

	it('groups by format in AniChart’s order, leftovers after TV Short', () => {
		const chart = buildSeasonChart([airing, movie, ona], [leftover], {
			season: FALL_2026,
			now: NOW
		});
		expect(chart.map((s) => [s.label, s.cards.map((c) => c.title.id)])).toEqual([
			['TV', [1]],
			['Leftovers', [4]],
			['Movie', [2]],
			['OVA / ONA / Special', [3]]
		]);
	});

	it('fills a card the way AniChart reads', () => {
		const [tv, left, film, other] = buildSeasonChart([airing, movie, ona], [leftover], {
			season: FALL_2026,
			now: NOW
		});
		expect(tv.cards[0]).toMatchObject({
			whenLabel: 'Ep 2 of 12 airing in',
			when: '18 hours, 31 mins',
			origin: 'Sequel to Kusuriya 2',
			score: 85,
			face: 'good',
			popularRank: 1,
			studio: 'Studio One'
		});
		// a leftover's rank is from its own season
		expect(left.cards[0].popularRank).toBeNull();
		expect(film.cards[0]).toMatchObject({
			whenLabel: 'Premieres',
			when: 'Nov 20, 2026',
			origin: 'Source • Light Novel',
			score: null,
			face: null
		});
		expect(other.cards[0]).toMatchObject({ origin: 'Source • Original', face: 'bad' });
	});

	it('uses English titles when asked (signed out)', () => {
		const [tv] = buildSeasonChart([airing], [], { season: FALL_2026, now: NOW, titles: 'english' });
		expect(tv.cards[0].origin).toBe('Sequel to Apothecary 2');
	});

	it('sorts and filters within sections', () => {
		const a = seasonMedia({
			id: 10,
			averageScore: 60,
			title: { romaji: 'Bravo', english: null, native: null, userPreferred: 'Bravo' }
		});
		const b = seasonMedia({
			id: 11,
			averageScore: 90,
			title: { romaji: 'Alpha', english: null, native: null, userPreferred: 'Alpha' },
			nextAiringEpisode: { episode: 1, airingAt: NOW_S + 60, timeUntilAiring: 0 }
		});
		const ids = (sort: 'score' | 'title' | 'airing' | 'popularity', filter = '') =>
			buildSeasonChart([a, b], [], { season: FALL_2026, now: NOW, sort, filter })[0]?.cards.map(
				(c) => c.title.id
			);
		expect(ids('popularity')).toEqual([10, 11]);
		expect(ids('score')).toEqual([11, 10]);
		expect(ids('title')).toEqual([11, 10]);
		expect(ids('airing')).toEqual([11, 10]);
		expect(ids('popularity', 'brav')).toEqual([10]);
		expect(ids('popularity', 'zzz')).toBeUndefined();
	});
});

describe('serverChart', () => {
	const title = (english: string) => ({ romaji: english, english, userPreferred: english });
	const full = seasonMedia({
		id: 7,
		description: `<i>Frieren</i> ${'walks on. '.repeat(60)}`,
		bannerImage: 'https://img/banner.jpg',
		rankings: [
			{ rank: 3, type: 'POPULAR', season: 'FALL', year: 2026, allTime: false },
			{ rank: 90, type: 'RATED', season: null, year: null, allTime: true }
		],
		relations: {
			edges: [
				{ relationType: 'ADAPTATION', node: { id: 1, type: 'MANGA', title: title('The manga') } },
				{ relationType: 'PREQUEL', node: { id: 2, type: 'ANIME', title: title('Season 1') } },
				{ relationType: 'SIDE_STORY', node: { id: 3, type: 'ANIME', title: title('A special') } }
			]
		}
	});

	it('keeps what a card shows and drops the rest', () => {
		const [slim] = serverChart({ media: [full], leftovers: [] }, FALL_2026).media;
		expect(slim.bannerImage).toBeNull();
		expect(slim.relations?.edges.map((e) => e.node.id)).toEqual([2]);
		expect(slim.rankings?.map((r) => r.rank)).toEqual([3]);
		expect(slim.description?.startsWith('Frieren walks on.')).toBe(true);
		expect(slim.description?.length).toBeLessThanOrEqual(301);
		expect(slim.description?.endsWith('on.…')).toBe(true);
		// the card reads the same, synopsis and the (unshown) banner aside
		const options = { season: FALL_2026, now: NOW };
		const { synopsis, ...card } = buildCard(slim, options);
		const { synopsis: fullSynopsis, ...fullCard } = buildCard(full, options);
		expect(card).toEqual({
			...fullCard,
			title: { ...fullCard.title, synopsis: card.title.synopsis, banner: undefined }
		});
		expect(fullSynopsis.startsWith(synopsis.slice(0, -1))).toBe(true);
		expect(card.origin).toBe('Sequel to Season 1');
		expect(card.popularRank).toBe(3);
	});

	it("renders the season's best-known titles, with the whole chart's counts", () => {
		const media = Array.from({ length: 40 }, (_, i) => seasonMedia({ id: i + 1 }));
		const leftovers = Array.from({ length: 20 }, (_, i) => seasonMedia({ id: i + 100 }));
		const chart = serverChart({ media, leftovers }, FALL_2026);
		expect(chart.media.map((m) => m.id)).toEqual(media.slice(0, SERVER_TITLES).map((m) => m.id));
		expect(chart.leftovers).toHaveLength(SERVER_LEFTOVERS);
		expect(chart.total).toBe(40);
		expect(chart.leftoverTotal).toBe(20);
	});
});
