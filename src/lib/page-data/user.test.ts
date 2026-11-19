import { describe, expect, it } from 'vitest';
import { makeCollectionEntry, makeManga, makeMedia } from '#lib/anilist/fixtures.ts';
import { countryName } from './list.ts';
import {
	buildUserList,
	defaultUserSort,
	forViewer,
	isOwnProfile,
	statusParam,
	possessive,
	userSortsFor
} from './user.ts';

const now = 1_800_000_000;

describe('user list', () => {
	const entries = [
		makeCollectionEntry(
			makeMedia({ id: 1, title: { romaji: 'A', english: 'A', native: null, userPreferred: 'A' } }),
			{
				status: 'COMPLETED',
				score: 7.5
			}
		),
		makeCollectionEntry(
			makeMedia({ id: 2, title: { romaji: 'B', english: 'B', native: null, userPreferred: 'B' } }),
			{
				status: 'COMPLETED',
				score: 9
			}
		),
		makeCollectionEntry(makeMedia({ id: 3, isAdult: true }), { status: 'COMPLETED', score: 10 }),
		makeCollectionEntry(makeMedia({ id: 4 }), { status: 'CURRENT' })
	];

	it('opens Completed best first, leaving out 18+ titles unless the viewer allows them', () => {
		const view = buildUserList(entries, { status: 'COMPLETED', isAnime: true, adult: false, now });
		expect(view.rows.map((r) => [r.title.id, r.score])).toEqual([
			[2, 9],
			[1, 7.5]
		]);
		expect(view.tabs.map((t) => [t.status, t.count])).toEqual([
			['CURRENT', 1],
			['COMPLETED', 2]
		]);
		const all = buildUserList(entries, { status: 'COMPLETED', isAnime: true, adult: true, now });
		expect(all.rows[0].title.id).toBe(3);
	});

	it('keeps the open status as a tab even when it is empty', () => {
		const view = buildUserList(entries, { status: 'DROPPED', isAnime: true, adult: false, now });
		expect(view.tabs.map((t) => t.status)).toEqual(['CURRENT', 'COMPLETED', 'DROPPED']);
		expect(view.rows).toEqual([]);
	});

	it("filters by AniList's genre, country and year, and offers what's on the list", () => {
		const list = [
			makeCollectionEntry(makeMedia({ id: 1, genres: ['Action'], countryOfOrigin: 'JP' }), {
				status: 'COMPLETED'
			}),
			makeCollectionEntry(
				makeMedia({ id: 2, genres: ['Drama'], countryOfOrigin: 'KR', seasonYear: 2024 }),
				{ status: 'COMPLETED' }
			),
			// a manga's year is its start date's
			makeCollectionEntry(
				makeManga({ id: 3, genres: ['Drama', 'Romance'], startDate: { year: 2019 } }),
				{ status: 'COMPLETED' }
			)
		];
		const ids = (options: { genre?: string; country?: string; year?: number }) =>
			buildUserList(list, { status: 'COMPLETED', isAnime: true, adult: false, now, ...options })
				.rows.map((r) => r.title.id)
				.sort();
		expect(ids({})).toEqual([1, 2, 3]);
		expect(ids({ genre: 'Drama' })).toEqual([2, 3]);
		expect(ids({ country: 'KR' })).toEqual([2]);
		expect(ids({ year: 2019 })).toEqual([3]);
		expect(ids({ genre: 'Drama', year: 2024 })).toEqual([2]);
		expect(ids({ genre: 'Action', country: 'KR' })).toEqual([]);

		const view = buildUserList(list, { status: 'COMPLETED', isAnime: true, adult: false, now });
		expect(view.genres).toEqual(['Action', 'Drama', 'Romance']);
		expect(view.countries).toEqual(['JP', 'KR']);
		expect(view.years).toEqual([2026, 2024, 2019]);
	});

	it('names countries as AniList does', () => {
		expect(['JP', 'KR', 'CN', 'TW', 'FR'].map(countryName)).toEqual([
			'Japan',
			'South Korea',
			'China',
			'Taiwan',
			'FR'
		]);
	});

	it('reads the status from the URL', () => {
		expect(statusParam(null)).toBe('CURRENT');
		expect(statusParam('completed')).toBe('COMPLETED');
		expect(statusParam('nonsense')).toBe('CURRENT');
	});

	it('offers My List’s sorts without “Most to watch”', () => {
		expect(userSortsFor('CURRENT', true).map((s) => s.key)).not.toContain('toWatch');
		expect(defaultUserSort('COMPLETED')).toBe('score');
		expect(defaultUserSort('CURRENT')).toBe('updated');
	});
});

describe('names', () => {
	it('makes possessives', () => {
		expect(possessive('matchai')).toBe('matchai’s');
		expect(possessive('Ines')).toBe('Ines’');
	});

	it('knows your own profile whatever the case', () => {
		expect(isOwnProfile({ name: 'Matchai' }, 'matchai')).toBe(true);
		expect(isOwnProfile({ name: 'matchai' }, null)).toBe(false);
		expect(isOwnProfile({ name: 'matchai' }, 'haruka')).toBe(false);
	});
});

describe('forViewer', () => {
	const safe = makeCollectionEntry(makeMedia({ id: 1 }));
	const adult = makeCollectionEntry(makeMedia({ id: 2, isAdult: true }));

	it('leaves 18+ titles out unless the viewer shows them', () => {
		expect(forViewer([safe, adult], false).map((e) => e.mediaId)).toEqual([1]);
		expect(forViewer([safe, adult], true).map((e) => e.mediaId)).toEqual([1, 2]);
	});
});
